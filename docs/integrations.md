# Integrations

External services grouped by identity layer. This categorization helps decide what travels with a person vs what stays with a company.

## Overview

| Service | Layer | Access Method | Auth | Machine(s) |
|---------|-------|--------------|------|------------|
| Health tracker (Oura) | Person | MCP (local) | Cloud API token | Laptop, Server |
| Apple Health | Person | File sync | Local export app | Laptop |
| Voice recorder (Plaud) | Person | API + cloud sync | API token | Laptop, Server |
| Google Calendar | Shared (person + role) | MCP (claude.ai) | Google OAuth | Laptop, Server |
| Gmail | Shared (person + role) | MCP (claude.ai) | Google OAuth | Laptop, Server |
| Meeting transcripts (Granola) | Shared (person + role) | MCP (claude.ai) | Account auth | Laptop |
| Slack | Role (company) | MCP (claude.ai) | Slack OAuth | Laptop |
| Notion | Role (company) | MCP (claude.ai) | Notion OAuth | Laptop |
| GitHub | Infrastructure | CLI (gh) + MCP | SSH keys + gh auth | Laptop, Server |
| Obsidian | Infrastructure | CLI | Local (must be running) | Laptop |
| Chrome CDP | Infrastructure | Playwright (:9222) | Local (no auth) | Server |
| SSH | Infrastructure | MCP | SSH keys | Laptop |

## Person (portable)

Integrations that belong to the person, not to any role. Go with you when you leave a company.

**Health tracker** — sleep, readiness, activity, HRV, stress, heart rate. Cloud API, token-based auth. Integration points: evening reflection, morning briefing, weekly health check. Personal vault only.

**Apple Health** — two channels: full archive export (JSON, all metrics + workouts) and daily automated export (lighter, routine pulls). Both flow through cloud storage symlinks.

**Voice recorder** — transcripts + AI summaries. API access via custom client. Server runs cron sync → cloud storage → symlink into vault. Processing pipeline: synced → classified → indexed → extracted → routed.

## Shared (person + role)

Single account covers both personal and work contexts. Routing is behavioral (by topic/participants), not by account.

**Google Calendar** — read-only in personal vault. Personal events visible via sharing to work account. Work calendars accessed from work vault. Feeds: daily reflections, weekly reviews, monthly summaries.

**Gmail** — search, read, draft. Work account only.

**Meeting transcripts** — routing: work participants/topics → work vault, coaching/personal → personal vault. Personal meetings never appear in work vault.

## Role (company)

Company-specific integrations. Stay with the role, not the person. On a company rollout, these would be provided by company IT.

**Slack** — company workspace. Read channels, search, send messages. Work vault context only.

**Notion** — company workspace. Search, read, create pages. Work vault context only.

## Infrastructure

Tools and services that support the environment itself. Not tied to person or role — tied to machine setup.

**Obsidian CLI** — search, read, create, append, manage properties, tags, backlinks, daily notes. Requires Obsidian app running.

**GitHub CLI** (`gh`) — PRs, issues, releases, checks. SSH key auth.

**Chrome CDP** — Playwright on port 9222. Server only. Browser automation: scraping, monitoring, forms. Needs SSH tunnel for laptop-initiated sessions.

**SSH Manager** — server management from laptop. Commands, file transfer, tunnels, monitoring.

## Categorization Principle

The Person / Shared / Role / Infrastructure split answers one question: **what happens when you change jobs?**

- **Person** services come with you. No change needed.
- **Shared** services need re-routing (new work account, same personal account).
- **Role** services are replaced entirely (new company Slack, new Notion).
- **Infrastructure** services are re-provisioned (new SSH keys, new machine setup).

This categorization also maps cleanly to the [layered model](architecture.md): Person = Layer 1, Role = organization/department layers, Infrastructure = machine-level.

## MCP Model Config Persistence

MCP servers installed via `uvx` (like PAL) store model configs in ephemeral cache (`~/.cache/uv/archive-v0/.../conf/`). These configs are overwritten on package update.

**Pattern:** Use the server's env var override to point at a git-tracked config file:

```json
// In ~/.claude/settings.json → mcpServers:
"pal": {
  "command": "bash",
  "args": ["-c", "source ~/.zshrc 2>/dev/null; exec uvx --from ... pal-mcp-server"],
  "env": {
    "OPENROUTER_MODELS_CONFIG_PATH": "~/dotfiles-claude/config/pal-openrouter-models.json"
  }
}
```

The config file lives in the dotfiles repo → git-tracked, syncs to all machines. Update models by editing the JSON and committing. Survives `uvx` cache invalidation.

**Discovery:** PAL's `OpenRouterModelRegistry` checks `env_var_name="OPENROUTER_MODELS_CONFIG_PATH"` → falls back to bundled config. Other MCP servers may have similar override patterns — check their registry/config loader source code.
