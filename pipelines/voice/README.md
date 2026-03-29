# Voice Pipeline

Voice recordings (diary, meetings, memos) → transcripts + metadata → vault notes.

## Pattern

```
Voice recorder API or file export
        ↓  sync script (cron)
~/Cloud/Voice/{YYYY-MM-DD}_{record_id[:8]}/
├── source.md    ← immutable transcript (sync owns this)
└── extract.md   ← metadata card (Claude or auto-extract creates this)
        ↓  symlink
_inputs/Voice/   (vault access)
```

## Key design decisions

**Id-based folder naming:** `{YYYY-MM-DD}_{record_id[:8]}` — date for human sorting, truncated ID for uniqueness. **Never rename after creation.** Human-readable titles live in `extract.md`, not the filesystem.

**Why not content-derived names?** Content names (AI titles, user edits) change. When iCloud sees a rename, it creates a delete + create event — other machines see both old and new folders. With multiple machines syncing, this causes duplicates. ID-based names are immutable by construction.

**Single writer:** Only the sync script creates folders and writes `source.md`. Claude writes `extract.md` but never touches `source.md` or renames folders. This prevents race conditions across machines.

**Two files per recording:** `source.md` (raw transcript, never edited) and `extract.md` (structured metadata: category, people, topics, summary). Re-run extraction without losing the original.

**Classification at sync time:** The sync script writes device type, category, and sensitivity into `source.md` frontmatter. This metadata is available before Claude extraction.

**Auto-extract:** After downloading a new recording, the sync script can optionally call Claude (Haiku model, ~$0.0003/recording) to generate a lightweight `extract.md`. This gives you metadata cards without interactive sessions. Full vault-aware extraction (calendar cross-reference, people resolution) happens later interactively.

## Status tracking

Each record has an explicit `status:` field in `extract.md`:

| Status | Meaning | Set by |
|--------|---------|--------|
| `synced` | Source file exists, transcript downloaded, no extract yet | Sync script (no extract.md) |
| `pending-transcript` | Source file exists but API returned no transcript content | Sync script (auto-retry next cycle) |
| `extracted` | Metadata card created | Claude extract step |
| `processed` | Deep analysis done, vault note created | Claude process step |

**`status:` is canonical.** Don't use derived fields (`processed_at:`) to determine pipeline state — they can be set incorrectly (learned from a batch processing incident).

**Pending-transcript:** Some voice recording APIs return file metadata before transcription completes. The sync script detects this (source.md has frontmatter but no transcript sections) and marks the recording for automatic retry on the next sync cycle.

## Sync script features

### Eviction protection

Cloud-synced files can be "evicted" (replaced with placeholders) by the OS to save space. If the sync script's index rebuild can't read evicted source files, the index becomes incomplete → the script re-downloads everything → duplicates.

**Protection:** Count evicted files during index backfill. If >20% are evicted, abort the sync with an error instead of proceeding with a partial index.

### Deduplication

A `.sync-index.json` in the data directory maps record IDs to folder names and status. The sync script:
1. Loads the index
2. Backfills from disk (self-healing if index is lost)
3. Checks each API record against known IDs
4. Skips known records (unless `pending-transcript`)

### Alerting

The job wrapper sends a macOS notification on failure:
```bash
if [[ $EXIT_CODE -ne 0 ]]; then
    osascript -e "display notification \"sync failed (exit $EXIT_CODE)\" with title \"Sync Error\"" 2>/dev/null || true
fi
```

## Extract format

```yaml
---
source_record_id: "unique-id-from-api"
recorded: YYYY-MM-DD
recorded_time: "HH:MM"
title: "Short descriptive title"
duration: "Xm Ys"
device: pin                    # device type
category: work-meeting         # classification
sensitivity: work              # work / personal / private
route: shared                  # where to send processed output

summary: "One-line summary"
people:
  - Person 1
topics:
  - Topic A
language: en

status: extracted
destination:
processed_at:
---

# Short Title

**Summary:** 2-3 sentences.

**Attendees:** people present
**Mentioned:** people discussed

**Topics:** comma-separated
```

## Cloud storage considerations (iCloud)

If using iCloud Drive as transport between machines:

| Constraint | Problem | Protection |
|------------|---------|------------|
| File eviction | OS removes file data, keeps placeholder | Detect in sync, abort if too many |
| No distributed lock | Multiple writers = duplicates | Single-writer model |
| Rename = delete + create | Other machines see both folders | Never rename — use metadata for titles |
| FDA context-dependent | LaunchAgent via .app has FDA, SSH does not | Document FDA requirements |

**Local storage has none of these issues.** If you don't need cross-machine sync of raw files, write to a local directory instead.

## Auto-extract setup

Auto-extract requires an API key for headless operation (cron/LaunchAgent can't use OAuth):

1. Get an API key from console.anthropic.com
2. Add `ANTHROPIC_API_KEY=sk-ant-...` to your pipeline config (gitignored)
3. Pass `--auto-extract` to the sync script
4. The script calls `claude -p --bare --model haiku` with the API key

`--bare` mode skips hooks, CLAUDE.md, and OAuth — uses only the env var. Fast and clean for automation.

## Files to create

For your own voice pipeline:

| File | Purpose |
|------|---------|
| `bin/voice-sync.py` | Download recordings, classify, write source.md |
| `bin/voice-classify.py` | Shared classification functions (device → category → sensitivity) |
| `bin/voice-status.sh` | Pipeline status (counts, health checks) |
| `config/voice.env` | API credentials, output directory (gitignored) |
| `config/classify_rules.json` | Classification keywords |
| `jobs/voice-sync.sh` | Cron wrapper: lock, alerting, `--auto-extract` |
| `launchd/com.user.voice-sync.plist` | macOS LaunchAgent |
| `.claude/skills/voice/SKILL.md` | Claude skill for interactive extract/process |
| `tests/test_voice_classify.py` | Classification unit tests |
