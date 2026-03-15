# Jobs (Scheduled Automation)

Templates for running scripts on schedule. Three patterns: sync, check, and agent.

## Job wrapper pattern

Every cron job follows the same structure:

```bash
#!/bin/bash
set -uo pipefail

LOCK_FILE="/tmp/jobname.lock"

# 1. Prevent concurrent runs (flock)
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "[$(date)] Another instance running, skipping"
    exit 0
fi

# 2. Jitter (spread load, avoid API rate limits)
JITTER=$((15 + RANDOM % 31))
sleep "$JITTER"

# 3. Check prerequisites
# ...

# 4. Run the actual work
# ...

# 5. Log result
echo "[$(date)] Done (exit: $?)"
```

**Why flock?** Prevents overlapping runs if the previous instance hasn't finished.
**Why jitter?** If you have multiple jobs starting at the same time, jitter spreads the API calls. Also reduces fingerprinting from predictable request patterns.

## macOS: LaunchAgent

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.yourname.jobname</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/jobs/jobname.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>900</integer>  <!-- seconds: 900 = 15 min -->
    <key>StandardOutPath</key>
    <string>/var/log/claude/jobname.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/claude/jobname.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin</string>
        <key>HOME</key>
        <string>/Users/yourname</string>
    </dict>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
```

Install: `cp plist ~/Library/LaunchAgents/ && launchctl load ~/Library/LaunchAgents/plist`

## Linux: cron

```
*/15 * * * * /path/to/jobs/jobname.sh >> /var/log/claude/jobname.log 2>&1
```

## Job types

### Sync job
Pulls data from API on schedule. Example: calendar sync (every 15 min), voice recording sync (every 1 min).

### Check job
Validates system health. Example: vault audit (daily), log rotation.

### Agent job
Runs Claude Code headless. Example: daily reflection at 22:00.

```bash
claude -p "Run /daily-reflection for today" \
    --allowedTools "Read,Write,Edit,Glob,Grep,Bash" \
    --max-turns 30
```

**Gotcha:** headless Claude can't access keychain-based credentials or MCP servers that require browser auth. Design your pipeline so the agent reads from local files (L2), not from APIs.

## Files

| File | Purpose |
|------|---------|
| `example-sync.sh` | Template sync job |
| `example-agent.sh` | Template agent job (Claude headless) |
| `launchd/example.plist` | Template LaunchAgent |
