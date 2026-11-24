---
name: new-project
description: 'rc-hub 허브 세션의 프로젝트 세션 관리 절차. 새 프로젝트 폴더 생성 또는 GitHub 레포 클론, 선택적 GitHub 레포 초기화, tmux claude-rc 세션에 윈도우 추가, claude rc(Remote Control) 실행, 재부팅 복구 목록 등록까지 수행한다. 프로젝트 세션의 이름 변경과 제거도 다룬다. "foo 프로젝트 만들어줘", "foo 세션 만들어줘", "내 깃허브에서 foo 클론해서 리모트 세션 열어줘", "foo를 my-org에 프라이빗으로 초기화해줘", "foo를 bar로 바꿔줘", "foo 세션 내려줘" 같은 요청에 사용. Use when the user asks to create or start a new project, clone a repository and open a Remote Control session for it, or rename or remove a project session.'
---

# 프로젝트 세션 관리 (rc-hub)

프로젝트 하나는 폴더 1개, tmux `claude-rc` 세션의 윈도우 1개, 그 안의 `claude rc` 프로세스 1개로 구성된다. 윈도우 목록 `windows.tsv`가 재부팅 복구의 기준이다. 그래서 윈도우를 직접 만들지 않고, 목록에 추가한 뒤 복구 스크립트로 띄운다.

## 사전 확인

1. **허브 폴더 `<HUB>`**: `~/dev/.hub/restore.sh`가 있으면 `<HUB>`는 `~/dev/.hub`. 없으면 `systemctl --user cat claude-rc-restore.service`의 `ExecStart` 경로가 있는 폴더. 프로젝트 상위 폴더 `<ROOT>`는 `<HUB>`의 상위 폴더.
2. **미설치 시**: 둘 다 없으면 여기서 중단하고, 이 머신의 터미널에서 `/rc-hub:setup`을 먼저 실행해야 한다고 알린다.
3. **tmux 실행 파일 `<TMUX>`**: `/snap/tmux/current/usr/local/bin/tmux`가 있으면 그 경로, 없으면 `tmux`. snap 설치의 `/snap/bin/tmux`는 Claude Code의 Bash에서 출력 없이 종료될 수 있다.
4. **샌드박스**: Bash 샌드박스가 켜져 있으면 tmux, systemctl, `restore.sh` 호출은 샌드박스 밖에서 실행한다. 샌드박스 안에서는 tmux 소켓(`/tmp/tmux-<UID>/`)에 접근할 수 없다.

## 새 프로젝트 (5단계 파이프라인)

1. **폴더 준비**
   - 새 프로젝트: `<ROOT>/<이름>` 생성. 같은 이름의 폴더가 이미 있으면 내용을 확인하고 그 폴더를 그대로 쓴다는 사실을 보고에 포함.
   - 기존 레포: `cd <ROOT> && gh repo clone <owner>/<repo>`. owner 언급 없이 "내 깃허브"라고 하면 `gh api user --jq .login`의 계정.
2. **GitHub 초기화** (요청한 경우만)
   - `git init` 후 `git checkout -b main`. git 2.28 미만은 `git init -b`를 지원하지 않는다.
   - `.gitignore`(`logs/`, `.venv/`, `__pycache__/`, `.env`)와 `README.md`를 만들고 초기 커밋.
   - `gh repo create <owner>/<이름> --private --source=. --remote=origin --push`. 공개 요청이 있을 때만 `--public`. owner 언급이 없으면 로그인 계정.
3. **목록 추가**: `<HUB>/windows.tsv` 끝에 `윈도우명<TAB>폴더 절대경로` 한 줄 추가. 구분자는 탭 문자이므로 `printf '%s\t%s\n' <윈도우명> <절대경로> >> <HUB>/windows.tsv` 형태로 쓴다. 윈도우명은 폴더명과 같게 한다. 같은 윈도우명이 이미 있으면 추가하지 않는다.
4. **실행**: `<HUB>/restore.sh` 실행. 목록에 있고 tmux에 없는 윈도우만 만들어 `claude rc --spawn=same-dir`을 실행하고, 실행 중인 윈도우는 그대로 둔다. tmux `claude-rc` 세션 자체가 없으면(`<TMUX> has-session -t claude-rc` 실패) `systemctl --user restart claude-rc-restore.service`로 실행해 tmux 서버를 로그인 세션과 분리한다.
5. **확인과 보고**: 스크립트 출력(같은 내용이 `<HUB>/logs/restore_*.log`에 기록됨)에서 새 윈도우의 줄을 확인.
   - `연결 확인 [이름]`: 완료.
   - `대기 [이름]`: 폴더 신뢰 확인 프롬프트가 떠 있음. 아래 "폴더 신뢰 승인" 절차 수행.
   - `경고 [이름]`: `<TMUX> capture-pane -p -t 'claude-rc:=<윈도우명>'`으로 화면을 보고 원인(로그인 만료, 네트워크 등)을 보고.
   - 보고 항목: 폴더 경로, 윈도우 번호와 이름, 연결 여부, 환경 이름(화면의 `Connected` 아래에 표시), 만든 경우 GitHub 레포 주소와 공개 범위.

