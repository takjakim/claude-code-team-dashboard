# claude-code-team-dashboard

Claude Code 에이전트 오케스트레이션 시스템을 위한 실시간 모니터링 대시보드.

tmux, 로그 파일, 파일 기반 상태 등 다양한 데이터 소스 지원.

![Dashboard Preview](docs/preview.png)

## 기능

- **실시간 상태 모니터링**: 에이전트 상태(DOING/TODO/DONE) 실시간 추적
- **컨텍스트 사용량 추적**: Claude 컨텍스트 윈도우 사용량 모니터링 (80%/90% 경고)
- **활동 피드**: 최근 완료 작업과 현재 작업 한눈에 보기
- **압축 감지**: 컨텍스트 압축 필요시 자동 경고
- **미션 컨트롤 UI**: NASA 관제실 스타일 다크 테마

## 빠른 시작

### 1단계: tmux에서 에이전트 팀 구성

먼저 tmux로 에이전트 팀을 구성하세요:

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

아래 프롬프트를 Claude Code에 붙여넣기:

```
Clone https://github.com/takjakim/claude-code-team-dashboard to ./team-dashboard and configure it for my current tmux session. Update team-config.json with appropriate team names for my panes.
```

### 수동 설치

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

대시보드는 tmux pane 내용에서 Claude Code 상태를 감지합니다:

| 패턴 | 상태 | 의미 |
|------|------|------|
| `✶ Processing…` | DOING | 작업 중 |
| `✳ Actualizing…` | DOING | 에이전트 실행 중 |
| `⎿ Running` | DOING | 도구 실행 중 |
| `✻ Baked for Xm` | TODO | 대기 중 |
| `thinking` | TODO | 생각 중 (대기) |
| `agents:N` | DOING | N개 에이전트 실행 중 |

## 컨텍스트 경고

| 레벨 | 임계값 | 표시 |
|------|--------|------|
| 정상 | 0-79% | 초록색 바 |
| 경고 | 80-89% | 노란색 바 + 하이라이트 |
| 위험 | 90%+ | 빨간색 바 + 애니메이션 |
| COMPRESS | 감지됨 | 빨간색 경고 배너 |

## 어댑터 (대체 데이터 소스)

대시보드는 `team-status.json`을 생성하는 모든 데이터 소스와 작동합니다. tmux 없이 사용하려면 어댑터를 사용하세요:

### 데모 모드 (의존성 없음)

```bash
# 테스트용 시뮬레이션 데이터 생성
watch -n2 ./adapters/demo.sh
```

### 파일 기반 상태

각 에이전트가 자체 상태 파일 작성:

```bash
# 에이전트가 작성: .omc/agent-status/0.json
echo '{"status": "DOING", "task": "기능 작업 중", "ctx": 45}' > .omc/agent-status/0.json

# 파일 기반 어댑터 실행
watch -n2 ./adapters/file-based.sh
```

### 로그 파일 감시

Claude Code 출력 로그 파싱:

```bash
# 로그 디렉토리 지정
LOG_DIR=.claude-logs watch -n2 ./adapters/log-watcher.sh
```

### 커스텀 어댑터

`team-status.json`을 생성하여 직접 만들 수 있습니다:

```json
{
  "timestamp": "2024-01-01T12:00:00",
  "team": [
    {
      "pane": 0,
      "name": "에이전트 이름",
      "status": "DOING",
      "progress": 50,
      "ctx": 45,
      "currentTask": {"title": "작업 설명", "details": []}
    }
  ]
}
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
├── team-status.json    # 생성된 상태 (gitignore)
├── team-state.json     # 상태 지속성 (gitignore)
├── package.json        # npm 설정
└── README.md           # 영문 문서
```

## 개발

```bash
# 개발 의존성 설치
npm install

# 자동 리로드로 실행
npm run dev

# 또는 수동으로:
# 터미널 1: 상태 업데이터
npm run watch

# 터미널 2: HTTP 서버
npm run start
```

## 커스터마이징

### 새 에이전트 추가

1. `team-config.json`에서 팀 멤버 추가
2. tmux에서 해당 pane 생성

### 테마 변경

`index.html`의 CSS 변수:

```css
:root {
    --bg-primary: #0a0e14;
    --accent-cyan: #00d9ff;
    --accent-green: #3fb950;
    --accent-amber: #f0883e;
    --accent-red: #f85149;
}
```

## Claude Code 프롬프트

아래 프롬프트를 Claude Code 에이전트에 붙여넣기:

### 초기 설정
```
Clone https://github.com/takjakim/claude-code-team-dashboard and configure it for my tmux session. Detect my current pane layout and set up team-config.json accordingly. Then start the dashboard on port 8080.
```

### 대시보드 시작 (이미 설치됨)
```
Start the team dashboard - run update-status.sh every 2 seconds and serve on port 8080.
```

### 팀 재설정
```
Update team-dashboard/team-config.json based on my current tmux pane layout. Detect agent names and roles from pane content.
```

### 데모 모드 (에이전트 없이 테스트)
```
Run team-dashboard in demo mode to preview the UI without actual agents.
```

## 요구사항

- bash 4.0+
- jq (JSON 파싱용)
- Python 3 (http.server용) 또는 Node.js (serve용)
- 모던 브라우저 (Chrome, Firefox, Safari, Edge)
- tmux 3.0+ (기본 `update-status.sh` 사용시에만)

## 라이선스

MIT

## 기여하기

1. 저장소 포크
2. 기능 브랜치 생성 (`git checkout -b feature/amazing-feature`)
3. 변경사항 커밋 (`git commit -m 'Add amazing feature'`)
4. 브랜치에 푸시 (`git push origin feature/amazing-feature`)
5. Pull Request 열기
