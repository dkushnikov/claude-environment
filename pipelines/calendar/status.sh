#!/usr/bin/env bash
# Calendar Sync status checker
# Shows sync health, data freshness, and auth status.
#
# Usage: ./status.sh [data-dir]

set -uo pipefail

DATA_DIR="${1:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/Claude Data/Calendar}"
DAYS_DIR="$DATA_DIR/days"

echo "=== Calendar Sync Status ==="
echo ""

# Data directory
if [[ ! -d "$DATA_DIR" ]]; then
    echo "Data directory not found: $DATA_DIR"
    exit 1
fi
echo "Data dir: $DATA_DIR"

# Config
if [[ -f "$DATA_DIR/config.json" ]]; then
    CALS=$(python3 -c "
import json
c = json.load(open('$DATA_DIR/config.json'))
personal = len(c['calendars'].get('personal', []))
work = len(c['calendars'].get('work', []))
print(f'{personal} personal + {work} work')
" 2>/dev/null || echo "?")
    echo "Config: $CALS calendars"
else
    echo "Config: missing"
fi

# Sync state
if [[ -f "$DATA_DIR/.sync-state.json" ]]; then
    LAST=$(python3 -c "import json; print(json.load(open('$DATA_DIR/.sync-state.json')).get('last_sync','?')[:16])" 2>/dev/null || echo "?")
    echo "Last sync: $LAST"
else
    echo "Last sync: never"
fi

echo ""

# Day files
if [[ ! -d "$DAYS_DIR" ]]; then
    echo "No day files yet"
    exit 0
fi

TODAY=$(date +%Y-%m-%d)
TOTAL=$(ls "$DAYS_DIR"/*.json 2>/dev/null | wc -l | tr -d ' ')
echo "Day files: $TOTAL total"
echo ""

for OFFSET in -3 -2 -1 0 1 2 3 4 5 6 7; do
    if [[ "$(uname)" == "Darwin" ]]; then
        if [[ $OFFSET -ge 0 ]]; then
            DATE=$(date -v "+${OFFSET}d" +%Y-%m-%d)
        else
            DATE=$(date -v "${OFFSET}d" +%Y-%m-%d)
        fi
    else
        DATE=$(date -d "$TODAY ${OFFSET} days" +%Y-%m-%d)
    fi

    FILE="$DAYS_DIR/$DATE.json"
    if [[ -f "$FILE" ]]; then
        EVENTS=$(python3 -c "import json; print(len(json.load(open('$FILE')).get('events',[])))" 2>/dev/null || echo "?")
        SYNCED=$(python3 -c "import json; print(json.load(open('$FILE')).get('synced_at','?')[:16])" 2>/dev/null || echo "?")
        MARKER=""
        [[ "$DATE" == "$TODAY" ]] && MARKER=" <- today"
        echo "  $DATE: ${EVENTS} events (synced: $SYNCED)$MARKER"
    else
        MARKER=""
        [[ "$DATE" == "$TODAY" ]] && MARKER=" <- today"
        echo "  $DATE: no data$MARKER"
    fi
done

# Auth check
echo ""
if command -v gws >/dev/null 2>&1; then
    TOKEN=$(gws auth status 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('token_valid',False))" 2>/dev/null || echo "False")
    if [[ "$TOKEN" == "True" ]]; then
        USER=$(gws auth status 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('user','?'))" 2>/dev/null || echo "?")
        echo "Auth: gws ($USER)"
    else
        echo "Auth: not authenticated (run: gws auth login --services calendar)"
    fi
else
    echo "Auth: gws not installed"
fi
