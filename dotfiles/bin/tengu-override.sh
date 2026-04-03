#!/bin/bash
# tengu-override.sh — Claude Code PreToolUse hook
#
# Two jobs:
# 1. Auto-APPROVE known-safe commands (bypass tengu heuristic false positives)
# 2. Force-ASK on destructive commands (safety net even with Bash(*) in allow)
#
# With Bash(*) in global settings, Layer 1 auto-approves everything.
# This hook is now the primary gate for dangerous commands.
#
# Usage: Register in ~/.claude/settings.json → hooks.PreToolUse
#
# See docs/hooks.md for details and docs/security.md for the 4-layer
# permission model.

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

# ── Helpers (must be defined before use) ──
allow() {
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"permissionDecisionReason\":\"tengu-override: $1\"}}"
    exit 0
}

ask() {
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"ask\",\"permissionDecisionReason\":\"tengu-override: ⚠️ $1\"}}"
    exit 0
}

# ── Auto-approve non-Bash tools (WebSearch, WebFetch) ──
case "$TOOL" in
    Bash) ;; # continue to Bash logic below
    WebSearch|WebFetch) allow "$TOOL auto-approve" ;;
    *) exit 0 ;;
esac

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0

# ── DANGEROUS: force prompt even though Bash(*) would auto-approve ──

# Pipe to shell / eval (injection vector)
if echo "$CMD" | grep -qE '\|\s*(ba)?sh\b|\|\s*zsh\b|\beval\s'; then
    ask "pipe to shell or eval"
fi

# rm -rf with broad targets (/, ~, ., *)
if echo "$CMD" | grep -qE '\brm\s+(-[a-zA-Z]*f[a-zA-Z]*\s+(-[a-zA-Z]*\s+)*|(-[a-zA-Z]*\s+)*-[a-zA-Z]*f[a-zA-Z]*\s+)(\/(\s|$)|~|\.\.?(\s|$)|\*(\s|$))'; then
    ask "rm -rf with broad target"
fi
if echo "$CMD" | grep -qE '\brm\s+-(r|R)f\s*$'; then
    ask "rm -rf with no target"
fi

# dd — disk destroyer
if echo "$CMD" | grep -qE '^\s*dd\s'; then
    ask "dd command"
fi

# mkfs — format filesystem
if echo "$CMD" | grep -qE '^\s*mkfs'; then
    ask "mkfs command"
fi

# shutdown / reboot
if echo "$CMD" | grep -qE '^\s*(shutdown|reboot|halt)\b'; then
    ask "system shutdown/reboot"
fi

# git force push
if echo "$CMD" | grep -qE '\bgit\s+push\s+.*(-f|--force)\b'; then
    ask "git push --force"
fi

# git reset --hard
if echo "$CMD" | grep -qE '\bgit\s+reset\s+--hard\b'; then
    ask "git reset --hard"
fi

# git clean -f
if echo "$CMD" | grep -qE '\bgit\s+clean\s+.*-[a-zA-Z]*f'; then
    ask "git clean -f"
fi

# ── Extract first command word ──
FIRST_WORD=$(echo "$CMD" | sed 's/^\s*//' | awk '{print $1}')
BARE_CMD=$(basename "$FIRST_WORD" 2>/dev/null || echo "$FIRST_WORD")

# ── Safe command whitelist ──
# Customize this list for your environment. Add commands you use frequently
# and trust. Remove any you're not comfortable auto-approving.
SAFE_CMDS="
ls find cat head tail wc sort grep rg cut tr uniq diff
echo printf date test which basename dirname realpath readlink
stat file du md5 xxd jq hostname system_profiler pgrep
git gh top ps sysctl vm_stat launchctl ping
touch mkdir mv ln cp open chmod cd rm rmdir
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
