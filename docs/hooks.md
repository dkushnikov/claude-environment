# Hooks Architecture

Claude Code hooks run shell commands at specific lifecycle events. They're the mechanism for automation within sessions.

## Hook Events

| Event | When | Use for |
|-------|------|---------|
| `SessionStart` | Session begins | Briefing, cache check, context load |
| `PreToolUse` | Before a tool runs | Validation, logging, auto-permissions |
| `PostToolUse` | After a tool succeeds | Formatting, linting, notifications |
| `Stop` | Claude stops responding | Session wrap-up, auto-commit |
| `PreCompact` | Before context compaction | Preserve critical info |

## Common Patterns

### Session Briefing

Show context at session start — what's open, what changed, what's on the calendar.

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "/path/to/session-briefing.sh /path/to/project"
      }]
    }]
  }
}
```

A briefing script can:
- Read cached data (calendar, health, TODO)
- Show the last session log title
- Check for incoming messages
- Display deferred items with age

### Auto-Format After Writes

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "command",
        "command": "jq -r '.tool_response.filePath // .tool_input.file_path' | { read -r f; prettier --write \"$f\"; } 2>/dev/null || true"
      }]
    }]
  }
}
```

### Date Injection

Always provide the current date so Claude doesn't guess:

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "echo \"📅 Today: $(date +%Y-%m-%d) ($(date +%A))\""
      }]
    }]
  }
}
```

## Where Hooks Live

| File | Scope | Git |
|------|-------|-----|
| `~/.claude/settings.json` | All projects | Via dotfiles repo |
| `.claude/settings.json` | This project (team) | Committed |
| `.claude/settings.local.json` | This project (personal) | Gitignored |

Later files override earlier ones. Use `settings.local.json` for hooks that reference local paths.

## Hook Output

Hooks communicate back via JSON on stdout:

```json
{
  "systemMessage": "Briefing shown to user",
  "continue": true
}
```

Set `"continue": false` to block the triggering action (useful for PreToolUse validation).

## Overriding Shell Safety Heuristics

Claude Code has 23 hardcoded shell safety checks (internally called "tengu") that trigger prompts even when commands are explicitly in your allow list. These checks cannot be disabled via settings — but a PreToolUse hook can override them.

### The Problem

You add `Bash(ls *)` to your allow list. But `ls ~/Library/Mobile Documents/` still prompts because it triggers the `BACKSLASH_ESCAPED_WHITESPACE` heuristic (the shell escapes the spaces).

Other common triggers:
- `$()` in commands → `DANGEROUS_PATTERNS_COMMAND_SUBSTITUTION`
- `>` redirection → `DANGEROUS_PATTERNS_OUTPUT_REDIRECTION`
- `;`, `|`, `&` → `SHELL_METACHARACTERS`
- Multi-line commands → `NEWLINES`

### The Solution

A PreToolUse hook that returns `permissionDecision: "allow"` bypasses **all** permission checks, including safety heuristics:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "~/dotfiles-claude/bin/tengu-override.sh"
      }]
    }]
  }
}
```

The hook receives the tool name and command as JSON on stdin, and decides whether to auto-approve:

```bash
#!/bin/bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL" != "Bash" ] && exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# DENY dangerous patterns
if echo "$CMD" | grep -qE '\|\s*(ba)?sh\b|\beval\s'; then
    exit 0  # fall through to normal permission check
fi

# ALLOW known-safe commands
FIRST_WORD=$(echo "$CMD" | sed 's/^\s*//' | awk '{print $1}')
BARE_CMD=$(basename "$FIRST_WORD")

SAFE_CMDS="ls find cat head tail git gh date jq mkdir mv cp ..."
if echo " $SAFE_CMDS " | grep -qw "$BARE_CMD"; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"tengu-override"}}'
    exit 0
fi

exit 0  # unknown command → normal permission check
```

A full reference implementation is at [`dotfiles/bin/tengu-override.sh`](../dotfiles/bin/tengu-override.sh).

### Destructive Command Safety Net

When you use `Bash(*)` in global settings (D40), Layer 1 auto-approves everything. The tengu-override hook becomes **the primary gate** — it does two jobs:

1. **Auto-APPROVE** known-safe commands (bypass tengu false positives, same as before)
2. **Force-ASK** on destructive commands (safety net even with `Bash(*)`)

Force-prompt patterns to add to your hook:

