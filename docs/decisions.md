# Decisions

Key design decisions with rationale. Reference when you're making similar choices. Grouped by domain. 42 decisions from 4 weeks of building.

## Architecture & Dotfiles

### D1: Dotfiles via symlinks, not copy
**Decision:** `~/.claude/` contains symlinks to dotfiles repo, not copies.
**Why:** Single source of truth. Edit in one place, reflected everywhere. Avoids CVE risks from full directory sync, iCloud eviction, and JSONL corruption on concurrent writes.
**Trade-off:** If the repo is moved/deleted, symlinks break. Mitigated by `check.sh`.

### D2: Memory is local per machine
**Decision:** Each machine builds its own memory cache. Shared context lives in vault files (synced via Obsidian Sync or cloud storage), not in Claude's memory.
**Why:** Different machines run different tasks (interactive vs automation). They build different context.

### D3: `--add-dir` for cross-project context
**Decision:** Use Claude Code's `--add-dir` for cross-vault or cross-project work, not symlinks or copying.
**Why:** Official mechanism. No CVE risks. Doesn't break git context. Skills load correctly from added dirs.

### D4: Universal skills global, domain skills in projects
**Decision:** Only universal skills (web scraping, transcription) in `~/.claude/skills/`. Domain skills (Obsidian formatting, vault audit) stay in each project's `.claude/skills/`.
**Why:** Domain skills in the wrong project waste context and add noise. ~40% of context was irrelevant in cross-domain use.

### D5: Content sync via Obsidian Sync, git for backup
**Decision:** Real-time content sync via Obsidian Sync (or equivalent). Git for version history and backup, not sync.
**Why:** Sync is real-time to all devices. Git auto-commit conflicts with Sync on timing.

### D6: Global CLAUDE.md = identity only
**Decision:** Global CLAUDE.md contains who you are, communication style, preferences. Domain conventions moved to domain-level CLAUDE.md.
**Why:** In a coding project, Obsidian conventions are noise — roughly 40% of the global file was irrelevant content.

### D7: Bash scripts, not chezmoi
**Decision:** Simple bash scripts for install/check, not a dotfile manager.
**Why:** With ~10 files and 2 machines, a simple bash script beats a templating engine. Migration trigger: 3+ machines or 25+ managed files.

### D8: Machine identity via environment.md
**Decision:** Each machine has a gitignored `environment.md` declaring its role (interactive vs background).
**Why:** Same dotfiles repo, different behavior per machine. No conditional logic in shared config.

### D27: Separate architecture docs from behavioral rules
**Decision:** System architecture, storage models, and infrastructure belong in architecture/design docs. Protocols keep only behavioral rules (how Claude should act).
**Why:** Protocols grew into mixed system design + behavioral rules. Splitting makes each document focused.

## Permissions & Safety

### D24: Permission split — generic global, project-specific local
**Decision:** Global `settings.json` covers CLI, git, system tools. Local `settings.local.json` covers project-specific paths and domain commands.
**Why:** Reduces noise in templates. Allow rules merge across levels. Deny from any level wins.

