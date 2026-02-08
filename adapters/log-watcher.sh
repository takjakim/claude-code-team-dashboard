#!/usr/bin/env bash
# Log Watcher Status Adapter
# Reads status from Claude Code log/output files
#
# Usage: ./adapters/log-watcher.sh [--config path/to/config.json]
#
# Expected log file location: $LOG_DIR/{pane}.log
# (e.g., .claude-logs/0.log, .claude-logs/1.log)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUS_FILE="$SCRIPT_DIR/team-status.json"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/team-config.json}"
LOG_DIR="${LOG_DIR:-.claude-logs}"
TAIL_LINES="${TAIL_LINES:-50}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --log-dir)
            LOG_DIR="$2"
            shift 2
            ;;
        --lines)
            TAIL_LINES="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Load configuration
if command -v jq &>/dev/null && [ -f "$CONFIG_FILE" ]; then
    PANE_COUNT=$(jq '.team | length' "$CONFIG_FILE")

    get_name() {
        jq -r ".team[$1].name // \"Agent $1\"" "$CONFIG_FILE"
    }

    get_role() {
        jq -r ".team[$1].role // \"Agent\"" "$CONFIG_FILE"
    }

    get_model() {
        jq -r ".team[$1].model // \"Claude\"" "$CONFIG_FILE"
    }

    is_external() {
        jq -r ".team[$1].isExternal // false" "$CONFIG_FILE"
    }
else
    echo "Error: jq required and config file must exist"
    exit 1
fi

# Status detection (same logic as tmux adapter)
detect_status() {
    local content="$1"
    local last_15=$(echo "$content" | tail -15)

    # IDLE indicators FIRST
    if echo "$last_15" | grep -qE "✻ (Baked|Churned|Cogitated|Cooked|Simmered|Worked|Brewed|Stewed|Leavened) for"; then
        echo "TODO"
        return
    fi

    # Active indicators
    if echo "$last_15" | grep -qE "^· [A-Z]|· Processing|· Thinking|· Generating"; then
        echo "DOING"
        return
    fi

    if echo "$last_15" | grep -qE "✶ [A-Z]|✢ [A-Z]|✳ [A-Z]"; then
        echo "DOING"
        return
    fi

    if echo "$last_15" | grep -qE "agents:[0-9]+"; then
        echo "DOING"
        return
    fi

    if echo "$last_15" | grep -qE "⎿  Running"; then
        echo "DOING"
        return
    fi

    if echo "$content" | grep -qE "⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏"; then
        echo "DOING"
        return
    fi

    if echo "$last_15" | grep -qE "⎿  Done$"; then
        echo "DONE"
        return
    fi

    echo "TODO"
}

extract_context_usage() {
    local content="$1"
    local ctx=$(echo "$content" | tail -10 | grep -oE "ctx:[0-9]+" | tail -1 | sed 's/ctx://')
    if [ -n "$ctx" ]; then
        echo "$ctx"
    else
        echo "0"
    fi
}

detect_compress_warning() {
    local content="$1"
    if echo "$content" | tail -15 | grep -qiE "COMPRESS\?|compress\?|compaction"; then
        echo "true"
    else
        echo "false"
    fi
}

extract_task_title() {
    local content="$1"
    local task=""

    task=$(echo "$content" | grep -oE "(Task|Working on|Running|Analyzing):[^$]*" | tail -1 | sed 's/^[^:]*: *//' | head -c 80)

    if [ -z "$task" ]; then
        task=$(echo "$content" | grep -v "^$" | tail -1 | head -c 80)
    fi

    task=$(echo "$task" | tr -d '\n\r' | sed 's/["\\]//g' | xargs 2>/dev/null || echo "$task")

    if [ -z "$task" ]; then
        task="Waiting for assignment"
    fi

    echo "$task"
}

# Build JSON array
JSON_ARRAY="["
FIRST=true

for ((pane=0; pane<PANE_COUNT; pane++)); do
    LOG_FILE="$LOG_DIR/$pane.log"

    # Read log file or use empty content
    if [ -f "$LOG_FILE" ]; then
        CONTENT=$(tail -$TAIL_LINES "$LOG_FILE" 2>/dev/null || echo "")
    else
        CONTENT=""
    fi

    # Detect status and extract info
    if [ -n "$CONTENT" ]; then
        STATUS=$(detect_status "$CONTENT")
        TASK=$(extract_task_title "$CONTENT")
        CTX=$(extract_context_usage "$CONTENT")
        COMPRESS=$(detect_compress_warning "$CONTENT")
    else
        STATUS="TODO"
        TASK="No log file: $LOG_FILE"
        CTX=0
        COMPRESS="false"
    fi

    # Progress based on status
    case "$STATUS" in
        "TODO") PROGRESS=0 ;;
        "DONE") PROGRESS=100 ;;
        "DOING") PROGRESS=$((30 + RANDOM % 50)) ;;
    esac

    NAME=$(get_name $pane)
    ROLE=$(get_role $pane)
    MODEL=$(get_model $pane)

    # External flag
    EXTERNAL=""
    if [ "$(is_external $pane)" = "true" ]; then
        EXTERNAL=', "isExternal": true'
    fi

    # Add comma for non-first items
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        JSON_ARRAY+=","
    fi

    # Escape task for JSON
    TASK_ESCAPED=$(echo "$TASK" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr -d '\n\r')

    JSON_ARRAY+="
    {
      \"pane\": $pane,
      \"name\": \"$NAME\",
      \"model\": \"$MODEL\",
      \"role\": \"$ROLE\",
      \"status\": \"$STATUS\",
      \"progress\": $PROGRESS,
      \"ctx\": $CTX,
      \"compressWarning\": $COMPRESS,
      \"currentTask\": {
        \"title\": \"$TASK_ESCAPED\",
        \"details\": [],
        \"startedAt\": \"\"
      },
      \"recentCompleted\": []$EXTERNAL
    }"
done

JSON_ARRAY+="
  ]"

# Write final JSON
TIMESTAMP=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)
cat > "$STATUS_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "team": $JSON_ARRAY
}
EOF

echo "Status updated from log files: $STATUS_FILE"
