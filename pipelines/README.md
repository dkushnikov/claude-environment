# Data Pipelines

Patterns for feeding external data into your vault so Claude can read it without API calls.

## The problem

Claude Code can access external services via MCP (Model Context Protocol), but:
- MCP calls require user approval each time
- They're slow (network round-trip per request)
- They don't work on headless servers (no approval UI)
- They can't be cached or pre-processed

## The solution: three-layer pipeline

```
External API
     ↓  sync script (cron, every N minutes)
L1: Local storage (iCloud Drive / Dropbox / NAS)
     ↓  cloud sync between machines
L2: Vault symlink (_inputs/ServiceName/)
     ↓  Claude reads structured files via Read tool
L3: Session cache (_claude/cache/service.md)
```

### L1: Sync + Store

A script pulls data from an external API and writes structured files (JSON or Markdown) to a cloud-synced directory.

**Why cloud storage, not the vault directly?**
- Keeps large/binary data out of git
- Automatic sync between machines (iCloud, Dropbox, Syncthing)
- Vault stays clean — only symlinks

**Key decisions:**
- **One file per unit** (one day, one recording, one export). Enables incremental sync.
- **JSON for structured data** (calendar events, health metrics). Easy to query, merge, filter.
- **Markdown for text data** (transcripts, notes). Claude reads natively.
- **Atomic writes** (write to `.tmp`, then rename). No corrupt files from interrupted syncs.

### L2: Vault access

A symlink from `_inputs/ServiceName/` to the L1 directory. Claude uses the `Read` tool to access files.

```bash
ln -s ~/Library/Mobile\ Documents/.../ServiceData ~/vault/_inputs/ServiceName
```

Add to `.gitignore`:
```
_inputs/ServiceName/
```

### L3: Session cache

Claude composes a compact markdown summary from L2 data at session start. Cached in `_claude/cache/service.md` with a TTL.

```yaml
---
fetched: 2026-03-15T14:00
source: service-json    # or mcp-tool-name if fallback
ttl_hours: 3
---

# Today's data summary
...
```

**Priority cascade:**
1. L2 files (fresh JSON) → compose L3 cache
2. L3 cache (if fresh, skip L2 read)
3. MCP fallback (if both L2 and L3 unavailable)

## Pipeline anatomy

Every pipeline has the same components:

| Component | File | Purpose |
|-----------|------|---------|
| Sync script | `bin/service-sync.py` | Fetch from API, write structured files |
| Config | `config.json` (in L1 dir) | What to sync, credentials reference |
| Job wrapper | `jobs/service-sync.sh` | Cron wrapper: lock, alerting, logging |
| LaunchAgent | `launchd/com.user.service-sync.plist` | macOS scheduled task |
| Status checker | `bin/service-status.sh` | CLI health check |
| Claude command | `.claude/commands/service-sync.md` | Refresh L3 cache from L2 |
| Sync state | `.sync-state.json` (in L1 dir) | Last sync time, checksums |

## Case studies

### [Calendar](calendar/) — Google Calendar → per-day JSON

**Type:** Structured API (official, OAuth2)
**Auth:** `gws` CLI (Google Workspace CLI) handles OAuth transparently
**Output:** One JSON file per day with events, all-day events, work summary
**Sync frequency:** Every 15 minutes
**Use case:** Daily reflections, morning briefings, weekly reviews, session onboarding

### [Voice](voice/) — Voice recordings → transcripts + metadata

**Type:** Reverse-engineered API or file export
**Output:** Per-recording folder with source.md (transcript) + extract.md (metadata)
**Sync frequency:** Every few minutes
**Use case:** Processing diary entries, meeting notes, voice memos into vault notes

### [Health](health/) — Wearable data → metrics

**Type:** Official API (Oura) + file export (Apple Health)
**Output:** Daily JSON with sleep, activity, readiness scores
**Sync frequency:** Every 12 hours
**Use case:** Health tracking, sleep analysis, cross-referencing with calendar/diary

## Creating your own pipeline

1. **Identify the data source** — API, file export, scraping?
2. **Choose the storage format** — JSON (structured) or Markdown (text)?
3. **Choose the unit** — one file per day? per item? per export?
4. **Write the sync script** — fetch, transform, write atomically
5. **Create the job wrapper** — lock + jitter + logging (copy from template)
6. **Create the Claude command** — L2 → L3 cache composition
7. **Update check.sh** — add symlink + freshness validation

Template: copy `jobs/example-sync.sh` and `pipelines/calendar/` as starting points.
