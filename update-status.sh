#!/usr/bin/env bash
# Team Dashboard - Real-time tmux Status Updater
# Captures pane content and detects agent states
#
# Usage: ./update-status.sh [--config path/to/config.json]
#
# Environment variables:
#   TMUX_SESSION - Override tmux session name
#   CONFIG_FILE  - Path to team-config.json

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_FILE="$SCRIPT_DIR/team-status.json"
STATE_FILE="$SCRIPT_DIR/team-state.json"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/team-config.json}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Load configuration from JSON if jq is available
if command -v jq &>/dev/null && [ -f "$CONFIG_FILE" ]; then
    SESSION="${TMUX_SESSION:-$(jq -r '.tmux.session // "hwatu-team"' "$CONFIG_FILE")}"
    WINDOW=$(jq -r '.tmux.window // 0' "$CONFIG_FILE")
    PANE_COUNT=$(jq '.team | length' "$CONFIG_FILE")

    # Dynamic team configuration from JSON
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
    # Fallback: hardcoded configuration
    SESSION="${TMUX_SESSION:-hwatu-team}"
    WINDOW=0
    PANE_COUNT=6

    get_name() {
        case $1 in
            0) echo "UI/UX Reviewer" ;;
            1) echo "QA Engineer" ;;
            2) echo "Logic Analyst" ;;
            3) echo "SFX/VFX Specialist" ;;
            4) echo "opencode" ;;
            5) echo "Dashboard Dev" ;;
            *) echo "Agent $1" ;;
        esac
    }

    get_role() {
        case $1 in
            0) echo "Design Quality Assurance" ;;
            1) echo "Quality Assurance" ;;
            2) echo "Game Logic Validation" ;;
            3) echo "Effects & Animation" ;;
            4) echo "External Partner" ;;
            5) echo "Orchestration" ;;
            *) echo "Agent" ;;
        esac
    }

    get_model() {
        case $1 in
            4) echo "Gemini" ;;
            *) echo "Claude" ;;
        esac
    }

    is_external() {
        [ "$1" -eq 4 ] && echo "true" || echo "false"
    }
fi

# Extract context usage percentage from pane content
extract_context_usage() {
    local content="$1"
    # Look for ctx:XX% pattern in the last 10 lines
    local ctx=$(echo "$content" | tail -10 | grep -oE "ctx:[0-9]+" | tail -1 | sed 's/ctx://')
    if [ -n "$ctx" ]; then
        echo "$ctx"
    else
        echo "0"
    fi
}

# Detect COMPRESS warning
detect_compress_warning() {
    local content="$1"
    # Check for COMPRESS? in the last 15 lines
    if echo "$content" | tail -15 | grep -qiE "COMPRESS\?|compress\?|compaction"; then
        echo "true"
    else
        echo "false"
    fi
}

# Detect status from pane content (Claude Code specific)
detect_status() {
    local content="$1"
    local last_15=$(echo "$content" | tail -15)

    # === IDLE indicators FIRST (definitively finished waiting) ===
    # ✻ Baked/Churned/Cogitated/Worked = finished, now waiting
    if echo "$last_15" | grep -qE "✻ (Baked|Churned|Cogitated|Cooked|Simmered|Worked|Brewed|Stewed|Leavened) for"; then
        echo "TODO"
        return
    fi

    # === ACTIVE indicators (actually working) ===
    # · Processing…, · Thinking… = currently processing (middle dot)
    if echo "$last_15" | grep -qE "^· [A-Z]|· Processing|· Thinking|· Generating"; then
        echo "DOING"
        return
    fi

    # ✶ ✢ ✳ active indicators (various symbols)
    if echo "$last_15" | grep -qE "✶ [A-Z]|✢ [A-Z]|✳ [A-Z]"; then
        echo "DOING"
        return
    fi

    # agents:N in status bar = agents running
    if echo "$last_15" | grep -qE "agents:[0-9]+"; then
        echo "DOING"
        return
    fi

    # ⎿  Running = tool currently executing
    if echo "$last_15" | grep -qE "⎿  Running"; then
        echo "DOING"
        return
    fi

    # ⏺ Tool/Agent execution with Running
    if echo "$last_15" | grep -qE "Running [0-9]+ .* agents|Running PreToolUse|Running PostToolUse"; then
        echo "DOING"
        return
    fi

    # Spinners (generic)
    if echo "$content" | grep -qE "⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏"; then
        echo "DOING"
        return
    fi

    # === DONE indicators (just completed) ===
    if echo "$last_15" | grep -qE "⎿  Done$"; then
        echo "DONE"
        return
    fi

    # === IDLE (default - thinking/waiting) ===
    echo "TODO"
}

