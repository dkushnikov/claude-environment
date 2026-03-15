# Calendar Pipeline

Google Calendar events → per-day JSON files → Claude reads locally.

## Architecture

```
Google Calendar API (via gws CLI)
        ↓  calendar-sync.py (cron, every 15 min)
~/Cloud/Calendar/days/2026-03-15.json
        ↓  iCloud/Dropbox sync
_inputs/Calendar/days/2026-03-15.json  (vault symlink)
        ↓  Claude reads via Read tool
_claude/cache/calendar.md  (session cache, TTL 3h)
```

## Setup

### 1. Install Google Workspace CLI

```bash
brew install @googleworkspace/cli
# or: npm install -g @googleworkspace/cli
```

### 2. Authenticate

```bash
gws auth login --services calendar
```

Opens browser → log in with your Google account → authorize Calendar read access. Works with both personal Gmail and Google Workspace accounts.

### 3. Create data directory

```bash
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/YourApp/Calendar/days
# Or any cloud-synced directory. Adjust paths in config.json.
```

### 4. Configure calendars

Copy `config.example.json` to your data directory as `config.json`. Edit:
- Add your calendar IDs (find in Google Calendar → Settings → Calendar ID)
- Set sync levels: `full` (all details), `summary` (count + hours), `skip`, `none`
- Adjust routine patterns to filter (sleep, meals, etc.)

### 5. Create vault symlink

```bash
ln -s ~/Library/Mobile\ Documents/.../Calendar ~/vault/_inputs/Calendar
echo "_inputs/Calendar/" >> ~/vault/.gitignore
```

### 6. Test sync

```bash
python3 sync.py --date $(date +%Y-%m-%d)
```

### 7. Set up cron (optional)

Copy the LaunchAgent plist to `~/Library/LaunchAgents/` and load it, or add to crontab:

```bash
*/15 * * * * /path/to/jobs/calendar-sync.sh >> /var/log/calendar-sync.log 2>&1
```

## Output format

Each day produces one JSON file: `days/YYYY-MM-DD.json`

```json
{
  "date": "2026-03-15",
  "synced_at": "2026-03-15T14:12:11Z",
  "all_day": [
    {
      "summary": "Conference Trip",
      "calendar": "Personal",
      "start_date": "2026-03-14",
      "end_date": "2026-03-17",
      "location": "Berlin"
    }
  ],
  "events": [
    {
      "summary": "Gym with Pete",
      "calendar": "Personal",
      "start": "2026-03-15T08:00:00Z",
      "end": "2026-03-15T09:30:00Z",
      "duration_minutes": 90,
      "location": "Third Space",
      "attendees": [{"name": "Pete", "email": "pete@example.com"}],
      "recurring": true
    }
  ],
  "work_summary": {
    "total_meetings": 4,
    "total_hours": 5.5,
    "categories": {"1-1": 2, "Staff": 1, "Focus": 1},
    "first_meeting": "09:00",
    "last_meeting": "17:30"
  },
  "routine_filtered": ["Sleeping 22:00-06:00", "Breakfast 08:00-08:30"]
}
```

**Design decisions:**
- **Personal events:** full details (attendees, location, description)
- **Work events:** summary only (count + hours + categories). Full work details belong in a work vault.
- **Routine events:** filtered out of main events list, kept in `routine_filtered` for health analytics
- **Cancelled events:** excluded
- **OOO events:** treated as context (all_day), not meetings

## Files

| File | Purpose |
|------|---------|
| `sync.py` | Sync script: gws → per-day JSON |
| `config.example.json` | Calendar configuration template |
| `status.sh` | Check sync health, data freshness |

## How Claude uses this

**Session onboarding:** reads today's JSON → composes briefing ("3 meetings, gym at 8, dinner at 7")

**Daily reflection:** reads the day's JSON → structures the day as a table (time, event, type, notes)

**Weekly review:** reads 7 JSON files → aggregates patterns (meeting load, travel, routine changes)

**Plaud/voice classification:** reads JSON to cross-reference voice recordings with calendar events by time overlap

All with zero MCP calls. Falls back to MCP (`gcal_list_events`) only when JSON is missing.
