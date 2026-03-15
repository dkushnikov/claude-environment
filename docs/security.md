# Security & Privacy

How this framework handles secrets, personal data, and trust boundaries.

## Secrets management

| Secret type | Where it lives | Synced? |
|-------------|---------------|---------|
| API tokens, OAuth secrets | `config/*.env` (gitignored) | Never |
| gws credentials | OS keyring (`~/.config/gws/`) | Never |
| SSH keys | `~/.ssh/` | Never |
| OAuth refresh tokens | Per-tool storage (encrypted) | Never |

**Rule:** if it grants access to an API, it stays on the machine. Zero secrets in git.

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

## Recommendations

1. **Audit `settings.json` regularly.** Approved tools accumulate. Remove what you don't need.
2. **Use `check.sh` before sharing.** It validates that no secrets leaked into git.
3. **Rotate API tokens periodically.** Especially if a machine is compromised.
4. **Private vault = laptop only.** No server, no sync, no cloud. If it's truly private, it stays on one device.
