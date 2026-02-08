# claude-code-team-dashboard

Real-time monitoring dashboard for Claude Code agent orchestration systems.

Supports multiple data sources: tmux, log files, file-based status, or custom adapters.

![Dashboard Preview](docs/preview.png)

## Features

- **Real-time Status Monitoring**: Track agent status (DOING/TODO/DONE) with live updates
- **Context Usage Tracking**: Monitor Claude's context window usage with warnings at 80%/90%
- **Activity Feed**: See recent completions and current tasks at a glance
- **Compress Detection**: Automatic warning when context compression is needed
- **Mission Control UI**: Professional dark theme inspired by NASA control rooms

## Quick Start

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

The dashboard detects Claude Code status from tmux pane content:

| Pattern | Status | Meaning |
|---------|--------|---------|
| `✶ Processing…` | DOING | Actively working |
| `✳ Actualizing…` | DOING | Agent execution |
| `⎿ Running` | DOING | Tool execution |
| `✻ Baked for Xm` | TODO | Idle/waiting |
| `thinking` | TODO | Thinking but idle |
| `agents:N` | DOING | N agents running |

## Context Warnings

| Level | Threshold | Indicator |
|-------|-----------|-----------|
| Normal | 0-79% | Green bar |
| Warning | 80-89% | Yellow bar + highlight |
| Critical | 90%+ | Red bar + animation |
| COMPRESS | Detected | Red warning banner |

## Adapters (Alternative Data Sources)

The dashboard works with any data source that generates `team-status.json`. Use adapters for non-tmux setups:

### Demo Mode (No Dependencies)

```bash
# Generate simulated data for testing
watch -n2 ./adapters/demo.sh
```

### File-Based Status

Each agent writes its own status file:

```bash
# Agent writes to: .omc/agent-status/0.json
echo '{"status": "DOING", "task": "Working on feature", "ctx": 45}' > .omc/agent-status/0.json

# Run file-based adapter
watch -n2 ./adapters/file-based.sh
```

### Log File Watcher

Parse Claude Code output logs:

```bash
# Point to log directory
LOG_DIR=.claude-logs watch -n2 ./adapters/log-watcher.sh
```

### Custom Adapter

Create your own by generating `team-status.json`:

```json
{
  "timestamp": "2024-01-01T12:00:00",
  "team": [
    {
      "pane": 0,
      "name": "Agent Name",
      "status": "DOING",
      "progress": 50,
      "ctx": 45,
      "currentTask": {"title": "Task description", "details": []}
    }
  ]
}
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
├── team-status.json    # Generated status (gitignored)
├── team-state.json     # State persistence (gitignored)
├── package.json        # npm configuration
└── README.md           # This file
```

## Development

```bash
# Install dev dependencies
npm install

# Run with auto-reload
npm run dev

# Or manually:
# Terminal 1: Status updater
npm run watch

# Terminal 2: HTTP server
npm run start
```

## Customization

### Adding New Agents

1. Edit `team-config.json` to add team members
2. Update `update-status.sh` functions:
   - `get_name()`
   - `get_role()`
   - `get_model()`

### Theming

CSS variables in `index.html`:

```css
:root {
    --bg-primary: #0a0e14;
    --accent-cyan: #00d9ff;
    --accent-green: #3fb950;
    --accent-amber: #f0883e;
    --accent-red: #f85149;
}
```

## Requirements

- bash 4.0+
- jq (for JSON parsing)
- Python 3 (for http.server) or Node.js (for serve)
- Modern browser (Chrome, Firefox, Safari, Edge)
- tmux 3.0+ (only if using default `update-status.sh`)

## License

MIT

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
