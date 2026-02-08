# claude-code-team-dashboard

English | [한국어](README.ko.md)

Claude Code 에이전트 오케스트레이션 시스템을 위한 실시간 모니터링 대시보드.

![Dashboard Preview](docs/preview.png)

## Claude Code로 설치하기

**이 프롬프트를 아무 Claude Code 에이전트에 붙여넣기만 하면 됩니다:**

```
Clone https://github.com/takjakim/claude-code-team-dashboard and configure it for my tmux session. Detect my current pane layout and set up team-config.json accordingly. Then start the dashboard on port 8080.
```

끝! Claude가 알아서 다 해줍니다.

### 기타 유용한 프롬프트

| 작업 | 프롬프트 |
|------|----------|
| 대시보드 시작 | `Start the team dashboard on port 8080` |
| 팀 재설정 | `Update team-dashboard config based on my current tmux panes` |
| 데모 모드 | `Run team-dashboard in demo mode` |

---

## 기능

- **실시간 상태 모니터링**: 에이전트 상태(DOING/TODO/DONE) 실시간 추적
- **컨텍스트 사용량 추적**: Claude 컨텍스트 윈도우 사용량 모니터링 (80%/90% 경고)
- **활동 피드**: 최근 완료 작업과 현재 작업 한눈에 보기
- **압축 감지**: 컨텍스트 압축 필요시 자동 경고
- **미션 컨트롤 UI**: NASA 관제실 스타일 다크 테마
- **다양한 데이터 소스**: tmux, 로그 파일, 파일 기반 상태, 커스텀 어댑터

## 수동 설치

### 1단계: tmux에서 에이전트 팀 구성

```bash
# 6개 pane의 tmux 세션 생성
tmux new-session -s my-team -n agents
tmux split-window -h
tmux split-window -v
tmux select-pane -t 0 && tmux split-window -v
tmux select-pane -t 2 && tmux split-window -v
tmux select-pane -t 4 && tmux split-window -v
```

각 pane에서 Claude Code(또는 다른 에이전트)를 실행하세요.

### 2단계: 대시보드 설치

```bash
# 1. 저장소 클론
git clone https://github.com/takjakim/claude-code-team-dashboard.git
cd claude-code-team-dashboard

# 2. 팀 설정 (team-config.json 편집)
vim team-config.json

# 3. 상태 업데이터 시작
watch -n2 ./update-status.sh

# 4. 대시보드 서버 시작
python3 -m http.server 8080

# 5. 브라우저에서 열기
open http://localhost:8080
```

## 설정

### team-config.json

```json
{
  "project": {
    "name": "프로젝트 이름",
    "subtitle": "AI 에이전트 오케스트레이션 시스템"
  },
  "tmux": {
    "session": "세션-이름",
    "window": 0
  },
  "team": [
    {
      "pane": 0,
      "name": "에이전트 이름",
      "model": "Claude",
      "role": "에이전트 역할",
      "isExternal": false
    }
  ],
  "thresholds": {
    "ctx": {
      "warning": 80,
      "critical": 90
    }
  }
}
```

### 환경 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `TMUX_SESSION` | 설정 파일 참조 | tmux 세션 이름 오버라이드 |
| `TMUX_WINDOW` | 0 | tmux 윈도우 번호 |
| `PORT` | 8080 | HTTP 서버 포트 |

## 상태 감지

| 패턴 | 상태 | 의미 |
|------|------|------|
| `✶ Processing…` | DOING | 작업 중 |
| `✳ Actualizing…` | DOING | 에이전트 실행 중 |
| `⎿ Running` | DOING | 도구 실행 중 |
| `✻ Baked for Xm` | TODO | 대기 중 |
| `agents:N` | DOING | N개 에이전트 실행 중 |

## 컨텍스트 경고

| 레벨 | 임계값 | 표시 |
|------|--------|------|
| 정상 | 0-79% | 초록색 바 |
| 경고 | 80-89% | 노란색 바 + 하이라이트 |
| 위험 | 90%+ | 빨간색 바 + 애니메이션 |
| COMPRESS | 감지됨 | 빨간색 경고 배너 |

## 어댑터 (tmux 없이)

tmux 없이 사용하려면 어댑터 사용:

```bash
# 데모 모드 (의존성 없음)
watch -n2 ./adapters/demo.sh

# 파일 기반 상태
watch -n2 ./adapters/file-based.sh

# 로그 파일 감시
LOG_DIR=.claude-logs watch -n2 ./adapters/log-watcher.sh
```

## 파일 구조

```
claude-code-team-dashboard/
├── index.html          # 대시보드 UI
├── update-status.sh    # tmux 상태 어댑터 (기본)
├── adapters/
│   ├── demo.sh         # 데모/테스트 데이터 생성기
│   ├── file-based.sh   # 파일 기반 상태 리더
│   └── log-watcher.sh  # 로그 파일 파서
├── team-config.json    # 팀 설정
└── package.json        # npm 설정
```

## 요구사항

- bash 4.0+
- jq (JSON 파싱용)
- Python 3 또는 Node.js (HTTP 서버용)
- 모던 브라우저
- tmux 3.0+ (기본 어댑터 사용시에만)

## 라이선스

MIT
