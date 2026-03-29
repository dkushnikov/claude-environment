# Multi-Machine Setup

Patterns for running Claude Code on laptop + server (or multiple machines).

## Why two machines?

| Machine | Role | Runs |
|---------|------|------|
| Laptop | Interactive | You + Claude, real-time. MCP, browser, GUI |
| Server | Background | Cron jobs, headless Claude, always-on sync |

The laptop is where you work. The server is where automation runs while you sleep.

## What syncs, what doesn't

| Data | Sync method | Direction |
|------|-------------|-----------|
| Dotfiles (rules, skills, settings) | Git | Push from laptop, pull on server |
| Pipeline data (calendar JSON, transcripts) | iCloud / Dropbox | Bidirectional, automatic |
| Vault content | Obsidian Sync or Git | Bidirectional |
| Secrets (API tokens, credentials) | Never synced | Machine-local only |
| Machine identity (`environment.md`) | Never synced | `.gitignore`d |

## Sync Architecture

The key insight: **Obsidian Sync and Git serve different purposes and operate on different timescales.** Don't make them compete.

```
┌──────────────────────────────────────────────────┐
│  Layer 1: Obsidian Sync (real-time)              │
│  Content sync between all devices. Source of     │
│  truth for vault content. Seconds.               │
├──────────────────────────────────────────────────┤
│  Layer 2: Git (async archive)                    │
│  One machine commits (laptop). Others pull only. │
│  History, backup, rollback. Hours/days.          │
├──────────────────────────────────────────────────┤
│  Layer 3: File sync (data pipelines)             │
│  iCloud/Dropbox for large files (audio, exports).│
│  Everything in _inputs/, gitignored.             │
└──────────────────────────────────────────────────┘
```

**Single git committer.** The laptop commits with descriptive messages. The server does `git pull --ff-only` daily via cron. Zero merge conflicts by construction — two machines committing to the same repo is asking for trouble.

```
Laptop (interactive)  → commit → push → GitHub
                                           ↑
Server (daily cron)   → git pull --ff-only ─┘
```

Server-generated files (cron reflections, audit reports) flow back via Obsidian Sync → laptop → committed in the next interactive session. Git is for history and rollback, not real-time sync.

**Corollary: cron jobs must not auto-commit (D30).** If a server cron job includes `git commit` in its prompt, it becomes a second committer — breaking the single-committer model. This happened with a vault audit job: server auto-committed → `git pull --ff-only` on the laptop failed due to divergence. Fix: remove all commit steps from cron job prompts.

**Vault-pull job** on the server keeps git state current for `git log` / `git blame`:

```bash
#!/bin/bash
# vault-pull.sh — daily at 04:00
for vault in ~/Obsidian/*; do
    [[ -d "$vault/.git" ]] && cd "$vault" && git pull --ff-only
done
```

## Session Awareness

When multiple Claude sessions can write to the same vault (laptop interactive + server Telegram bot + cron), use a marker file so sessions know about each other:

```
_claude/.active-session.json
```

```json
{
  "machine": "server",
  "channel": "telegram",
  "started": "2026-03-23T22:00:00Z",
  "session_id": "abc-123"
}
```

Each session writes this at start, deletes at end. Other sessions read it to know the vault is being actively edited. Not a lock — just awareness. Gitignored.

## Machine identity

Each machine has `rules/environment.md` (gitignored) that tells Claude where it's running:

```markdown
- machine: laptop
- role: interactive
```

```markdown
- machine: server
- role: background
```

Claude adjusts behavior based on role:
- **Interactive:** can open files in Obsidian, prompt user, use MCP
- **Background:** reads from local files only, logs output, no user prompts

## Server setup

```bash
# On server:
git clone git@github.com:you/your-dotfiles.git ~/dotfiles-claude
cd ~/dotfiles-claude
./install.sh
./server-setup.sh    # creates log dir, launchd agents, symlinks
```

See `server-setup.sh` for the full script.

## Secrets

**Never commit secrets.** Each machine has its own credentials:
- `config/*.env` — API tokens (gitignored via `*.env` pattern)
- `gws` credentials — stored in encrypted keyring per-machine
- SSH keys — generated per-machine

When a new service needs auth on the server:
1. SSH to server
2. Run the auth command (e.g., `gws auth login`)
3. Credentials stored locally in keyring

## Headless auth gotcha

Some auth flows require a browser (OAuth2 web flow). On a headless server:
- **Option A:** Screen sharing / VNC — open the browser remotely
- **Option B:** Port forwarding — forward the OAuth callback to your laptop
- **Option C:** Token export — authenticate on laptop, export token, import on server
  ```bash
  # On laptop:
  gws auth export > /tmp/gws-creds.json
  # Copy to server, then:
  GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=/path/to/creds.json gws calendar events list ...
  ```

## Deploy flow

```
Laptop: edit dotfiles → git push
Server: git pull (cron or manual) → install.sh (idempotent)
```

The `dotfiles-pull` job (cron, hourly) keeps the server in sync:
```bash
cd ~/dotfiles-claude && git pull origin main
```

## Gotchas

### Permission grants can trigger bulk operations

When you grant a new permission (e.g., Full Disk Access to a sync script), the first run may bulk-operate on stale state. Example: a voice recording sync script was blocked by TCC for 3 days. When FDA was granted, it re-downloaded 93 recordings into duplicate folders because its sync index was empty.

**Prevention:** After granting new permissions, run the affected job with `--dry-run` first (if supported), or manually verify the sync state before the first real run.

### Cloud storage is eventually consistent

iCloud, Dropbox, and similar services are eventually consistent — files may take seconds to minutes to sync. If two processes (e.g., laptop Claude + server cron) write to the same cloud-synced directory, duplicates and conflicts are likely.

**Pattern: single-writer model (D22).** Designate one process as the folder owner. Other processes read files but never create or rename folders. Use metadata files (e.g., frontmatter in markdown) for display names instead of folder names.

## Monitoring (basic)

Check logs for errors:
```bash
# On server:
tail -f /var/log/claude/*.log

# Quick health check:
./check.sh
```

For alerting, add a log-check job that greps for ERROR in log files and sends a notification (email, Telegram, Slack webhook).
