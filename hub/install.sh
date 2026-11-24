#!/usr/bin/env bash
# rc-hub 설치 스크립트. 여러 번 실행해도 안전.
#   (1) 복구 스크립트를 <상위 폴더>/.hub/restore.sh 로 복사 (기존 파일과 다르면 백업 후 교체)
#   (2) 윈도우 목록 <상위 폴더>/.hub/windows.tsv 생성 (없을 때만)
#   (3) systemd 사용자 서비스 claude-rc-restore.service 배치와 enable
#
# 사용법: install.sh [프로젝트 상위 폴더]     기본 ~/dev, 환경변수 HUB_ROOT 로도 지정 가능
# 환경변수: HUB_SKIP_SYSTEMD=1  서비스 파일만 배치하고 systemctl 호출 생략
set -euo pipefail
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_SRC="$SRC_DIR/../systemd/claude-rc-restore.service"
UNIT_NAME=claude-rc-restore.service

say() { echo "[rc-hub] $*"; }

ROOT="${1:-${HUB_ROOT:-$HOME/dev}}"
ROOT="${ROOT/#\~/$HOME}"
mkdir -p "$ROOT"
ROOT="$(cd "$ROOT" && pwd)"
HUB="$ROOT/.hub"
case "$HUB" in *[[:space:]]*) say "오류: 공백이 포함된 경로는 지원하지 않음 ($HUB)"; exit 1 ;; esac
[ -f "$SRC_DIR/restore.sh" ] || { say "오류: restore.sh 없음 ($SRC_DIR)"; exit 1; }
[ -f "$UNIT_SRC" ] || { say "오류: 서비스 파일 없음 ($UNIT_SRC)"; exit 1; }

mkdir -p "$HUB/logs"

# (1) 복구 스크립트
if [ -f "$HUB/restore.sh" ] && cmp -s "$SRC_DIR/restore.sh" "$HUB/restore.sh"; then
  say "restore.sh: 최신 상태"
else
  if [ -f "$HUB/restore.sh" ]; then
    bak="$HUB/restore.sh.bak-$(date +%Y%m%d-%H%M%S)"
    cp -p "$HUB/restore.sh" "$bak"
    say "restore.sh: 기존 파일 백업 ($bak)"
  fi
  install -m 755 "$SRC_DIR/restore.sh" "$HUB/restore.sh"
  say "restore.sh: 설치 ($HUB/restore.sh)"
fi

# (2) 윈도우 목록
if [ -f "$HUB/windows.tsv" ]; then
  say "windows.tsv: 기존 목록 유지 ($(grep -cvE '^\s*(#|$)' "$HUB/windows.tsv")개 윈도우)"
else
  {
    echo "# claude-rc tmux 윈도우 목록 (윈도우명<TAB>폴더 절대경로). 위에서부터 순서대로 복구."
    printf 'hub\t%s\n' "$ROOT"
  } > "$HUB/windows.tsv"
  say "windows.tsv: 생성 (hub 윈도우 1개)"
fi

# (3) systemd 사용자 서비스
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT="$UNIT_DIR/$UNIT_NAME"
EXEC="$HUB/restore.sh"
case "$EXEC" in "$HOME"/*) EXEC="%h${EXEC#"$HOME"}" ;; esac
mkdir -p "$UNIT_DIR"
tmp="$(mktemp)"
sed "s|^ExecStart=.*|ExecStart=$EXEC|" "$UNIT_SRC" > "$tmp"
if [ -f "$UNIT" ] && cmp -s "$tmp" "$UNIT"; then
  say "서비스 파일: 최신 상태"
  rm -f "$tmp"
else
  install -m 644 "$tmp" "$UNIT"
  rm -f "$tmp"
  say "서비스 파일: 설치 ($UNIT, ExecStart=$EXEC)"
fi

if [ "${HUB_SKIP_SYSTEMD:-0}" = 1 ]; then
  say "systemd: 호출 생략 (HUB_SKIP_SYSTEMD=1)"
elif systemctl --user show-environment >/dev/null 2>&1; then
  systemctl --user daemon-reload
  systemctl --user enable "$UNIT_NAME" >/dev/null 2>&1
  say "systemd: $UNIT_NAME $(systemctl --user is-enabled "$UNIT_NAME" 2>/dev/null || echo unknown)"
  linger="$(loginctl show-user "$(id -un)" -p Linger --value 2>/dev/null || echo unknown)"
  if [ "$linger" = yes ]; then
    say "linger: yes (로그인 없이 부팅 시 실행)"
  else
    say "linger: $linger. 로그인 없이 부팅 시 실행하려면: sudo loginctl enable-linger $(id -un)"
  fi
else
  say "경고: systemd 사용자 관리자에 연결할 수 없음. 서비스 등록 생략. 수동 복구는 $HUB/restore.sh 실행"
fi

say "완료. 다음 단계: HUB_DRY_RUN=1 $HUB/restore.sh 로 계획 확인 후 systemctl --user restart $UNIT_NAME"
