#!/bin/bash
# tengu-override.sh — Bypass Claude Code's shell safety heuristic prompts
# for known-safe commands.
#
# Claude Code has 23 hardcoded safety checks (backslash escaping, $(),
# newlines, pipes, etc.) that prompt even when commands are in the allow list.
# This PreToolUse hook auto-approves safe commands, bypassing those checks.
#
# Usage: Register in ~/.claude/settings.json → hooks.PreToolUse
#
# See docs/hooks.md for details and docs/security.md for the 4-layer
# permission model.

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL" != "Bash" ] && exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

# ── DENY: never auto-approve these patterns ──
if echo "$CMD" | grep -qE '\|\s*(ba)?sh\b|\|\s*zsh\b|\beval\s'; then
    exit 0
fi

# ── Extract first command word ──
FIRST_WORD=$(echo "$CMD" | sed 's/^\s*//' | awk '{print $1}')
BARE_CMD=$(basename "$FIRST_WORD" 2>/dev/null || echo "$FIRST_WORD")

# ── Helper ──
allow() {
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"permissionDecisionReason\":\"tengu-override: $1\"}}"
    exit 0
}

# ── Safe command whitelist ──
# Customize this list for your environment. Add commands you use frequently
# and trust. Remove any you're not comfortable auto-approving.
SAFE_CMDS="
ls find cat head tail wc sort grep rg cut tr uniq diff
echo printf date test which basename dirname realpath readlink
stat file du md5 xxd jq hostname system_profiler pgrep
git gh top ps sysctl vm_stat launchctl ping
touch mkdir mv ln cp open chmod cd
sed awk sips
python3 pip3 pip brew npm npx bun uvx
ssh scp mosh curl wget
pandoc osacompile osadecompile codesign plutil PlistBuddy
pbcopy source tee xargs tar zip unzip gzip gunzip
for while do done fi if then else elif case esac
export local declare set unset read true false
command type env node bash perl ruby deno
"

# Check bare command against whitelist
if echo " $SAFE_CMDS " | grep -qw "$BARE_CMD"; then
    # Sudo: only allow specific subcommands
    if [ "$BARE_CMD" = "sudo" ]; then
        SUDO_CMD=$(echo "$CMD" | sed 's/^\s*sudo\s*//' | awk '{print $1}')
        case "$(basename "$SUDO_CMD" 2>/dev/null || echo "$SUDO_CMD")" in
            mkdir|chown|chmod|ln|cp|mv|touch) allow "sudo $SUDO_CMD" ;;
            *) exit 0 ;;
        esac
    fi
    allow "$BARE_CMD"
fi

# Own dotfiles scripts — customize this path to your dotfiles location
DOTFILES_DIR="$HOME/dotfiles-claude"
case "$FIRST_WORD" in
    "$DOTFILES_DIR"/*|"$HOME"/dotfiles-claude/*) allow "dotfiles script" ;;
esac

# Variable assignments (VARNAME=value ...)
if echo "$FIRST_WORD" | grep -qE '^[A-Z_][A-Z0-9_]*='; then
    allow "variable assignment"
fi

exit 0
