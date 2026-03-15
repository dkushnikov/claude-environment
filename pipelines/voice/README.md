# Voice Pipeline

Voice recordings (diary, meetings, memos) → transcripts + metadata → vault notes.

## Pattern

```
Voice recorder API or file export
        ↓  sync script
~/Cloud/Voice/YYYY-MM-DD Title/
├── source.md    ← immutable transcript (sync owns this)
└── extract.md   ← metadata card (Claude creates this)
        ↓  symlink
_inputs/Voice/   (vault access)
```

## Key design decisions

**Two files per recording:** `source.md` (raw transcript, never edited) and `extract.md` (structured metadata: category, people, topics, summary). This separation means you can re-run extraction without losing the original transcript.

**Folder per recording:** keeps transcript + metadata + optional audio together. Named `YYYY-MM-DD S — Title` where S = speaker count hint.

**Classification matrix:** device type × calendar overlap → category assignment. A recording during a calendar meeting = work meeting. A solo recording with no calendar match = personal diary.

**Calendar cross-reference:** mandatory during extraction. Read the day's calendar JSON to match recordings with events by time overlap. This fills in attendees and confirms category.

## Sync approaches

### Option A: Official API (if available)
Best case. Script authenticates, lists recordings, downloads transcripts. Example: Otter.ai API, Rev.ai.

### Option B: Reverse-engineered API
If no official API exists. Capture network requests, extract auth tokens, replicate calls. Fragile but works. Example: Plaud Note reverse-engineering.

### Option C: File export
Manual or automated export to a folder. Simplest but least automated. Example: Apple Voice Memos → iCloud folder.

## Processing pipeline

```
Sync (automatic)     → source.md exists
Extract (Claude)     → extract.md created (metadata, classification)
Process (Claude)     → vault note created (reflection, meeting notes, etc.)
```

**Extract** is the key step: Claude reads the transcript, cross-references with calendar and people database, and creates a structured metadata card. This can run in batch (`claude -p` headless) or interactively.

**Process** requires vault context (which area does this belong to? what's the follow-up?) — best done interactively.

## Files to create

For your own voice pipeline, you'll need:
- `bin/voice-sync.py` — download recordings to L1
- `config.json` — API credentials, output directory
- `jobs/voice-sync.sh` — cron wrapper
- `.claude/commands/voice-extract.md` — Claude command for batch extraction
- `.claude/commands/voice-process.md` — Claude command for interactive processing
