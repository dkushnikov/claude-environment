# Claude Environment

A framework for running Claude Code across multiple machines with data pipelines, automation, and Obsidian vault integration.

**What this solves:** You use Claude Code daily. You have a laptop and a server (or two laptops). You want the same rules, skills, and behavior everywhere. You want data from external services (calendar, health, voice recordings) flowing into your vault automatically. You want cron jobs running reflections and audits while you sleep.

This repo gives you the patterns, templates, and reference implementations to build that.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Claude Code                                        │
│  ├── CLAUDE.md ─────────┐                           │
│  ├── rules/             │ symlinked from dotfiles   │
│  ├── skills/            │                           │
│  └── settings.json ─────┘                           │
├─────────────────────────────────────────────────────┤
│  Vault (_inputs/)                                   │
│  ├── Calendar/ ──→ iCloud/Dropbox (symlink)         │
│  ├── Health/   ──→ local export (symlink)           │
│  └── Voice/    ──→ iCloud/Dropbox (symlink)         │
├─────────────────────────────────────────────────────┤
│  Pipelines (cron, every N minutes)                  │
│  ├── API ──→ structured files (JSON/MD)             │
│  ├── synced via iCloud/Dropbox between machines     │
│  └── Claude reads local files, no API calls needed  │
├─────────────────────────────────────────────────────┤
│  Dotfiles repo (git, synced between machines)       │
│  ├── bin/     scripts                               │
│  ├── jobs/    cron wrappers                         │
│  ├── config/  credentials (.gitignored)             │
│  └── launchd/ LaunchAgent plists (macOS)            │
└─────────────────────────────────────────────────────┘
```

### Three-layer data pipeline

Every external data source follows the same pattern:

```
External API (Google Calendar, Oura, Plaud, ...)
        ↓  sync script (cron, every N minutes)
L1: Cloud storage (iCloud Drive / Dropbox / local)
        ↓  synced between machines automatically
L2: Vault symlink (_inputs/ServiceName/)
        ↓  Claude reads structured files
L3: Session cache (_claude/cache/service.md, TTL-based)
```

**Why three layers?**
- **L1** decouples sync frequency from Claude sessions. Sync runs every 15 min; Claude reads whenever.
- **L2** keeps synced data out of git (symlink, gitignored). Vault stays clean.
- **L3** gives Claude a fast, pre-composed view for session startup. Rebuilt from L2 when stale.

## Quick start

```bash
# 1. Clone
git clone https://github.com/user/claude-environment.git ~/dotfiles-claude
cd ~/dotfiles-claude

# 2. Install — creates symlinks, sets up directories
./install.sh

# 3. Configure your machine identity
cp dotfiles/rules/environment.md.example dotfiles/rules/environment.md
# Edit: set your machine name, role (interactive/background), hostname

# 4. Validate
./check.sh
```

Then pick the pipelines you need — see [pipelines/](pipelines/).

## What's included

### Dotfiles (Claude Code config)

Templates for Claude Code configuration that sync across machines via git.

| File | Purpose |
|------|---------|
| `CLAUDE.md.example` | Walk-up context: who you are, communication style, project context |
| `settings.json.example` | Permissions, allowed tools, MCP servers |
| `rules/environment.md.example` | Machine identity: name, role, hardware |
| `skills/` | Example skills (reusable prompt templates) |

See [dotfiles/](dotfiles/).

### Pipelines (data integration)

Patterns and reference implementations for feeding external data into your vault.

| Pipeline | Source | Output | Status |
|----------|--------|--------|--------|
| [Calendar](pipelines/calendar/) | Google Calendar (via `gws` CLI) | Per-day JSON files | Reference implementation |
| [Voice](pipelines/voice/) | Voice recorder transcripts | Markdown + metadata | Pattern description |
| [Health](pipelines/health/) | Oura Ring, Apple Health | JSON / CSV | Pattern description |

Each pipeline includes: architecture, sync script, config template, status checker.

See [pipelines/](pipelines/).

### Jobs (automation)

Templates for scheduled tasks: cron wrappers with locking, jitter, and logging.

| Pattern | Purpose |
|---------|---------|
| Sync job | Pull data from API on schedule |
| Check job | Validate system health |
| Agent job | Run Claude Code headless (`claude -p`) |

See [jobs/](jobs/).

### Multi-machine

Patterns for laptop + server setups: sync, deploy, identity, secrets.

See [multi-machine/](multi-machine/).

## Principles

1. **Templates, not opinions.** Customize everything. No locked-in structure.
2. **Secrets are local.** API tokens, credentials — only on the specific machine. Zero secrets in git.
3. **Sync via cloud, not git.** Pipeline data syncs via iCloud/Dropbox. Git = config + code only.
4. **Idempotent scripts.** `install.sh` and `check.sh` can run repeatedly without side effects.
5. **Simplicity.** Bash over frameworks. Files over databases. Symlinks over copies.
6. **Progressive complexity.** Start with dotfiles only. Add pipelines when you need them. Add automation when it's worth it.

See [docs/principles.md](docs/principles.md) for the full list with rationale.

## Who is this for?

- You use Claude Code as your primary AI coding/thinking tool
- You work across multiple machines (laptop + server, home + work)
- You use Obsidian (or similar) as a knowledge base
- You want external data (calendar, health, recordings) available to Claude without MCP calls
- You want automation (daily reflections, vault audits) running on schedule

## Project history

Built from real usage: 50+ Claude Code sessions, 3 months of daily use across laptop and home server. Patterns evolved from solving actual problems — not designed top-down.

Key milestones:
- Dotfiles structure and multi-machine sync
- Data pipeline pattern (Calendar, Plaud voice recordings, Oura health data)
- Cron automation with LaunchAgent integration
- Session onboarding protocol (briefing from cached data)

## Related

- [Obsidian Seed](https://github.com/dkushnikov/obsidian-seed) — Obsidian vault setup wizard. **Seed = vault content methodology, Environment = infrastructure around it.** Start with Seed to build your vault, then use this repo to add pipelines, automation, and multi-machine support.

## License

MIT
