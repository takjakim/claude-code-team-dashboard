# Claude Code Team Dashboard

[한국어](README.ko.md) | English

**Real-time dashboard for multi-agent work in tmux** — see who is doing what (DOING/TODO/DONE), track context usage, and catch COMPRESS moments early.

![Dashboard Preview](docs/preview.png)

## Quickstart

```bash
git clone https://github.com/takjakim/claude-code-team-dashboard.git
cd claude-code-team-dashboard
watch -n2 ./update-status.sh
python3 -m http.server 8080
```

Open: <http://localhost:8080>

## Install with Claude Code

**Just paste this prompt into any Claude Code agent:**

```
Clone https://github.com/takjakim/claude-code-team-dashboard and configure it for my tmux session. Detect my current pane layout and set up team-config.json accordingly. Then start the dashboard on port 8080.
```

That's it! Claude will handle everything.

### Other Useful Prompts

| Task | Prompt |
|------|--------|
| Start Dashboard | `Start the team dashboard on port 8080` |
| Reconfigure Team | `Update team-dashboard config based on my current tmux panes` |
| Demo Mode | `Run team-dashboard in demo mode` |

---

## Why this exists

Once you run 4–8 agents in tmux panes, you lose time on:
- jumping between panes to check status
- missing context limits (80% / 90%)
- noticing COMPRESS too late

This dashboard keeps the whole team visible, continuously.

## Features

- **Real-time Status Monitoring**: Track agent status (DOING/TODO/DONE) with live updates
- **Context Usage Tracking**: Monitor Claude's context window usage with warnings at 80%/90%
- **Activity Feed**: See recent completions and current tasks at a glance
- **Compress Detection**: Automatic warning when context compression is needed
- **Mission Control UI**: Professional dark theme inspired by NASA control rooms
- **Multiple Data Sources**: tmux, log files, file-based status, or custom adapters

## Manual Installation

### Step 1: Set Up Your Agent Team in tmux

```bash
# Create a 6-pane tmux session
tmux new-session -s my-team -n agents
tmux split-window -h
tmux split-window -v
tmux select-pane -t 0 && tmux split-window -v
tmux select-pane -t 2 && tmux split-window -v
tmux select-pane -t 4 && tmux split-window -v
```

Launch Claude Code (or other agents) in each pane.

### Step 2: Install Dashboard

```bash
# 1. Clone the repository
git clone https://github.com/takjakim/claude-code-team-dashboard.git
cd claude-code-team-dashboard

# 2. Configure your team (edit team-config.json)
vim team-config.json

# 3. Start the status updater
watch -n2 ./update-status.sh

# 4. Serve the dashboard
python3 -m http.server 8080

# 5. Open in browser
open http://localhost:8080
```

## Configuration

### team-config.json

```json
{
  "project": {
    "name": "YOUR PROJECT",
    "subtitle": "AI Agent Orchestration System"
  },
  "tmux": {
    "session": "your-session-name",
    "window": 0
  },
  "team": [
    {
      "pane": 0,
      "name": "Agent Name",
      "model": "Claude",
      "role": "Agent Role",
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

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TMUX_SESSION` | from config | Override tmux session name |
| `TMUX_WINDOW` | 0 | tmux window number |
| `PORT` | 8080 | HTTP server port |

## Status Detection

| Pattern | Status | Meaning |
|---------|--------|---------|
| `✶ Processing…` | DOING | Actively working |
| `✳ Actualizing…` | DOING | Agent execution |
| `⎿ Running` | DOING | Tool execution |
| `✻ Baked for Xm` | TODO | Idle/waiting |
| `agents:N` | DOING | N agents running |

## Context Warnings

| Level | Threshold | Indicator |
|-------|-----------|-----------|
| Normal | 0-79% | Green bar |
| Warning | 80-89% | Yellow bar + highlight |
| Critical | 90%+ | Red bar + animation |
| COMPRESS | Detected | Red warning banner |

## Adapters (Non-tmux)

Use adapters for non-tmux setups:

```bash
# Demo mode (no dependencies)
watch -n2 ./adapters/demo.sh

# File-based status
watch -n2 ./adapters/file-based.sh

# Log file watcher
LOG_DIR=.claude-logs watch -n2 ./adapters/log-watcher.sh
```

## File Structure

```
claude-code-team-dashboard/
├── index.html          # Dashboard UI
├── update-status.sh    # tmux status adapter (default)
├── adapters/
│   ├── demo.sh         # Demo/test data generator
│   ├── file-based.sh   # File-based status reader
│   └── log-watcher.sh  # Log file parser
├── team-config.json    # Team configuration
└── package.json        # npm configuration
```

## Requirements

- bash 4.0+
- jq (for JSON parsing)
- Python 3 or Node.js (for http server)
- Modern browser
- tmux 3.0+ (only if using default adapter)

## License

MIT
