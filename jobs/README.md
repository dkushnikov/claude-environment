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

## macOS: iCloud Drive and TCC

LaunchAgent processes can't access `~/Library/Mobile Documents/` (iCloud Drive) by default. macOS TCC (Transparency, Consent, and Control) blocks it — even if your interactive terminal has access.

**Symptom:** `PermissionError: [Errno 1] Operation not permitted` in cron logs for any script that reads/writes iCloud Drive paths.

**Solution:** Wrap your job in an Automator `.app` and grant it Full Disk Access.

### Creating an .app wrapper

```bash
# Create the AppleScript wrapper
cat > /tmp/wrapper.applescript << 'EOF'
on run
    try
        do shell script "/path/to/your/job.sh >> /path/to/log 2>&1"
    on error errMsg
        -- error already logged by the shell script, exit cleanly
    end try
end run
EOF

# Compile to .app
osacompile -o ~/Applications/YourJob.app /tmp/wrapper.applescript
```

Then: **System Settings → Privacy & Security → Full Disk Access → add the .app**.

Update your LaunchAgent plist to use the applet binary:
```xml
<key>Program</key>
<string>/Users/you/Applications/YourJob.app/Contents/MacOS/applet</string>
```

### Critical: always use try/on error

**Without `try/on error`**, if your script exits non-zero, AppleScript's `do shell script` raises an error. In a headless LaunchAgent this shows an invisible error dialog — the applet hangs forever, launchd thinks it's still running, and never restarts it. One failure = dead cron job until you manually `kill` the process.

### macOS lock pattern

`flock` doesn't exist on macOS. Use `mkdir` (atomic on POSIX):

```bash
LOCK_DIR="/tmp/jobname.lock.d"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_DIR") ))
    if (( lock_age > 600 )); then
        rm -rf "$LOCK_DIR"
        mkdir "$LOCK_DIR" 2>/dev/null || exit 0
    else
        exit 0  # another instance running
    fi
fi
trap 'rm -rf "$LOCK_DIR"' EXIT
```

### After tccutil reset

If you accidentally run `tccutil reset SystemPolicyAllFiles`, all FDA grants are wiped. Re-add your `.app` wrappers in System Settings. Running processes won't pick up new grants — kill existing PIDs so launchd restarts them with fresh TCC context.

## Files

| File | Purpose |
|------|---------|
| `example-sync.sh` | Template sync job |
| `example-agent.sh` | Template agent job (Claude headless) |
| `launchd/example.plist` | Template LaunchAgent |