```bash
# ── DANGEROUS: force prompt even though Bash(*) would auto-approve ──

# Pipe to shell / eval (injection vector)
if echo "$CMD" | grep -qE '\|\s*(ba)?sh\b|\beval\s'; then
    ask "pipe to shell or eval"
fi

# rm -rf with broad targets (/, ~, ., *)
if echo "$CMD" | grep -qE '\brm\s+.*-[a-zA-Z]*f.*\s+(\/(\s|$)|~|\.\.?(\s|$)|\*(\s|$))'; then
    ask "rm -rf with broad target"
fi

# dd, mkfs, shutdown/reboot
if echo "$CMD" | grep -qE '^\s*(dd|mkfs|shutdown|reboot|halt)\b'; then
    ask "destructive system command"
fi

# git force push / reset --hard / clean -f
if echo "$CMD" | grep -qE '\bgit\s+(push\s+.*--force|reset\s+--hard|clean\s+.*-[a-zA-Z]*f)'; then
    ask "destructive git command"
fi
```

The `ask()` helper returns `permissionDecision: "ask"`, which forces the normal permission prompt regardless of `Bash(*)`:

```bash
ask() {
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"ask\",\"permissionDecisionReason\":\"tengu-override: ⚠️ $1\"}}"
    exit 0
}
```

### Safety Considerations

- **Deny list first.** Always check for dangerous patterns before allowing. Pipe to `sh`/`bash` and `eval` should never be auto-approved.
- **Whitelist, not blacklist.** Only approve commands you explicitly list. Unknown commands fall through to the normal permission check.
- **Sudo restrictions.** If `sudo` is in your whitelist, only allow specific subcommands (e.g., `sudo mkdir`, `sudo chmod`).
- **This is a guardrail override, not a security bypass.** The safety heuristics are behavioral safeguards. Override them only for commands you trust and use frequently.
- **With `Bash(*)`, the hook IS the safety net.** Without it, everything auto-approves. Test the hook independently before enabling `Bash(*)`.

### Quick Fix: Quoted Paths

For the common case of paths with spaces (iCloud, user directories), you can avoid the `BACKSLASH_ESCAPED_WHITESPACE` heuristic without a hook — just use quoted paths:

```bash
# Triggers heuristic:
ls ~/Library/Mobile\ Documents/com~apple~CloudDocs/

# Doesn't trigger:
ls "$HOME/Library/Mobile Documents/com~apple~CloudDocs/"
```

### All 23 Safety Checks

For reference, the complete list of shell safety heuristics:

| Check | What it catches |
|-------|----------------|
| BACKSLASH_ESCAPED_WHITESPACE | `path\ with\ spaces` |
| BACKSLASH_ESCAPED_OPERATORS | `\|`, `\;` before operators |
| BRACE_EXPANSION | `{a,b}` patterns |
| COMMENT_QUOTE_DESYNC | Quotes inside `#` comments |
| CONTROL_CHARACTERS | Non-printable characters |
| DANGEROUS_PATTERNS_COMMAND_SUBSTITUTION | `$()` and backticks |
| DANGEROUS_PATTERNS_INPUT_REDIRECTION | `<` redirection |
| DANGEROUS_PATTERNS_OUTPUT_REDIRECTION | `>` redirection |
| DANGEROUS_VARIABLES | Variables in redirections/pipes |
| GIT_COMMIT_SUBSTITUTION | `$()` in git commit messages |
| IFS_INJECTION | `IFS=` usage |
| INCOMPLETE_COMMANDS | Truncated commands |
| JQ_FILE_ARGUMENTS | `jq` with risky flags |
| JQ_SYSTEM_FUNCTION | `jq` with `system()` |
| MALFORMED_TOKEN_INJECTION | Ambiguous syntax |
| MID_WORD_HASH | `#` mid-word |
| NEWLINES | Multi-line commands |
| OBFUSCATED_FLAGS | Quoted chars in flags |
| PROC_ENVIRON_ACCESS | `/proc/*/environ` |
| QUOTED_NEWLINE | Quoted newline + `#` line |
| SHELL_METACHARACTERS | `;`, `\|`, `&` in args |
| UNICODE_WHITESPACE | Unicode whitespace chars |
| ZSH_DANGEROUS_COMMANDS | Zsh-specific builtins |

## Tips

- **Keep hooks fast.** A slow SessionStart hook delays every session. Target < 2 seconds.
- **Fail gracefully.** End commands with `|| true` if failure shouldn't block the session.
- **Log, don't alert.** Write to a log file; check logs separately. Don't make hooks chatty.
- **Test the command first.** Pipe a sample JSON payload before wiring it into settings.