### git 사용자 정보

전역 git 사용자 정보가 없으면 커밋이 실패한다. 이 경우 레포 로컬로만 설정하고 전역 설정은 바꾸지 않는다.

- 클론한 레포: 기존 커밋의 작성자 정보(`git log --format='%an <%ae>' | sort | uniq -c`)와 같게.
- 새 레포: 이름은 GitHub 로그인. 이메일은 사용자가 지정했거나 메모리에 기록된 값, 없으면 `gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"'`.

### 폴더 신뢰 승인

처음 실행하는 경로에서는 `Trust <경로>? [y/N]` 프롬프트가 뜬다. 승인하면 그 폴더의 프로젝트 설정(훅, MCP 서버, 권한 규칙)이 세션에 적용된다.

- 방금 만든 빈 폴더, 또는 사용자 본인 레포이고 `.claude/`와 `.mcp.json`이 없으면: `<TMUX> send-keys -t 'claude-rc:=<윈도우명>' y Enter`로 승인.
- `.claude/`나 `.mcp.json`이 있거나 다른 사람의 레포면: 해당 파일 내용을 요약해 보고하고 사용자 확인을 받은 뒤 승인.
- 승인 후 5-10초 뒤 화면에서 `Connected`를 확인.

## 이름 변경

실행 중인 `claude rc`를 멈춰야 하므로 그 윈도우에서 진행 중인 원격 세션이 끊긴다. 해당 폴더를 작업 폴더로 하는 claude 프로세스가 `claude rc` 외에 더 있으면 진행 중인 세션이 있는 것이다. 이 경우 사용자에게 알리고 확인을 받은 뒤 진행한다.

1. `<TMUX> send-keys -t 'claude-rc:=<옛 이름>' C-c`로 종료하고, 셸 프롬프트 복귀를 확인한 뒤 `<TMUX> kill-window -t 'claude-rc:=<옛 이름>'`.
2. 폴더 이름 변경(`mv`).
3. `windows.tsv`의 해당 줄을 새 이름과 새 경로로 수정.
4. 대화 기록과 프로젝트 메모리 이어받기: `~/.claude/projects/` 아래에서 옛 경로에 해당하는 폴더(경로의 `/`를 `-`로 바꾼 이름)의 내용을 새 경로에 해당하는 폴더로 복사. 원본은 지우지 않는다.
5. `<HUB>/restore.sh` 실행 후 "새 프로젝트"의 5단계와 같은 방식으로 확인. 새 경로이므로 신뢰 프롬프트가 다시 뜬다.
6. GitHub 레포 이름은 바꾸지 않는다. 요청이 있을 때만 `gh repo rename`.

## 제거

1. `windows.tsv`에서 해당 줄 삭제.
2. `<TMUX> kill-window -t 'claude-rc:=<윈도우명>'`.
3. 폴더와 GitHub 레포는 삭제하지 않는다. 삭제 요청이 명시적으로 있을 때만, 대상 경로를 확인받은 뒤 수행.

## 운영 규칙

- 윈도우 실행 명령은 `claude rc --spawn=same-dir`로 통일한다. 이 옵션이 없으면 스폰 모드 선택 프롬프트에서 멈춘다.
- 실행 중인 다른 윈도우는 재시작하지 않는다. 원격 연결 이름을 바꾸기 위한 재시작도 사용자 확인 후에만 수행.
- `<HUB>/restore.sh`가 `${CLAUDE_PLUGIN_ROOT}/hub/restore.sh`와 다르면(`cmp -s`) 보고 끝에 한 줄로 알린다. `/rc-hub:setup`을 다시 실행하면 설치본이 갱신된다.
- 이 머신에서 확인한 특이사항(tmux 경로, git 버전, 자주 쓰는 GitHub 조직 등)은 메모리에 기록해 다음 요청에 재사용.
