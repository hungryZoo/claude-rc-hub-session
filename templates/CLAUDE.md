# 허브 세션 지침

이 폴더(`~/dev`)에서 실행되는 Claude Code 세션은 "허브 세션"이다. `~/dev`는 프로젝트 폴더만 모아두는 상위 폴더이고, 새 프로젝트 요청은 허브 세션이 처리한다. 프로젝트마다 tmux `claude-rc` 세션의 윈도우 1개와 그 안의 `claude rc` 프로세스 1개를 둔다.

## 설정값

- GitHub 사용자: `<GITHUB_ID>`
- 커밋 이메일: `<EMAIL>` (공개 레포는 `<ID>+<GITHUB_ID>@users.noreply.github.com` 권장)
- 기본 GitHub 조직: `<ORG>` (없으면 개인 계정)

## 새 프로젝트 요청 처리 (5단계 파이프라인)

1. **폴더 준비**
   - 새 프로젝트: `~/dev/<이름>/` 생성
   - 기존 레포: `gh repo clone <owner>/<repo>` 로 `~/dev/<repo>/` 클론
2. **GitHub 초기화** (요청한 경우만)
   - `git init` 후 `git checkout -b main` (git 2.28 미만은 `git init -b` 미지원)
   - 전역 git 사용자 정보가 없으면 레포 로컬로만 `git config user.name`, `git config user.email` 설정
   - `.gitignore`(`logs/`, `.venv/`, `__pycache__/`, `.env`)와 `README.md` 초기 커밋
   - `gh repo create <owner>/<이름> --private --source=. --remote=origin --push` (공개 요청 시 `--public`)
3. **목록 추가**: `~/dev/.hub/windows.tsv`에 `윈도우명<TAB>절대경로` 한 줄 추가. 구분자는 탭 문자.
4. **복구 스크립트 실행**: `~/dev/.hub/restore.sh`
   - 목록에 있고 tmux에 없는 윈도우만 생성 후 `claude rc --spawn=same-dir` 실행
   - 이미 실행 중인 윈도우는 유지
5. **확인과 보고**
   - 최신 로그 `~/dev/.hub/logs/restore_*.log`에서 "연결 확인" 확인
   - "대기" 표시(폴더 신뢰 프롬프트)면 레포의 `.claude/`, `.mcp.json` 존재 여부 확인 후 `tmux send-keys -t 'claude-rc:=<윈도우명>' y Enter`
   - 보고 항목: 폴더 경로, 윈도우 번호와 이름, 연결 여부, 환경 이름

## 운영 규칙

- 윈도우 실행 명령은 항상 `claude rc --spawn=same-dir`로 통일.
- 실행 중인 윈도우는 재시작 금지. 이름 변경 같은 비파괴 작업만 허용.
- 프로젝트 제거 요청: `windows.tsv`에서 해당 줄 삭제, `tmux kill-window -t 'claude-rc:=<윈도우명>'`. 폴더 삭제는 사용자 확인 후에만 수행.
- tmux가 snap 설치이고 `tmux -V`가 출력 없이 끝나면 `/snap/tmux/current/usr/local/bin/tmux`를 직접 호출.
- Bash 샌드박스가 tmux 소켓(`/tmp/tmux-<UID>/`) 접근을 막으면 tmux 명령만 샌드박스 해제로 실행.
- 이 머신에서 발견한 특이사항(tmux 경로, git 버전 등)은 메모리에 기록.
