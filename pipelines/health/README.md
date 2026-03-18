# Health Pipeline

> **Status: pattern description only.** No runnable code yet. See [Calendar pipeline](../calendar/) for a working reference implementation.

Wearable + health app data → structured metrics → cross-reference with calendar and diary.

## Pattern

```
Health API (Oura Ring, Whoop, Garmin, ...)
        ↓  sync script or MCP
~/Cloud/Health/daily/YYYY-MM-DD.json
        ↓  symlink
_inputs/Health/   (vault access)
```

## Data sources

### Wearable APIs (Oura, Whoop, Garmin)

Official REST APIs with OAuth2. Sync script pulls daily summaries:
- Sleep: score, duration, deep/REM/light, latency
- Readiness/recovery: HRV, resting HR, temperature
- Activity: steps, calories, workouts

**Sync frequency:** every 12 hours (data updates overnight and mid-day).

### Apple Health (via auto-export apps)

No direct API from macOS. Use apps like Health Auto Export that write JSON to iCloud on schedule. Symlink the export directory.

**Data available:** workouts, steps, heart rate, VO2 max, body measurements.

### MCP as fallback

Some health services have MCP servers (e.g., Oura MCP). Use as interactive fallback when JSON files aren't available, but prefer local files for automation.

## Output format

```json
{
  "date": "2026-03-15",
  "sleep": {
    "score": 82,
    "total_hours": 7.5,
    "deep_hours": 1.2,
    "rem_hours": 1.8,
    "latency_minutes": 12
  },
  "readiness": {
    "score": 78,
    "hrv_ms": 45,
    "resting_hr": 52,
    "temperature_deviation": 0.1
  },
  "activity": {
    "steps": 12500,
    "active_calories": 450,
    "workouts": [
      {"type": "strength", "duration_minutes": 60, "source": "apple_health"}
    ]
  }
}
```

## Cross-references (where it gets interesting)

Health data alone is useful. Combined with calendar and diary data, it's powerful:

| Cross-reference | Insight |
|----------------|---------|
| Calendar last event × sleep onset | Evening pattern → sleep impact |
| Meeting hours × next-day HRV | Work stress → recovery correlation |
| Workout in calendar × workout in Health | Intent vs actual (showed up?) |
| Travel days × sleep quality | Travel impact pattern |
| Heavy meeting day → HRV lag | Stress manifests 0-1 days later |

Claude can compute these when it has all three data sources (calendar JSON + health JSON + diary text) as local files.

## Implementation notes

- Start with MCP if your service has one (quickest to get data flowing)
- Migrate to local sync when you want automation or cross-machine access
- Health data is sensitive — keep in local/cloud storage, not in git
- Gitignore the symlink: `_inputs/Health/`
