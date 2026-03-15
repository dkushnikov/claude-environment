#!/bin/bash
# Example sync job — template for scheduled data sync
#
# Usage:
#   ./example-sync.sh              # with jitter (for cron)
#   ./example-sync.sh --now        # no jitter (manual)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/pipelines/calendar/sync.py"  # adjust path
LOCK_FILE="/tmp/example-sync.lock"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# Prevent concurrent runs
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "$LOG_PREFIX Another sync running, skipping"
    exit 0
fi

# Jitter: 15-45 seconds (unless --now)
if [[ "${1:-}" != "--now" ]]; then
    JITTER=$((15 + RANDOM % 31))
    echo "$LOG_PREFIX Sleeping ${JITTER}s (jitter)"
    sleep "$JITTER"
fi

# Check prerequisites
if [[ ! -f "$SYNC_SCRIPT" ]]; then
    echo "$LOG_PREFIX ERROR: sync script not found: $SYNC_SCRIPT"
    exit 1
fi

# Run sync
echo "$LOG_PREFIX Starting sync"
EXIT_CODE=0
python3 "$SYNC_SCRIPT" 2>&1 || EXIT_CODE=$?

echo "$LOG_PREFIX Done (exit: $EXIT_CODE)"
exit $EXIT_CODE
