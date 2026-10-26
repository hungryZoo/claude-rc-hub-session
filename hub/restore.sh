#!/usr/bin/env bash
# claude-rc tmux 세션 복구 스크립트
# windows.tsv 목록 기준 세션, 윈도우 생성 및 claude rc 실행. 여러 번 실행해도 안전.
#   - 윈도우 없음: 생성 후 claude rc 실행
#   - 윈도우 있음 + 셸만 실행 중: claude rc 재실행
#   - 윈도우 있음 + claude 실행 중: 유지
#
# 환경변수
#   HUB_DRY_RUN=1       실행 없이 계획만 출력
#   HUB_SESSION         tmux 세션 이름 (기본 claude-rc)
#   HUB_MANIFEST        목록 파일 경로 (기본 스크립트 옆 windows.tsv)
#   HUB_TMUX_BIN        tmux 실행 파일 경로 (기본 자동 감지)
#   HUB_TMUX_SOCKET     tmux -L 소켓 이름 (테스트용)
#   HUB_CMD             윈도우에서 실행할 명령 (기본 claude rc --spawn=same-dir)
set -u
HUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${HUB_MANIFEST:-$HUB_DIR/windows.tsv}"
SESSION="${HUB_SESSION:-claude-rc}"
CMD="${HUB_CMD:-claude rc --spawn=same-dir}"
DRY="${HUB_DRY_RUN:-0}"
LOG_DIR="$HUB_DIR/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/restore_$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

log() { echo "[$(date '+%F %T')] $*"; }

unset TMUX TMUX_PANE
export PATH="$HOME/.local/bin:$PATH"

# tmux 실행 파일 감지. snap 설치는 /snap/bin/tmux 래퍼가 일부 환경에서 출력 없이 종료되므로 실제 바이너리 우선.
detect_tmux() {
  if [ -n "${HUB_TMUX_BIN:-}" ]; then echo "$HUB_TMUX_BIN"; return; fi
  if [ -x /snap/tmux/current/usr/local/bin/tmux ]; then echo /snap/tmux/current/usr/local/bin/tmux; return; fi
  command -v tmux 2>/dev/null
}

log "복구 시작 (session=$SESSION, dry_run=$DRY, socket=${HUB_TMUX_SOCKET:-default})"

# tmux 준비 대기 (최대 120초, snap 마운트 지연 대응)
TMUX_BIN=""
for _ in $(seq 1 60); do TMUX_BIN="$(detect_tmux)"; [ -n "$TMUX_BIN" ] && [ -x "$TMUX_BIN" ] && break; sleep 2; done
[ -n "$TMUX_BIN" ] && [ -x "$TMUX_BIN" ] || { log "오류: tmux 실행 파일 없음"; exit 1; }
T=("$TMUX_BIN"); [ -n "${HUB_TMUX_SOCKET:-}" ] && T+=(-L "$HUB_TMUX_SOCKET")
log "tmux: $TMUX_BIN"

# 네트워크 대기 (최대 300초). 실패해도 진행.
for _ in $(seq 1 60); do getent hosts claude.ai >/dev/null 2>&1 && break; sleep 5; done
getent hosts claude.ai >/dev/null 2>&1 && log "네트워크 확인" || log "경고: 네트워크 미확인 상태로 진행"

[ -f "$MANIFEST" ] || { log "오류: 목록 파일 없음 ($MANIFEST)"; exit 1; }

run() { if [ "$DRY" = 1 ]; then log "  (dry-run) $*"; else "$@"; fi; }

started=()
while IFS=$'\t' read -r name dir || [ -n "$name" ]; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  dir="${dir/#\~/$HOME}"
  if [ ! -d "$dir" ]; then log "건너뜀 [$name]: 폴더 없음 ($dir)"; continue; fi
  target="=$SESSION:=$name"

  if ! "${T[@]}" has-session -t "=$SESSION" 2>/dev/null; then
    log "생성 [$name]: 세션 및 첫 윈도우 ($dir)"
    run "${T[@]}" new-session -d -s "$SESSION" -n "$name" -c "$dir"
  elif ! "${T[@]}" list-windows -t "=$SESSION" -F '#{window_name}' | grep -qxF "$name"; then
    log "생성 [$name]: 윈도우 ($dir)"
    run "${T[@]}" new-window -d -t "=$SESSION:" -n "$name" -c "$dir"
  else
    cur=$("${T[@]}" display-message -p -t "$target" '#{pane_current_command}')
    case "$cur" in
      claude) log "유지 [$name]: claude 실행 중"; continue ;;
      bash|zsh|sh|fish) log "재실행 [$name]: 셸만 실행 중" ;;
      *) log "건너뜀 [$name]: 다른 프로그램 실행 중 ($cur)"; continue ;;
    esac
  fi
  run "${T[@]}" send-keys -t "$target" "$CMD" Enter
  started+=("$name")
  [ "$DRY" = 1 ] || sleep 2
done < "$MANIFEST"

# 연결 상태 확인
if [ "$DRY" != 1 ] && [ ${#started[@]} -gt 0 ] && [ -z "${HUB_CMD:-}" ]; then
  sleep 15
  for name in "${started[@]}"; do
    screen="$("${T[@]}" capture-pane -p -t "=$SESSION:=$name")"
    if grep -q 'Connected' <<<"$screen"; then
      log "연결 확인 [$name]"
    elif grep -q 'Trust' <<<"$screen"; then
      log "대기 [$name]: 폴더 신뢰 확인 프롬프트. tmux 윈도우에서 y 입력 필요"
    else
      log "경고 [$name]: Connected 미확인. 화면 마지막 줄:"
      grep -v '^\s*$' <<<"$screen" | tail -3 | sed 's/^/    /'
    fi
  done
fi

# 로그 30개만 보관
ls -1t "$LOG_DIR"/restore_*.log 2>/dev/null | tail -n +31 | xargs -r rm -f
log "복구 종료 (실행 ${#started[@]}개)"