# Extract current task title from pane content
extract_task_title() {
    local content="$1"
    local task=""

    # Try to find task indicators
    task=$(echo "$content" | grep -oE "(Task|Working on|Running|Analyzing|Testing|Building|Checking|Reviewing|Implementing|Fixing|Refactoring):[^$]*" | tail -1 | sed 's/^[^:]*: *//' | head -c 80)

    if [ -z "$task" ]; then
        # Look for common patterns
        task=$(echo "$content" | grep -iE "(running|testing|building|analyzing|writing|fixing|implementing|reviewing)" | tail -1 | head -c 80)
    fi

    if [ -z "$task" ]; then
        # Get last non-empty line as context
        task=$(echo "$content" | grep -v "^$" | grep -v "^[[:space:]]*$" | tail -1 | head -c 80)
    fi

    # Clean up
    task=$(echo "$task" | LC_ALL=C tr -d '\n\r' | LC_ALL=C sed 's/["\]//g' | xargs 2>/dev/null || echo "$task")

    if [ -z "$task" ]; then
        task="Waiting for assignment"
    fi

    echo "$task"
}

# Extract multi-line task details (last 3-5 relevant lines)
extract_task_details() {
    local content="$1"
    local details=()

    # Get last 20 lines, filter out empty and noise
    local relevant=$(echo "$content" | tail -20 | grep -vE "^$|^[[:space:]]*$|^─+$|^═+$|^━+$" | tail -5)

    # Convert to array, limit to 3-5 lines
    while IFS= read -r line; do
        if [ ${#details[@]} -lt 5 ]; then
            # Clean and truncate line
            line=$(echo "$line" | LC_ALL=C sed 's/["\]//g' | head -c 100 | xargs 2>/dev/null || echo "$line")
            if [ -n "$line" ]; then
                details+=("$line")
            fi
        fi
    done <<< "$relevant"

    # Return as JSON array
    if [ ${#details[@]} -eq 0 ]; then
        echo "[]"
    else
        local json="["
        local first=true
        for detail in "${details[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                json+=","
            fi
            # Properly escape for JSON
            detail_escaped=$(echo "$detail" | LC_ALL=C sed 's/\\/\\\\/g' 2>/dev/null | LC_ALL=C sed 's/"/\\"/g' 2>/dev/null || echo "$detail")
            json+="\"$detail_escaped\""
        done
        json+="]"
        echo "$json"
    fi
}

# Extract recent completed tasks
extract_completed_tasks() {
    local content="$1"
    local completed=()

    # Look for completion indicators in last 50 lines
    local done_lines=$(echo "$content" | grep -iE "✓|✔|completed|done|finished|success|passed" | tail -5)

    while IFS= read -r line; do
        if [ ${#completed[@]} -lt 3 ] && [ -n "$line" ]; then
            # Extract task name from line
            task=$(echo "$line" | LC_ALL=C sed 's/^\s*//' | head -c 60 | xargs 2>/dev/null || echo "$line")
            if [ -n "$task" ]; then
                completed+=("$task")
            fi
        fi
    done <<< "$done_lines"

    # Return as JSON array of objects
    if [ ${#completed[@]} -eq 0 ]; then
        echo "[]"
    else
        local json="["
        local first=true
        for task in "${completed[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                json+=","
            fi
            task_escaped=$(echo "$task" | LC_ALL=C sed 's/\\/\\\\/g' 2>/dev/null | LC_ALL=C sed 's/"/\\"/g' 2>/dev/null || echo "$task")
            json+="{\"task\":\"$task_escaped\",\"time\":\"방금 전\"}"
        done
        json+="]"
        echo "$json"
    fi
}

# Estimate progress from content patterns
estimate_progress() {
    local status="$1"
    local content="$2"

    case "$status" in
        "DONE")
            echo 100
            ;;
        "TODO")
            echo 0
            ;;
        "DOING")
            # Try to detect progress indicators
            local progress=$(echo "$content" | grep -oE "[0-9]+%" | tail -1 | tr -d '%')
            if [ -n "$progress" ] && [ "$progress" -ge 0 ] 2>/dev/null && [ "$progress" -le 100 ] 2>/dev/null; then
                echo "$progress"
            else
                # Random-ish progress for active tasks
                echo $((30 + RANDOM % 50))
            fi
            ;;
        *)
            echo 0
            ;;
    esac
}

# Load previous state for time tracking
load_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "{}"
    fi
}

# Save current state for next iteration
save_state() {
    local state_json="$1"
    echo "$state_json" > "$STATE_FILE"
}

# Get elapsed time since task started
get_elapsed_time() {
    local pane="$1"
    local current_status="$2"
    local current_task="$3"
    local previous_state="$4"

    # Extract previous status and task for this pane
    local prev_status=$(echo "$previous_state" | jq -r ".pane_${pane}.status // \"TODO\"" 2>/dev/null)
    local prev_task=$(echo "$previous_state" | jq -r ".pane_${pane}.task // \"\"" 2>/dev/null)
    local prev_time=$(echo "$previous_state" | jq -r ".pane_${pane}.started_at // \"\"" 2>/dev/null)

    # If status just changed to DOING, record current time
    if [ "$current_status" = "DOING" ] && [ "$prev_status" != "DOING" ]; then
        date +%H:%M
    elif [ "$current_status" = "DOING" ] && [ "$prev_status" = "DOING" ] && [ -n "$prev_time" ]; then
        # Return previous start time
        echo "$prev_time"
    else
        echo ""
    fi
}

# Check if hwatu-team tmux session exists
if ! tmux has-session -t hwatu-team &>/dev/null; then
    echo "tmux not running, creating sample status..."
    cat > "$STATUS_FILE" << EOF
{
  "timestamp": "$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)",
  "team": [
    {"pane": 0, "name": "UI/UX Reviewer", "model": "Claude", "role": "Design Quality Assurance", "status": "TODO", "progress": 0, "currentTask": {"title": "tmux not running", "details": [], "startedAt": ""}, "recentCompleted": []},
    {"pane": 1, "name": "QA Engineer", "model": "Claude", "role": "Quality Assurance", "status": "TODO", "progress": 0, "currentTask": {"title": "tmux not running", "details": [], "startedAt": ""}, "recentCompleted": []},
    {"pane": 2, "name": "Logic Analyst", "model": "Claude", "role": "Game Logic Validation", "status": "TODO", "progress": 0, "currentTask": {"title": "tmux not running", "details": [], "startedAt": ""}, "recentCompleted": []},
    {"pane": 3, "name": "SFX/VFX Specialist", "model": "Claude", "role": "Effects & Animation", "status": "TODO", "progress": 0, "currentTask": {"title": "tmux not running", "details": [], "startedAt": ""}, "recentCompleted": []},
    {"pane": 4, "name": "opencode", "model": "Gemini", "role": "External Partner", "status": "TODO", "progress": 0, "isExternal": true, "currentTask": {"title": "tmux not running", "details": [], "startedAt": ""}, "recentCompleted": []},
    {"pane": 5, "name": "Dashboard Dev", "model": "Claude", "role": "Orchestration", "status": "TODO", "progress": 0, "currentTask": {"title": "tmux not running", "details": [], "startedAt": ""}, "recentCompleted": []}
  ]
}
EOF
    exit 0
fi

# Load previous state
PREVIOUS_STATE=$(load_state)

# Build JSON array and new state
JSON_ARRAY="["
NEW_STATE="{"
FIRST=true
FIRST_STATE=true

# Use configured pane count for dynamic team size
for ((pane=0; pane<PANE_COUNT; pane++)); do
    # Capture pane content (last 50 lines) from hwatu-team session
    CONTENT=$(tmux capture-pane -t "$SESSION:0.$pane" -p -S -50 2>/dev/null || echo "Pane not found")

    # Detect status and extract task information
    STATUS=$(detect_status "$CONTENT")
    TASK_TITLE=$(extract_task_title "$CONTENT")
    TASK_DETAILS=$(extract_task_details "$CONTENT")
    COMPLETED_TASKS=$(extract_completed_tasks "$CONTENT")
    PROGRESS=$(estimate_progress "$STATUS" "$CONTENT")

    # Extract context usage and compress warning
    CTX_USAGE=$(extract_context_usage "$CONTENT")
    COMPRESS_WARNING=$(detect_compress_warning "$CONTENT")

    # Get elapsed time
    STARTED_AT=$(get_elapsed_time "$pane" "$STATUS" "$TASK_TITLE" "$PREVIOUS_STATE")

    NAME=$(get_name $pane)
    ROLE=$(get_role $pane)
    MODEL=$(get_model $pane)

    # External flag from config
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
    TASK_ESCAPED=$(echo "$TASK_TITLE" | LC_ALL=C sed 's/\\/\\\\/g' | LC_ALL=C sed 's/"/\\"/g' | LC_ALL=C tr -d '\n\r' 2>/dev/null || echo "$TASK_TITLE")

    JSON_ARRAY+="
    {
      \"pane\": $pane,
      \"name\": \"$NAME\",
      \"model\": \"$MODEL\",
      \"role\": \"$ROLE\",
      \"status\": \"$STATUS\",
      \"progress\": $PROGRESS,
      \"ctx\": $CTX_USAGE,
      \"compressWarning\": $COMPRESS_WARNING,
      \"currentTask\": {
        \"title\": \"$TASK_ESCAPED\",
        \"details\": $TASK_DETAILS,
        \"startedAt\": \"$STARTED_AT\"
      },
      \"recentCompleted\": $COMPLETED_TASKS$EXTERNAL
    }"

    # Build new state for next iteration
    if [ "$FIRST_STATE" = true ]; then
        FIRST_STATE=false
    else
        NEW_STATE+=","
    fi

    NEW_STATE+="
    \"pane_$pane\": {
      \"status\": \"$STATUS\",
      \"task\": \"$TASK_ESCAPED\",
      \"started_at\": \"$STARTED_AT\"
    }"
done

JSON_ARRAY+="
  ]"

NEW_STATE+="
}"

# Write final JSON
TIMESTAMP=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)
cat > "$STATUS_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "team": $JSON_ARRAY
}
EOF

# Save state for next iteration
save_state "$NEW_STATE"

echo "Status updated: $STATUS_FILE"
