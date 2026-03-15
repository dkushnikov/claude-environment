#!/usr/bin/env python3
"""
Calendar Sync — pull Google Calendar events into per-day JSON files.

Uses `gws` (Google Workspace CLI) for API access — no direct OAuth2 management.
Auth handled by `gws auth login --services calendar` (one-time).

Architecture:
    L1: gws → iCloud Drive / Claude Data / Calendar / days / YYYY-MM-DD.json
    L2: _inputs/Calendar/ (symlink) — Claude reads JSON
    L3: _claude/cache/calendar.md (TTL 3h, session-level, composed by Claude)

Usage:
    python3 calendar-sync.py                    # sync configured range
    python3 calendar-sync.py --now              # same, explicit
    python3 calendar-sync.py --date 2026-03-14  # sync single date
    python3 calendar-sync.py --backfill 30      # sync last 30 days

Prerequisites:
    gws auth login --services calendar
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path


# --- gws CLI ---

GWS_BIN = shutil.which("gws") or "/opt/homebrew/bin/gws"


def gws_fetch_events(calendar_id: str, time_min: str, time_max: str,
                     tz: str = "Europe/London") -> list:
    """Fetch events from one calendar via gws CLI."""
    params = {
        "calendarId": calendar_id,
        "timeMin": time_min,
        "timeMax": time_max,
        "timeZone": tz,
        "singleEvents": True,
        "orderBy": "startTime",
        "maxResults": 2500,
    }

    try:
        result = subprocess.run(
            [GWS_BIN, "calendar", "events", "list",
             "--params", json.dumps(params),
             "--page-all", "--format", "json"],
            capture_output=True, text=True, timeout=30
        )
    except FileNotFoundError:
        print(f"Error: gws not found at {GWS_BIN}. Install: brew install @googleworkspace/cli")
        sys.exit(1)
    except subprocess.TimeoutExpired:
        print(f"  Warning: timeout fetching {calendar_id}")
        return []

    if result.returncode != 0:
        stderr = result.stderr.strip()
        if "401" in stderr or "authError" in stderr:
            print(f"Error: gws not authenticated. Run: gws auth login --services calendar")
            sys.exit(1)
        print(f"  Warning: gws error for {calendar_id}: {stderr[:200]}")
        return []

    # gws --page-all outputs NDJSON (one JSON object per page)
    events = []
    for line in result.stdout.strip().split("\n"):
        if not line.strip():
            continue
        try:
            page = json.loads(line)
            events.extend(page.get("items", []))
        except json.JSONDecodeError:
            continue

    return events


# --- Config ---

def load_config(data_dir: Path) -> dict:
    """Load calendar config from data directory."""
    config_path = data_dir / "config.json"
    if not config_path.exists():
        print(f"Error: config.json not found at {config_path}")
        sys.exit(1)
    return json.loads(config_path.read_text(encoding="utf-8"))


def get_calendars_by_sync(config: dict, level: str) -> list:
    """Get calendars with the specified sync level."""
    result = []
    for group in config["calendars"].values():
        for cal in group:
            if cal.get("sync") == level:
                result.append(cal)
    return result


# --- Sync state ---

SYNC_STATE_NAME = ".sync-state.json"


def load_sync_state(data_dir: Path) -> dict:
    state_path = data_dir / SYNC_STATE_NAME
    if state_path.exists():
        try:
            return json.loads(state_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return {"version": 1, "days": {}}
    return {"version": 1, "days": {}}


def save_sync_state(data_dir: Path, state: dict):
    state["last_sync"] = datetime.now(timezone.utc).isoformat()
    state_path = data_dir / SYNC_STATE_NAME
    tmp_path = state_path.with_suffix(".tmp")
    tmp_path.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
    tmp_path.rename(state_path)


# --- Event processing ---

def is_routine(summary: str, patterns: list) -> bool:
    if not summary:
        return False
    summary_lower = summary.lower()
    return any(p.lower() in summary_lower for p in patterns)


def categorize_work_event(summary: str) -> str:
    s = (summary or "").lower()
    if "1-1" in s or "1:1" in s or "one-on-one" in s:
        return "1-1"
    if "staff" in s:
        return "Staff"
    if "all hands" in s or "all-hands" in s or "town hall" in s:
        return "All Hands"
    if "focus" in s or "deep work" in s or "maker" in s:
        return "Focus"
    if "interview" in s:
        return "Interview"
    if "standup" in s or "stand-up" in s or "sync" in s:
        return "Sync"
    if "review" in s or "retro" in s:
        return "Review"
    if "lunch" in s or "ooo" in s or "out of office" in s or "personal" in s:
        return "Personal"
    return "Meeting"


def parse_event(event: dict, cal_name: str) -> dict:
    """Parse a Google Calendar API event into our compact format."""
    start = event.get("start", {})
    end = event.get("end", {})
    is_all_day = "date" in start and "dateTime" not in start

    parsed = {
        "summary": event.get("summary", "(no title)"),
        "calendar": cal_name,
        "status": event.get("status", "confirmed"),
    }

    if event.get("eventType"):
        parsed["event_type"] = event["eventType"]

    if is_all_day:
        parsed["all_day"] = True
        parsed["start_date"] = start.get("date")
        parsed["end_date"] = end.get("date")
    else:
        parsed["all_day"] = False
        start_dt = start.get("dateTime", "")
        end_dt = end.get("dateTime", "")
        parsed["start"] = start_dt
        parsed["end"] = end_dt
        if start_dt and end_dt:
            try:
                s = datetime.fromisoformat(start_dt)
                e = datetime.fromisoformat(end_dt)
                parsed["duration_minutes"] = int((e - s).total_seconds() / 60)
            except (ValueError, TypeError):
                pass

    if event.get("location"):
        parsed["location"] = event["location"]

    attendees = event.get("attendees", [])
    parsed_attendees = []
    for a in attendees:
        if a.get("self"):
            continue
        entry = {}
        if a.get("displayName"):
            entry["name"] = a["displayName"]
        if a.get("email"):
            entry["email"] = a["email"]
        if a.get("responseStatus"):
            entry["response"] = a["responseStatus"]
        if entry:
            parsed_attendees.append(entry)
    if parsed_attendees:
        parsed["attendees"] = parsed_attendees

    if event.get("recurringEventId"):
        parsed["recurring"] = True

    desc = event.get("description", "")
    if desc and len(desc) > 500:
        desc = desc[:500] + "..."
    if desc:
        parsed["description"] = desc

    return parsed


def build_work_summary(events: list) -> dict:
    # Exclude all-day and OOO events from meeting count
    timed_events = [e for e in events
                    if not e.get("all_day")
                    and e.get("event_type") != "outOfOffice"]
    total_minutes = sum(e.get("duration_minutes", 0) for e in timed_events)
    categories = {}
    first_start = None
    last_end = None

    for e in timed_events:
        cat = categorize_work_event(e.get("summary", ""))
        categories[cat] = categories.get(cat, 0) + 1
        start = e.get("start", "")
        end = e.get("end", "")
        if start:
            t = start[11:16] if len(start) > 16 else start
            if first_start is None or t < first_start:
                first_start = t
        if end:
            t = end[11:16] if len(end) > 16 else end
            if last_end is None or t > last_end:
                last_end = t

    key_meetings = []
    for e in timed_events:
        cat = categorize_work_event(e.get("summary", ""))
        if cat in ("1-1", "All Hands", "Staff", "Interview"):
            key_meetings.append(e.get("summary", ""))

    summary = {
        "total_meetings": len(timed_events),
        "total_hours": round(total_minutes / 60, 1),
        "categories": categories,
    }
    if first_start:
        summary["first_meeting"] = first_start
    if last_end:
        summary["last_meeting"] = last_end
    if key_meetings:
        summary["key_meetings"] = key_meetings[:5]
    return summary


# --- Build day file ---

def build_day_file(config: dict, date_str: str) -> dict:
    """Build the complete day file for a given date."""
    tz = config["sync"].get("timezone", "Europe/London")
    routine_patterns = config["sync"].get("routine_patterns", [])

    time_min = f"{date_str}T00:00:00Z"
    next_day = (datetime.fromisoformat(date_str) + timedelta(days=1)).strftime("%Y-%m-%d")
    time_max = f"{next_day}T00:00:00Z"

    all_day_events = []
    timed_events = []
    routine_filtered = []
    work_events = []

    # Full-sync calendars
    for cal in get_calendars_by_sync(config, "full"):
        if "FILL_IN" in cal["id"]:
            continue
        raw_events = gws_fetch_events(cal["id"], time_min, time_max, tz)
        for raw in raw_events:
            if raw.get("status") == "cancelled":
                continue
            parsed = parse_event(raw, cal["name"])
            if parsed.get("all_day"):
                all_day_events.append(parsed)
            elif is_routine(parsed.get("summary", ""), routine_patterns):
                start = parsed.get("start", "")
                end = parsed.get("end", "")
                st = start[11:16] if len(start) > 16 else "?"
                et = end[11:16] if len(end) > 16 else "?"
                routine_filtered.append(f"{parsed['summary']} {st}-{et}")
            else:
                timed_events.append(parsed)

    # Summary-sync calendars (work)
    for cal in get_calendars_by_sync(config, "summary"):
        if "FILL_IN" in cal["id"]:
            continue
        raw_events = gws_fetch_events(cal["id"], time_min, time_max, tz)
        for raw in raw_events:
            if raw.get("status") == "cancelled":
                continue
            parsed = parse_event(raw, cal["name"])
            # OOO and all-day → context, not work meetings
            if parsed.get("all_day") or parsed.get("event_type") == "outOfOffice":
                all_day_events.append(parsed)
            else:
                work_events.append(parsed)

    timed_events.sort(key=lambda e: e.get("start", ""))

    result = {
        "date": date_str,
        "synced_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    if all_day_events:
        result["all_day"] = all_day_events
    if timed_events:
        result["events"] = timed_events
    if work_events:
        result["work_summary"] = build_work_summary(work_events)
    if routine_filtered:
        result["routine_filtered"] = routine_filtered

    return result


# --- Write ---

def write_day_file(data_dir: Path, date_str: str, data: dict) -> Path:
    days_dir = data_dir / "days"
    days_dir.mkdir(parents=True, exist_ok=True)
    file_path = days_dir / f"{date_str}.json"
    tmp_path = file_path.with_suffix(".tmp")
    tmp_path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    tmp_path.rename(file_path)
    return file_path


# --- Main ---

def main():
    parser = argparse.ArgumentParser(description="Sync Google Calendar to local JSON files")
    default_data_dir = os.path.expanduser(
        "~/Library/Mobile Documents/com~apple~CloudDocs/Claude Data/Calendar"
    )
    parser.add_argument("--data-dir", "-d", default=default_data_dir,
                        help=f"Data directory (default: iCloud)")
    parser.add_argument("--date", help="Sync a single date (YYYY-MM-DD)")
    parser.add_argument("--backfill", type=int, help="Backfill N days into the past")
    parser.add_argument("--now", action="store_true", help="Run immediately (manual use)")
    args = parser.parse_args()

    data_dir = Path(args.data_dir)
    if not data_dir.exists():
        print(f"Error: data directory not found: {data_dir}")
        sys.exit(1)

    # Verify gws is available and authenticated
    if not shutil.which("gws") and not os.path.exists(GWS_BIN):
        print("Error: gws not found. Install: brew install @googleworkspace/cli")
        sys.exit(1)

    config = load_config(data_dir)
    state = load_sync_state(data_dir)

    today = datetime.now().date()
    if args.date:
        dates = [args.date]
    elif args.backfill:
        dates = [(today - timedelta(days=i)).isoformat() for i in range(args.backfill, -1, -1)]
    else:
        past_days = config["sync"].get("past_days", 3)
        future_days = config["sync"].get("future_days", 14)
        dates = [(today + timedelta(days=i)).isoformat() for i in range(-past_days, future_days + 1)]

    print(f"Syncing {len(dates)} days ({dates[0]} → {dates[-1]})")

    synced = 0
    errors = 0

    for date_str in dates:
        try:
            data = build_day_file(config, date_str)
            write_day_file(data_dir, date_str, data)

            ec = len(data.get("events", []))
            ac = len(data.get("all_day", []))
            wc = data.get("work_summary", {}).get("total_meetings", 0)
            print(f"  {date_str}: {ec} events, {ac} all-day, {wc} work")

            state.setdefault("days", {})[date_str] = {
                "synced_at": data["synced_at"], "events": ec, "all_day": ac, "work": wc,
            }
            synced += 1
        except Exception as e:
            print(f"  {date_str}: ERROR — {e}")
            errors += 1

    save_sync_state(data_dir, state)
    print(f"\nDone! {synced} synced, {errors} errors. Output: {data_dir / 'days'}")


if __name__ == "__main__":
    main()
