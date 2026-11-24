---
name: setup
description: 'rc-hub 초기 설정. 복구 스크립트, 윈도우 목록, systemd 사용자 서비스를 설치하고 tmux claude-rc 세션과 허브 윈도우를 시작한다. 새 머신에서 한 번 실행하고, 플러그인 업데이트 후 설치본을 갱신할 때 다시 실행한다.'
disable-model-invocation: true
argument-hint: '[프로젝트 상위 폴더, 기본 ~/dev]'
---

# rc-hub 초기 설정

프로젝트 상위 폴더 `<ROOT>`는 인자가 있으면 그 경로, 없으면 `~/dev`다. 인자: `$ARGUMENTS`

설치 위치는 `<ROOT>/.hub`다. 플러그인 설치 경로는 업데이트 때마다 바뀌므로, systemd 서비스는 플러그인 폴더가 아니라 `<ROOT>/.hub/restore.sh` 설치본을 실행한다. 이 스킬은 여러 번 실행해도 안전하다. 플러그인 업데이트 후 다시 실행하면 설치본만 갱신하고 실행 중인 윈도우는 건드리지 않는다.

Bash 샌드박스가 켜져 있으면 아래의 tmux, systemctl, `install.sh`, `restore.sh` 호출은 샌드박스 밖에서 실행한다.

## 1. 환경 확인

| 항목 | 확인 방법 | 미충족 시 |
|---|---|---|
| tmux | `/snap/tmux/current/usr/local/bin/tmux -V`, 없으면 `tmux -V` | 설치 안내 후 중단 |
| Claude Code Remote Control | `claude rc --help` | 구독 Claude 계정 로그인 안내 후 중단 |
| systemd 사용자 관리자 | `systemctl --user show-environment` | 서비스 등록 없이 진행. 재부팅 자동 복구가 안 된다는 사실을 보고 |
| GitHub CLI | `gh auth status` | 진행. 레포 생성과 클론이 안 된다는 사실을 보고 |
| git | `git --version`, `git config --global user.name` | 진행. 버전과 전역 사용자 정보 유무를 메모리에 기록 |

snap으로 설치한 tmux는 `/snap/bin/tmux`가 Claude Code의 Bash에서 출력 없이 종료될 수 있다. 이 경우 실제 바이너리 `/snap/tmux/current/usr/local/bin/tmux`를 쓴다. 이하 `<TMUX>`는 이렇게 정한 실행 파일이다.

## 2. 설치

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hub/install.sh" <ROOT>
```

설치 스크립트가 하는 일은 3가지다.

1. `<ROOT>/.hub/restore.sh` 복사. 기존 파일과 내용이 다르면 `restore.sh.bak-<시각>`으로 백업한 뒤 교체.
2. `<ROOT>/.hub/windows.tsv` 생성. 이미 있으면 그대로 둔다. 새로 만들 때는 `hub` 윈도우 한 줄만 넣는다.
3. `~/.config/systemd/user/claude-rc-restore.service` 배치, `daemon-reload`, `enable`. linger 상태 출력.

tmux `claude-rc` 세션이 이미 있고 목록에 없는 윈도우가 있으면 목록에 반영한다. `<TMUX> list-windows -t claude-rc -F '#{window_name}	#{pane_current_path}'` 결과에서 `claude`를 실행 중인 윈도우를 `윈도우명<TAB>절대경로` 형식으로 추가한다. 윈도우명이 중복되면 고유한 이름으로 바꾸고(`rename-window`) 그 사실을 보고한다.

## 3. 계획 확인

```bash
HUB_DRY_RUN=1 <ROOT>/.hub/restore.sh
```

실행 없이 윈도우별 판단(생성, 재실행, 유지, 건너뜀)만 출력한다. 예상과 다르면 여기서 멈추고 보고한다.

## 4. 시작

1. `systemctl --user restart claude-rc-restore.service` 실행. 부팅 때와 같은 조건으로 복구 스크립트가 돌고, tmux 서버가 로그인 세션과 분리된다. systemd 사용자 관리자가 없으면 `<ROOT>/.hub/restore.sh`를 직접 실행.
2. 최신 로그 확인: `cat "$(ls -1t <ROOT>/.hub/logs/restore_*.log | head -1)"`
3. `대기 [hub]`가 있으면 폴더 신뢰 확인 프롬프트다. `<ROOT>`는 사용자가 직접 지정한 자신의 프로젝트 상위 폴더이므로 `<TMUX> send-keys -t 'claude-rc:=hub' y Enter`로 승인하고, 5-10초 뒤 `<TMUX> capture-pane -p -t 'claude-rc:=hub'`에서 `Connected`를 확인.
4. 이미 실행 중이던 윈도우는 `유지`로 표시된다. 재시작하지 않는다.

## 5. 보고

- 설치한 파일 위치와 서비스 등록 상태.
- linger가 `yes`가 아니면, 로그인 없이 부팅 직후 복구되려면 사용자가 직접 `sudo loginctl enable-linger <사용자>`를 실행해야 한다는 사실.
- hub 윈도우 연결 여부와 환경 이름.
- 사용법: Claude 모바일 앱이나 claude.ai/code에서 hub 환경을 선택하고 "foo 프로젝트 만들어줘"처럼 요청.
- 이 설정용 세션은 종료해도 된다. 이후에는 tmux `claude-rc` 세션의 hub 윈도우가 허브 역할을 맡는다.
- 이 머신의 특이사항(tmux 경로, git 버전, 전역 git 사용자 정보 유무)은 메모리에 기록.