### D25: Shell heuristic override via PreToolUse hook
**Decision:** Use a PreToolUse hook to bypass shell safety heuristics for known-safe commands. Conservative whitelist of ~80 commands.
**Why:** 23 shell safety checks are hardcoded in the Claude Code binary ([#30435](https://github.com/anthropics/claude-code/issues/30435), [#34106](https://github.com/anthropics/claude-code/issues/34106)). A PreToolUse hook returning `permissionDecision: "allow"` is the only override mechanism.
**Trade-off:** Hook adds ~50ms per Bash command. Acceptable for interactive sessions.

### D26: `Bash(cmd *)` with space, not `Bash(cmd:*)`
**Decision:** All permission patterns use space syntax: `Bash(command *)`.
**Why:** The legacy `Bash(command:*)` syntax is deprecated and doesn't match compound commands.

### D40: `Bash(*)` replaces per-command rules
**Decision:** Replace hundreds of individual `Bash(command *)` rules with a single `Bash(*)` in global settings. Move safety enforcement from Layer 1 (allow/deny patterns) to Layer 4 (PreToolUse hook).
**Why:** Individual command rules are security theater — `python3 *` and `ssh *` already allow arbitrary code execution. Real protection comes from deny rules + the tengu-override hook (force-prompts on `rm -rf`, `git push --force`, `dd`). See [hooks.md](hooks.md#destructive-command-safety-net).
**Trade-off:** Requires the tengu-override hook as safety net. Without it, everything auto-approves.

### D41: Permissions audit with baseline drift detection
**Decision:** A `permissions-audit.sh` script compares current `settings.local.json` against a saved baseline, detecting rule accumulation, duplicates, and invalid patterns.
**Why:** Claude Code auto-appends one-off commands to the allow list during sessions. Over time, local settings grow from 20 rules to 200+. The audit detects: drift from baseline (+5 = warning, +15 = error), local rules redundant with global `Bash(*)`, invalid patterns. See [`dotfiles/bin/permissions-audit.sh`](../dotfiles/bin/permissions-audit.sh).

## MCP & Multi-Model

### D28: MCP server registration vs permissions — two different files
**Decision:** Register MCP servers via `claude mcp add` (writes to `.claude.json`). Permissions for MCP tools go in `settings.json` (allow/deny rules). Two files, two purposes.
**Why:** Common confusion: putting server definitions in `settings.json` `mcpServers` block. `claude mcp add` handles auth, env vars (`-e KEY=VALUE`), and server lifecycle.

### D29: OS keychain for API keys, not env files
**Decision:** API keys stored in OS keychain (macOS: `security add-generic-password`), exported via shell profile. MCP subprocesses receive keys through `-e` flag at `claude mcp add`.
**Why:** Alternatives rejected: hardcoded in `settings.json` (git-tracked), `.env` files (plaintext on disk). Keychain is encrypted, OS-managed.

### D36: MCP model config persisted via env var override
**Decision:** Custom model configurations for MCP servers stored in dotfiles and loaded via environment variable.
**Why:** MCP servers installed via `uvx` keep config in ephemeral cache — overwritten on package update. Env var override points to a git-tracked file in dotfiles.

### D42: MCP env vars must go through `.claude.json`, not `settings.json`
**Decision:** Environment variables for MCP servers must be registered via `claude mcp add -e`, which writes to `.claude.json`. The `env` block in `settings.json` `mcpServers` is decorative — variables defined there do NOT reach the MCP process.
**Why:** Discovered when custom model configs weren't loading despite the env var being set in `settings.json`. The MCP process never received the variable. Root cause: Claude Code only passes env vars from `.claude.json` server definitions, not from `settings.json` mcpServers. Three session restarts to diagnose.
**Rule:** Always use `claude mcp add --scope user -e KEY=VALUE` for env vars. Never hand-edit `settings.json` mcpServers for server definitions.

## Data Pipelines

### D10: Per-day JSON files, not database
**Decision:** Calendar sync writes one JSON file per day, not a SQLite database or single large file.
**Why:** Simple to debug, natural unit (one day = one reflection). Claude reads individual files.

### D11: gws CLI over direct Google API
**Decision:** Calendar sync uses `gws` (Google Workspace CLI) instead of `google-api-python-client`.
**Why:** Auth handled transparently (encrypted keyring, auto-refresh). No credentials in env files.

### D12: Cloud storage for pipeline data, not git
**Decision:** Pipeline data stored in iCloud Drive (or cloud storage), not in the vault's git repo.
**Why:** Pipeline data is large, personal, and changes frequently. Git would bloat.

### D13: Symlinks into vault, not direct writes
**Decision:** Pipelines write to cloud storage; vault accesses via symlink (`_inputs/ServiceName/`).
**Why:** Separation of concerns. Changing cloud provider = update one symlink.

### D14: Three-layer cache (L1 → L2 → L3)
**Decision:** External data has three layers: cloud storage, vault symlink, session cache.
**Why:** Each layer serves a different purpose. L1 = durability + sync. L2 = vault access. L3 = fast session startup.

### D15: Work events as summary only (in personal vault)
**Decision:** Work calendar events synced as summary (count + hours + categories) to personal vault.
**Why:** Vault isolation. Work details belong in work context.

### D22: Single-writer model for cloud-synced folders
**Decision:** Only one process may create/rename folders in cloud-synced directories. Other processes use metadata files for display names.
**Why:** Cloud storage is eventually consistent — multiple writers cause duplicate folders. Discovery: renaming 92 folders while sync was running created 92 duplicates.

### D23: Status field is canonical source of truth
**Decision:** Pipeline processing status tracked in a dedicated `status:` field, not inferred from timestamps.
**Why:** Timestamps can be set during partial processing. Discovered when 58 records had `processed_at:` filled but were not actually processed.

### D37: Pending-transcript status for incomplete syncs
**Decision:** When a sync API returns file metadata but content isn't ready yet, mark as `pending-transcript` instead of `synced`.
**Why:** Previous behavior permanently skipped unfinished records. Separate status enables auto-retry.

### D38: Auto-extract at sync via lightweight model
**Decision:** Generate a lightweight metadata card from raw content at sync time using a fast/cheap model. Interactive extraction with full context happens separately.
**Why:** Eliminates the "synced but unprocessed" backlog. Opt-in flag, fails silently if model unavailable.

### D39: Resolve symlinks and guard data_dir in pipeline scripts
**Decision:** Pipeline scripts must `Path.resolve()` (follow symlinks) and verify the resolved path ends with the expected directory name.
**Why:** When vault symlinks point to a subdirectory of the data dir, the script nests directories recursively. A guard catches this immediately. Real incident: 76 levels of nesting, 6481 duplicate files from a single wrong symlink target.

## Automation & Multi-Machine

### D16: flock + jitter for cron jobs
**Decision:** Every cron job uses `flock` (prevent concurrent runs) and random jitter.
**Why:** Prevents overlapping runs and API rate limiting.

### D17: Claude headless for agent jobs
**Decision:** Automated reflections/audits run via `claude -p` (headless, non-interactive).
**Why:** Reads from local files, writes to vault. No MCP, no user prompts.

### D18: Always-on agent = separate runtime
**Decision:** Reactive agent (Telegram/webhook) is a separate runtime, not Claude Code.
**Why:** Different interaction model. Shared filesystem with vaults, but own config and security surface.

### D19: Cron = one-shot + two-stream logging
**Decision:** Execution logs go to `~/Library/Logs/claude/`. Results go to vault.
**Why:** Simple observability. Logs + exit code alerting.

### D20: Applet wrappers: `try/on error` mandatory
**Decision:** All AppleScript `.app` wrappers for launchd must use `try/on error`.
**Why:** `do shell script` raises an error on non-zero exit → applet hangs forever in headless LaunchAgent.

### D21: No Syncthing — iCloud + FDA is sufficient
**Decision:** Keep iCloud for data pipeline sync. No Syncthing.
**Why:** FDA for `.app` wrappers resolves TCC permission issues. Only voice recordings use iCloud (large files). Syncthing adds complexity without benefit.

### D30: Server cron jobs must not auto-commit
**Decision:** Background/cron jobs on the server must not run `git commit`. Only the primary machine commits.
**Why:** Auto-commit on server caused divergence with laptop's `git pull --ff-only`. Obsidian Sync is content source of truth; git is async archive with one writer.

## Knowledge & Reference Management

### D31: Knowledge Store = separate vault, not `_inputs/` extension
**Decision:** External sources get their own Obsidian vault, not a folder inside an existing vault.
**Why:** External knowledge needs: own CLAUDE.md, own commands, own git history, QMD collection. Full framework: [knowledge-store.md](knowledge-store.md).

### D32: No Atoms tier — Key Ideas embedded in extract files
**Decision:** AI-extracted Key Ideas live inside extract files, not as separate atomic note files.
**Why:** Zettelkasten atoms are valuable when a **human** writes them — the act of writing IS the understanding. AI creates mechanical derivatives. When an idea matures across 3+ sources, the human writes a Synthesis note.

### D33: Federated search, not symlinks, for cross-vault knowledge
**Decision:** Knowledge stores connect through search at query time, not filesystem symlinks.
**Why:** Symlinks break on mobile, corrupt backups, create tight coupling. QMD's `collection` parameter supports per-collection queries with zero coupling.

### D34: Visibility = sharing intent, not security boundary
**Decision:** The `visibility` field (`public|personal|company|private`) is a tag for future sharing decisions, not access control.
**Why:** All knowledge belongs to one person. Convention-based, not enforced.

### D35: Domains registry as cross-vault vocabulary
**Decision:** Open list of domain slugs bridging knowledge stores to vault areas.
**Why:** A source about "AI strategy" is relevant to both personal career and company transformation. Domain slugs bridge both contexts.
