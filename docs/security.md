# Security & Privacy

How this framework handles secrets, personal data, and trust boundaries.

## Secrets management

| Secret type | Where it lives | Synced? |
|-------------|---------------|---------|
| API tokens (MCP, etc.) | OS keychain (preferred) or `config/*.env` (gitignored) | Never |
| gws credentials | OS keyring (`~/.config/gws/`) | Never |
| SSH keys | `~/.ssh/` | Never |
| OAuth refresh tokens | Per-tool storage (encrypted) | Never |

**Rule:** if it grants access to an API, it stays on the machine. Zero secrets in git.

**Preferred: OS keychain (D29).** Store API keys in the OS keychain, not plaintext files:

```bash
# Store (macOS):
security add-generic-password -a "$USER" -s MY_API_KEY -w "sk-..." -U

# Use in shell profile (~/.zshrc):
export MY_API_KEY="$(security find-generic-password -a "$USER" -s MY_API_KEY -w 2>/dev/null)"

# Pass to MCP servers at registration:
claude mcp add my-server -e MY_API_KEY="$MY_API_KEY" -- command args
```

Alternatives rejected: hardcoded in `settings.json` (git-tracked), `.env` files (plaintext on disk). Keychain is encrypted, OS-managed, and survives shell profile changes.

## Personal data

| Data type | Storage | In git? |
|-----------|---------|---------|
| Calendar events | iCloud → symlink | No (gitignored) |
| Voice transcripts | iCloud → symlink | No (gitignored) |
| Health metrics | iCloud → symlink | No (gitignored) |
| Vault content | Obsidian Sync or Git | Depends on vault policy |
| Session cache | `_claude/cache/` | Optional |

**Rule:** pipeline data is personal. It flows through cloud storage and symlinks, never through the dotfiles git repo.

## Trust model

```
You ──→ Claude Code ──→ Dotfiles repo (git, your control)
                    ──→ Pipeline data (iCloud, your control)
                    ──→ External APIs (gws, MCP — scoped access)
```

**What Claude Code can see:**
- Everything in the vault (files in working directory)
- Symlinked data (_inputs/)
- Dotfiles config (rules, skills, settings)

**What Claude Code cannot see** (unless you explicitly grant access):
- Other vaults (unless `--add-dir`)
- Files outside working directory
- Raw API credentials (reads from tools like `gws`, not from env files)

## Multi-vault isolation

If you have multiple vaults (personal, work, private):

| Vault | Git | Sync | Who sees it |
|-------|-----|------|-------------|
| Work | GitHub (private) | Obsidian Sync | You + work Claude sessions |
| Personal | GitHub (private) | Obsidian Sync | You + personal Claude sessions |
| Private | Local git only | None | You only, laptop only |

**Rule:** Claude sessions in one vault don't see other vaults unless you explicitly add them. Cross-vault data flows through a shared directory with controlled content.

## Permission Model

Claude Code has a **4-layer permission system** — layers 1-2 are configurable, layers 3-4 require workarounds.

```
1. Allow/deny patterns      ← settings.json, configurable
2. Path access               ← sandbox-aware check for files outside project
3. Shell safety heuristics   ← 23 hardcoded checks, NOT configurable
4. PreToolUse hooks           ← only way to override layer 3
```

### Layer 1: Allow/Deny Patterns

Glob-style patterns in `settings.json` (global, project, or local):

```json
{
  "permissions": {
    "allow": ["Bash(git *)", "Bash(ls *)", "Read"],
    "deny": ["Read(~/.ssh/**)"]
  }
}
```

**Syntax:** Use `Bash(command *)` with a **space** before `*`. The legacy `Bash(command:*)` syntax is deprecated and doesn't match compound commands. `Bash(command*)` (no space) matches both `command` and `commandSuffix`.

**Merge behavior:** Allow rules merge across all levels (global + project + local). Deny from any level wins — you can't undo a deny rule from a higher level.

### Layer 2: Path Access

Sandbox-aware check for file access outside the project directory. Tilde (`~`) doesn't expand in sandbox mode — use absolute paths or `$HOME`.

### Layer 3: Shell Safety Heuristics ("Tengu")

23 hardcoded checks compiled into the Claude Code binary. They trigger **after** allow/deny matching passes, causing prompts even for explicitly allowed commands. Common triggers:

| Check | What triggers it | Workaround |
|-------|-----------------|------------|
| Backslash-escaped whitespace | `path\ with\ spaces` | Use `"quoted paths"` instead |
| Command substitution | `$()` in commands | PreToolUse hook |
| Output redirection | `>` in commands | PreToolUse hook |
| Shell metacharacters | `;`, `\|`, `&` in arguments | PreToolUse hook |
| Newlines | Multi-line commands | PreToolUse hook |

These checks cannot be disabled via settings. The only override is a PreToolUse hook (Layer 4). See [hooks.md](hooks.md#overriding-shell-safety-heuristics) for a working solution.

**Relevant issues:** [#30435](https://github.com/anthropics/claude-code/issues/30435), [#34106](https://github.com/anthropics/claude-code/issues/34106), [#32520](https://github.com/anthropics/claude-code/issues/32520), [#35571](https://github.com/anthropics/claude-code/issues/35571)

### Layer 4: PreToolUse Hooks

The only way to override Layer 3. A hook returning `permissionDecision: "allow"` bypasses all permission checks including shell safety heuristics. See [hooks.md](hooks.md#overriding-shell-safety-heuristics) for implementation.

### Permission file hierarchy

| File | Scope | Overrides |
|------|-------|-----------|
| Managed settings | Enterprise | Everything |
| CLI flags | Session | Below |
| `.claude/settings.local.json` | Project (personal) | Below |
| `.claude/settings.json` | Project (team) | Below |
| `~/.claude/settings.json` | Global (user) | — |

**Split strategy:** Keep generic CLI/system commands in global settings. Keep project-specific paths, MCP tools, and domain commands in local settings. This reduces noise and makes templates reusable.

## Permissions Audit

Claude Code auto-appends one-off commands to your allow list during sessions. Over weeks, local settings grow from 20 rules to 200+ without anyone noticing. A permissions audit script (D41) detects this drift.

### What it checks

| Check | Severity | What it means |
|-------|----------|---------------|
| **Baseline drift** | Warning at +5, error at +15 | New rules added since baseline was saved |
| **Duplicates** | Warning | Local rules already covered by global (e.g., `Bash(ls *)` when `Bash(*)` is global) |
| **Invalid patterns** | Error | Double slashes, unexpanded `$VARS`, >120-char one-off commands |

### Usage

```bash
# Show drift report
permissions-audit.sh /path/to/project

# Save current state as baseline (do this after cleanup)
permissions-audit.sh --save-baseline /path/to/project
```

The baseline is saved to `_claude/cache/permissions-baseline.json`. Integrate into your vault audit or run after major permission cleanups.

A reference implementation is at [`dotfiles/bin/permissions-audit.sh`](../dotfiles/bin/permissions-audit.sh).

## Recommendations

1. **Audit `settings.json` regularly.** Use `permissions-audit.sh` to detect drift. Clean up after it flags issues.
2. **Use `check.sh` before sharing.** It validates that no secrets leaked into git.
3. **Rotate API tokens periodically.** Especially if a machine is compromised.
4. **Private vault = laptop only.** No server, no sync, no cloud. If it's truly private, it stays on one device.
5. **Consider `Bash(*)` + hook over per-command rules.** Per-command rules are security theater when `python3 *` and `ssh *` are already allowed. Move safety to a PreToolUse hook that force-prompts on destructive commands (D40). See [hooks.md](hooks.md#destructive-command-safety-net).
