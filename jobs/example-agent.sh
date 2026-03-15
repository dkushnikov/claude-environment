#!/bin/bash
# Example agent job — run Claude Code headless on schedule
#
# Use case: automated daily reflection, vault audit, report generation
#
# Prerequisites:
#   - Claude Code installed (~/.local/bin/claude)
#   - Vault exists and is configured
#   - Data pipelines synced (agent reads from local files, not MCP)

set -euo pipefail

VAULT_DIR="$HOME/Obsidian/YourVault"  # adjust
CLAUDE="$HOME/.local/bin/claude"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"
TODAY=$(date '+%Y-%m-%d')

# Check Claude Code
if [[ ! -x "$CLAUDE" ]]; then
    echo "$LOG_PREFIX ERROR: claude not found at $CLAUDE"
    exit 1
fi

# Check vault
if [[ ! -d "$VAULT_DIR" ]]; then
    echo "$LOG_PREFIX ERROR: vault not found: $VAULT_DIR"
    exit 1
fi

# Example: generate daily reflection if it doesn't exist
REFLECTION="$VAULT_DIR/Reflections/$TODAY.md"
if [[ -f "$REFLECTION" ]]; then
    echo "$LOG_PREFIX Reflection already exists: $REFLECTION"
    exit 0
fi

echo "$LOG_PREFIX Generating reflection for $TODAY..."

cd "$VAULT_DIR"
$CLAUDE -p "Create a daily reflection for today ($TODAY). Read calendar data from _inputs/Calendar/days/$TODAY.json. Read health data if available." \
    --allowedTools "Read,Write,Edit,Glob,Grep,Bash" \
    --max-turns 30 \
    2>&1

EXIT_CODE=$?
echo "$LOG_PREFIX Done (exit: $EXIT_CODE)"

if [[ -f "$REFLECTION" ]]; then
    echo "$LOG_PREFIX Reflection created"
else
    echo "$LOG_PREFIX Reflection NOT created"
    exit 1
fi
