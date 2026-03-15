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

## Monitoring (basic)

Check logs for errors:
```bash
# On server:
tail -f /var/log/claude/*.log

# Quick health check:
./check.sh
```

For alerting, add a log-check job that greps for ERROR in log files and sends a notification (email, Telegram, Slack webhook).
