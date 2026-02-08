#!/usr/bin/env bash
# Demo Status Adapter
# Generates simulated status data for testing/demo purposes
#
# Usage: ./adapters/demo.sh [--config path/to/config.json]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUS_FILE="$SCRIPT_DIR/team-status.json"
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

# Demo tasks pool
DEMO_TASKS=(
    "Reviewing component architecture"
    "Running test suite"
    "Analyzing game logic"
    "Implementing visual effects"
    "Optimizing performance"
    "Debugging API integration"
    "Writing documentation"
    "Refactoring codebase"
    "Code review in progress"
    "Building production bundle"
)

DEMO_DETAILS=(
    '["Checking file structure", "Validating patterns"]'
    '["Running 45 tests", "3 pending"]'
    '["Validating scoring engine", "Checking edge cases"]'
    '["Adding particle effects", "Optimizing animations"]'
    '["Profiling render loop", "Reducing bundle size"]'
    '["Testing endpoints", "Checking auth flow"]'
    '["Updating README", "Adding examples"]'
    '["Extracting components", "Improving types"]'
    '["Reviewing PR #42", "Checking security"]'
    '["Minifying assets", "Tree shaking"]'
)

# Random status generator with weighted distribution
random_status() {
    local rand=$((RANDOM % 100))
    if [ $rand -lt 40 ]; then
        echo "TODO"
    elif [ $rand -lt 85 ]; then
        echo "DOING"
    else
        echo "DONE"
    fi
}

# Build JSON array
JSON_ARRAY="["
FIRST=true

for ((pane=0; pane<PANE_COUNT; pane++)); do
    STATUS=$(random_status)

    # Random task from pool
    TASK_IDX=$((RANDOM % ${#DEMO_TASKS[@]}))
    TASK="${DEMO_TASKS[$TASK_IDX]}"
    DETAILS="${DEMO_DETAILS[$TASK_IDX]}"

    # Random context usage (0-95)
    CTX=$((RANDOM % 96))

    # Compress warning if ctx > 85
    if [ $CTX -gt 85 ]; then
        COMPRESS="true"
    else
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
        \"title\": \"$TASK\",
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

echo "Demo status generated: $STATUS_FILE"
