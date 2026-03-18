# Project-level settings templates

Drop these into `.claude/settings.local.json` in your project directory.

| Template | Use for |
|----------|---------|
| `settings.local.obsidian.json` | Obsidian vault — broad Read, Write to `_claude/` and `Reflections/`, Obsidian CLI |
| `settings.local.coding.json` | Code project — npm, python, docker, git, common dev tools |

## Usage

```bash
cp templates/settings.local.obsidian.json ~/Obsidian/MyVault/.claude/settings.local.json
# Edit: adjust paths, add MCP tools, tune permissions
```

These are starting points. Add project-specific MCP tools, webhooks, and deny rules as needed.

## Key principles

- **Start restrictive, open up.** Only allow what you actually use.
- **Deny sensitive paths.** `~/.ssh/`, `~/.aws/`, `~/.gnupg/` — always in deny.
- **`$HOME` in paths.** Use `$HOME` for portability or absolute paths for precision.
- **Cruft accumulates.** Claude Code auto-appends one-off Bash commands to allow. Clean up periodically.
