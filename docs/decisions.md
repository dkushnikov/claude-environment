# Decisions

Key design decisions with rationale. Reference when you're making similar choices.

## D1: Dotfiles via symlinks, not copy

**Decision:** `~/.claude/` contains symlinks to dotfiles repo, not copies.
**Why:** Single source of truth. Edit in one place, reflected everywhere. `check.sh` validates symlink integrity.
**Trade-off:** If the repo is moved/deleted, symlinks break. Mitigated by `check.sh`.

## D2: Per-day JSON files, not database

**Decision:** Calendar sync writes one JSON file per day, not a SQLite database or single large file.
**Why:** Simple to debug (open in editor), simple to sync (file-level), natural unit (one day = one reflection). Claude reads individual files without loading everything.
**Trade-off:** Querying across many days requires reading multiple files. Acceptable for our use case (weeks, not years).

## D3: gws CLI over direct Google API

**Decision:** Calendar sync uses `gws` (Google Workspace CLI) instead of `google-api-python-client`.
**Why:** Auth handled transparently (encrypted keyring, auto-refresh). No credentials in env files. No pip dependencies. Works with both personal and Workspace accounts.
**Trade-off:** Dependency on external CLI tool. Mitigated: `gws` is open-source, API calls are standard — easy to replace.

## D4: iCloud for L1, not git

**Decision:** Pipeline data stored in iCloud Drive (or Dropbox), not in the vault's git repo.
**Why:** Pipeline data is large (thousands of JSON files), personal (calendar events), and changes frequently. Git would bloat. Cloud storage syncs automatically between machines.
**Trade-off:** Requires iCloud/Dropbox. Alternative: rsync, Syncthing, or any file sync tool.

## D5: Symlinks into vault, not direct writes

**Decision:** Pipelines write to cloud storage; vault accesses via symlink (`_inputs/ServiceName/`).
**Why:** Separation of concerns. Sync script doesn't need vault access. Vault doesn't need to know where data physically lives. Changing cloud provider = update one symlink.
**Trade-off:** One more level of indirection. Worth it for flexibility.

## D6: Three-layer cache (L1 → L2 → L3)

**Decision:** External data has three layers: cloud storage, vault symlink, session cache.
**Why:** Each layer serves a different purpose. L1 = durability + sync. L2 = vault access. L3 = fast session startup. MCP = fallback when all layers miss.
**Trade-off:** Complexity. But each layer is optional — start with L1+L2, add L3 when session startup is slow.

## D7: flock + jitter for cron jobs

**Decision:** Every cron job uses `flock` (prevent concurrent runs) and random jitter (15-45 seconds).
**Why:** Flock prevents overlapping runs when a job takes longer than the interval. Jitter prevents API rate limiting when multiple jobs start simultaneously.
**Trade-off:** Jobs start 15-45 seconds late. Acceptable for background automation.

## D8: Claude headless for agent jobs

**Decision:** Automated reflections/audits run via `claude -p` (headless, non-interactive).
**Why:** No human needed. Reads from local files (L2), writes to vault. Can run on server while you sleep.
**Trade-off:** No MCP (can't approve), no interactive input. Design pipeline so agent has everything it needs in local files.

## D9: Machine identity via environment.md

**Decision:** Each machine has a gitignored `environment.md` declaring its role.
**Why:** Same dotfiles repo, different behavior per machine. Claude reads environment.md and adjusts (e.g., no MCP on background server, no GUI commands).
**Trade-off:** Manual step per machine. Acceptable (one-time setup).

## D10: Work events as summary only

**Decision:** Work calendar events are synced as summary (count + hours + categories), not full details.
**Why:** Work details belong in a work vault/context. Personal vault gets just enough to understand the day's shape ("4 meetings, 5.5 hours, first at 9am").
**Trade-off:** Can't cross-reference specific work meetings from personal vault. By design — separation of concerns.
