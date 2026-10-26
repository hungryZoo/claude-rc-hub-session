너는 이 머신에 "claude-rc 허브 세션" 환경을 구성한다.
참고 레포: https://github.com/hungryZoo/claude-rc-hub-session

## 설정값
- 프로젝트 상위 폴더: ~/dev
- GitHub 사용자: <GITHUB_ID>
- 커밋 이메일: <EMAIL>
- 기본 GitHub 조직: <ORG> (없으면 개인 계정)

## 1. 환경 확인
- tmux 실행 경로와 버전. snap 설치이고 `tmux -V`가 출력 없이 끝나면 /snap/tmux/current/usr/local/bin/tmux 직접 호출.
- claude CLI 버전과 `claude rc --help` 동작, gh 로그인 상태, git 버전과 전역 사용자 정보
- `systemctl --user` 동작 여부, `loginctl show-user $USER -p Linger` 값
- Bash 샌드박스가 tmux 소켓 접근을 막으면 tmux 명령만 샌드박스 해제로 실행.

## 2. 파일 배치
- 참고 레포를 임시 폴더에 클론.
- hub/restore.sh → ~/dev/.hub/restore.sh (실행 권한 부여)
- ~/dev/.hub/windows.tsv 생성. 첫 줄은 `hub<TAB>$HOME/dev`. tmux `claude-rc` 세션이 이미 있으면 기존 윈도우 이름과 경로를 목록에 반영.
- templates/CLAUDE.md → ~/dev/CLAUDE.md, 설정값 채움. 기존 파일이 있으면 덮어쓰지 말고 병합안 제시.
- systemd/claude-rc-restore.service → ~/.config/systemd/user/. 상위 폴더가 ~/dev가 아니면 ExecStart 경로 수정.

## 3. 검증 (4단계)
(1) `HUB_DRY_RUN=1 ~/dev/.hub/restore.sh` 로 계획 확인
(2) 테스트 소켓으로 재부팅 상황 재현:
    `systemd-run --user --wait -p KillMode=process -E HUB_TMUX_SOCKET=hubtest -E 'HUB_CMD=claude --version; sleep 300' ~/dev/.hub/restore.sh`
    → 모든 윈도우 생성과 각 윈도우의 claude 버전 출력 확인
(3) 같은 테스트 세션에 한 번 더 실행해 "건너뜀" 또는 "유지" 판단 확인 후 `tmux -L hubtest kill-server`
(4) KillMode=process 없이 실행하면 테스트 tmux가 사라지는 점을 이해하고, 실제 서비스 파일에 해당 설정이 있는지 확인

## 4. 시작과 등록
- `~/dev/.hub/restore.sh` 실행으로 `claude-rc` 세션과 hub 윈도우 시작
- 폴더 신뢰 프롬프트가 뜨면 y 전송 후 "Connected" 확인
- `systemctl --user daemon-reload && systemctl --user enable --now claude-rc-restore.service`
- Linger=no면 `sudo loginctl enable-linger $USER` 실행 필요 사실을 나에게 알림

## 5. 보고
- 배치한 파일 목록, 검증 결과, 허브 윈도우 연결 여부와 환경 이름
- 이 머신의 특이사항은 메모리에 기록
