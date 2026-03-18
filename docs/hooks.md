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

## Tips

- **Keep hooks fast.** A slow SessionStart hook delays every session. Target < 2 seconds.
- **Fail gracefully.** End commands with `|| true` if failure shouldn't block the session.
- **Log, don't alert.** Write to a log file; check logs separately. Don't make hooks chatty.
- **Test the command first.** Pipe a sample JSON payload before wiring it into settings.
