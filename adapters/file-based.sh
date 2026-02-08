#!/usr/bin/env bash
# File-based Status Adapter
# Each agent writes its own status to .omc/agent-status/{pane}.json
#
# Usage: ./adapters/file-based.sh [--config path/to/config.json]
#
# Agent status file format:
# {
#   "status": "DOING|TODO|DONE",
#   "task": "Current task description",
#   "ctx": 45,
#   "details": ["line1", "line2"]
# }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUS_FILE="$SCRIPT_DIR/team-status.json"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/team-config.json}"
AGENT_STATUS_DIR="${AGENT_STATUS_DIR:-.omc/agent-status}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --status-dir)
            AGENT_STATUS_DIR="$2"
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

# Build JSON array
JSON_ARRAY="["
FIRST=true

for ((pane=0; pane<PANE_COUNT; pane++)); do
    AGENT_FILE="$AGENT_STATUS_DIR/$pane.json"

    # Read agent status file or use defaults
    if [ -f "$AGENT_FILE" ]; then
        STATUS=$(jq -r '.status // "TODO"' "$AGENT_FILE")
        TASK=$(jq -r '.task // "Waiting for assignment"' "$AGENT_FILE")
        CTX=$(jq -r '.ctx // 0' "$AGENT_FILE")
        DETAILS=$(jq -c '.details // []' "$AGENT_FILE")
        COMPRESS=$(jq -r '.compressWarning // false' "$AGENT_FILE")
        PROGRESS=$(jq -r '.progress // 0' "$AGENT_FILE")
    else
        STATUS="TODO"
        TASK="No status file found"
        CTX=0
        DETAILS="[]"
        COMPRESS="false"
        PROGRESS=0
    fi

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
        \"details\": $DETAILS,
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

echo "Status updated from file-based adapter: $STATUS_FILE"
