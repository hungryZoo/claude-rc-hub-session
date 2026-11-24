너는 이 머신에 "claude-rc 허브 세션" 환경을 플러그인 없이 구성한다.
참고 레포: https://github.com/hungryZoo/claude-rc-hub-session

## 설정값
- 프로젝트 상위 폴더: ~/dev
- GitHub 사용자: <GITHUB_ID>
- 커밋 이메일: <EMAIL>
- 기본 GitHub 조직: <ORG> (없으면 개인 계정)

## 1. 환경 확인
- tmux 실행 경로와 버전. snap 설치이고 `tmux -V`가 출력 없이 끝나면 /snap/tmux/current/usr/local/bin/tmux 직접 호출.
- `claude rc --help` 동작, gh 로그인 상태, git 버전과 전역 사용자 정보, `systemctl --user show-environment` 동작
- Bash 샌드박스가 tmux 소켓 접근을 막으면 tmux, systemctl, 설치 스크립트, 복구 스크립트 호출만 샌드박스 해제로 실행.

## 2. 설치
- 참고 레포를 임시 폴더에 클론하고 `hub/install.sh ~/dev` 실행. 복구 스크립트, 윈도우 목록, systemd 사용자 서비스가 배치됨.
- tmux `claude-rc` 세션이 이미 있으면 기존 윈도우 이름과 경로를 ~/dev/.hub/windows.tsv에 반영.
- templates/CLAUDE.md → ~/dev/CLAUDE.md, 설정값 채움. 기존 파일이 있으면 덮어쓰지 말고 병합안 제시.

## 3. 검증과 시작
(1) `HUB_DRY_RUN=1 ~/dev/.hub/restore.sh` 로 계획 확인
(2) 테스트 소켓으로 재부팅 상황 재현 후 정리:
    `systemd-run --user --wait -p KillMode=process -E HUB_TMUX_SOCKET=hubtest -E 'HUB_CMD=claude --version; sleep 300' ~/dev/.hub/restore.sh`
    `tmux -L hubtest list-windows -t claude-rc` 확인 후 `tmux -L hubtest kill-server`
(3) `systemctl --user restart claude-rc-restore.service` 로 실제 시작, 최신 로그 확인
(4) 로그에 "대기 [hub]"가 있으면 hub 윈도우에 y 전송 후 "Connected" 확인

## 4. 보고
- 배치한 파일 목록, 검증 결과, 허브 윈도우 연결 여부와 환경 이름
- Linger=no면 `sudo loginctl enable-linger $USER` 실행 필요 사실을 나에게 알림
- 이 머신의 특이사항은 메모리에 기록
