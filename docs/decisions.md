# Decisions

Key design decisions with rationale. Reference when you're making similar choices.

## Architecture

### D1: Dotfiles via symlinks, not copy
**Decision:** `~/.claude/` contains symlinks to dotfiles repo, not copies.
**Why:** Single source of truth. Edit in one place, reflected everywhere. Avoids CVE risks from full directory sync, iCloud eviction, and JSONL corruption on concurrent writes.
**Trade-off:** If the repo is moved/deleted, symlinks break. Mitigated by `check.sh`.

### D2: Memory is local per machine
**Decision:** Each machine builds its own memory cache. Shared context lives in vault files (synced via Obsidian Sync or cloud storage), not in Claude's memory.
**Why:** Different machines run different tasks (interactive vs automation). They build different context. Memory should reflect the machine's role.

### D3: `--add-dir` for cross-project context
**Decision:** Use Claude Code's `--add-dir` for cross-vault or cross-project work, not symlinks or copying.
**Why:** Official mechanism. No CVE risks. Doesn't break git context. Skills load correctly from added dirs.

### D4: Universal skills global, domain skills in projects
**Decision:** Only universal skills (web scraping, transcription) in `~/.claude/skills/`. Domain skills (Obsidian formatting, vault audit) stay in each project's `.claude/skills/`.
**Why:** Domain skills in the wrong project waste context and add noise. ~40% of context was irrelevant in cross-domain use. Duplication across projects of the same domain is manageable.

### D5: Content sync via Obsidian Sync, git for backup
**Decision:** Real-time content sync via Obsidian Sync (or equivalent). Git for version history and backup, not sync.
**Why:** Sync is real-time to all devices. Git auto-commit conflicts with Sync on timing.

### D6: Global CLAUDE.md = identity only
**Decision:** Global CLAUDE.md contains who you are, communication style, preferences. Domain conventions moved to domain-level CLAUDE.md.
**Why:** In a coding project, Obsidian conventions are noise — roughly 40% of the global file was irrelevant content.

### D7: Permission templates by project type
**Decision:** Templates for `settings.local.json` per project type (Obsidian vault, coding project, etc.).
**Why:** Different project types need different permissions. Obsidian vaults need health tracker MCP; coding projects need npm/docker.

### D8: Bash scripts, not chezmoi
**Decision:** Simple bash scripts for install/check, not a dotfile manager.
**Why:** With ~10 files and 2 machines, a simple bash script beats a templating engine. Migration trigger: 3+ machines or 25+ managed files.

### D9: Machine identity via environment.md
**Decision:** Each machine has a gitignored `environment.md` declaring its role (interactive vs background).
**Why:** Same dotfiles repo, different behavior per machine. No conditional logic in shared config.

## Data Pipelines

### D10: Per-day JSON files, not database
**Decision:** Calendar sync writes one JSON file per day, not a SQLite database or single large file.
**Why:** Simple to debug, simple to sync, natural unit (one day = one reflection). Claude reads individual files without loading everything.

### D11: gws CLI over direct Google API
**Decision:** Calendar sync uses `gws` (Google Workspace CLI) instead of `google-api-python-client`.
**Why:** Auth handled transparently (encrypted keyring, auto-refresh). No credentials in env files. No pip dependencies.

### D12: Cloud storage for pipeline data, not git
**Decision:** Pipeline data stored in iCloud Drive (or Dropbox), not in the vault's git repo.
**Why:** Pipeline data is large, personal, and changes frequently. Git would bloat. Cloud storage syncs automatically.

### D13: Symlinks into vault, not direct writes
**Decision:** Pipelines write to cloud storage; vault accesses via symlink (`_inputs/ServiceName/`).
**Why:** Separation of concerns. Changing cloud provider = update one symlink.

### D14: Three-layer cache (L1 → L2 → L3)
**Decision:** External data has three layers: cloud storage, vault symlink, session cache.
**Why:** Each layer serves a different purpose. L1 = durability + sync. L2 = vault access. L3 = fast session startup. MCP = fallback.

### D15: Work events as summary only (in personal vault)
**Decision:** Work calendar events synced as summary (count + hours + categories) to personal vault. Full details to work vault.
**Why:** Vault isolation. Work details belong in work context.

## Automation

### D16: flock + jitter for cron jobs
**Decision:** Every cron job uses `flock` (prevent concurrent runs) and random jitter.
**Why:** Prevents overlapping runs and API rate limiting.

### D17: Claude headless for agent jobs
**Decision:** Automated reflections/audits run via `claude -p` (headless, non-interactive).
**Why:** Reads from local files (L2), writes to vault. No MCP, no user prompts.

### D18: Always-on agent = separate runtime
**Decision:** Reactive agent (Telegram/webhook) is a separate runtime, not Claude Code.
**Why:** Different interaction model. Shared filesystem with vaults, but own config and security surface.

### D19: Cron = one-shot + two-stream logging
**Decision:** Execution logs go to `/var/log/claude/`. Results go to vault.
**Why:** Simple observability. Logs + exit code alerting.

### D20: Applet wrappers: `try/on error` mandatory
**Decision:** All AppleScript `.app` wrappers for launchd must use `try/on error`.
**Why:** `do shell script` raises an error on non-zero exit → applet hangs forever in headless LaunchAgent (error dialog with no UI). The `try/on error` pattern catches failures gracefully.

### D21: No Syncthing — iCloud + FDA is sufficient
**Decision:** Keep iCloud for data pipeline sync. No Syncthing.
**Why:** FDA (Full Disk Access) for `.app` wrappers resolves TCC permission issues. Calendar/Health write to local `_inputs/` (not iCloud). Only voice recordings use iCloud (large audio files). Syncthing adds complexity without benefit.

### D22: Single-writer model for cloud-synced folders
**Decision:** Only one process may create/rename folders in cloud-synced directories (iCloud, Dropbox, etc.). Other processes use metadata files for display names.
**Why:** Cloud storage is eventually consistent — multiple writers cause duplicate folders. Discovery: renaming 92 folders via Claude while iCloud sync was running created 92 duplicates. Fix: designate a single sync script as folder owner, use metadata (e.g., `extract.md` title) for display.

### D23: Status field is canonical source of truth
**Decision:** Pipeline processing status is tracked in a dedicated `status:` field, not inferred from timestamps like `processed_at:`.
**Why:** Timestamps can be set during partial processing. `status:` explicitly represents the processing state. Discovered when 58 records had `processed_at:` filled but were not actually processed.

### D24: Permission split — generic global, project-specific local
**Decision:** Global `settings.json` covers CLI, git, system tools, package managers, MCP read-only. Local `settings.local.json` covers project-specific paths, domain commands, specialized WebFetch domains.
**Why:** Reduces noise in templates. Global rules apply everywhere, local rules are project-specific. Allow rules merge across levels (not replaced). Deny from any level wins.

### D25: Shell heuristic override via PreToolUse hook
**Decision:** Use a PreToolUse hook to bypass shell safety heuristics for known-safe commands. Conservative whitelist of ~80 commands. Deny: pipe to `sh`/`bash`, `eval`.
**Why:** 23 shell safety checks are hardcoded in the Claude Code binary and cannot be disabled via settings ([#30435](https://github.com/anthropics/claude-code/issues/30435), [#34106](https://github.com/anthropics/claude-code/issues/34106)). A PreToolUse hook returning `permissionDecision: "allow"` is the only override mechanism. Alternative rejected: `--dangerously-skip-permissions` (too broad, designed for containers).
**Trade-off:** Hook adds ~50ms per Bash command. Acceptable for interactive sessions.

### D26: `Bash(cmd *)` with space, not `Bash(cmd:*)`
**Decision:** All permission patterns use space syntax: `Bash(command *)`.
**Why:** The legacy `Bash(command:*)` syntax is deprecated and doesn't match compound commands (e.g., `ls ~/Library/...` won't match `Bash(ls:*)`). `Bash(command*)` without space matches both `command` and `commandSuffix` — use space to avoid false positives.

### D27: Separate architecture docs from behavioral rules
**Decision:** System architecture, storage models, and infrastructure belong in architecture/design docs. Protocols keep only behavioral rules (how Claude should act).
**Why:** Protocols grew into mixed system design + behavioral rules. Splitting makes each document focused: architecture for understanding the system, protocol for following it.

### D28: MCP server registration vs permissions — two different files
**Decision:** Register MCP servers via `claude mcp add` (writes to `.claude.json`). Permissions for MCP tools go in `settings.json` (allow/deny rules). Two files, two purposes.
**Why:** Common confusion: putting server definitions in `settings.json` `mcpServers` block. That works but mixes concerns. `claude mcp add` handles auth, env vars (`-e KEY=VALUE`), and server lifecycle. `settings.json` handles what tools are auto-approved.

### D29: OS keychain for API keys, not env files
**Decision:** API keys stored in OS keychain (macOS: `security add-generic-password`), exported via shell profile. MCP subprocesses receive keys through `-e` flag at `claude mcp add`.
**Why:** Alternatives rejected: hardcoded in `settings.json` (git-tracked), `.env` files (plaintext on disk), `.secrets` file (same problem as `.env`). Keychain is encrypted, OS-managed, and doesn't require manual file protection.

### D30: Server cron jobs must not auto-commit
**Decision:** Background/cron jobs on the server must not run `git commit`. Only the primary machine commits (single-committer model from D17).
**Why:** A vault audit cron job was auto-committing on the server. This caused divergence — the laptop's `git pull --ff-only` started failing because the server had commits that didn't exist on the laptop. Fix: removed commit step from all server job prompts. Obsidian Sync is the content source of truth; git is async archive with one writer.

## Knowledge & Reference Management

### D31: Knowledge Store = separate vault, not `_inputs/` extension
**Decision:** External sources (articles, books, ideas) get their own Obsidian vault, not a folder inside an existing vault.
**Why:** External knowledge needs: own CLAUDE.md (identity), own commands, own git history, QMD collection, standalone sessions. `_inputs/` = transient pipeline data (gitignored). Shared = coordination bridge. Knowledge Store = permanent reference layer. Full framework: [knowledge-store.md](knowledge-store.md).

### D32: No Atoms tier — Key Ideas embedded in extract files
**Decision:** AI-extracted Key Ideas live inside extract files, not as separate atomic note files.
**Why:** Zettelkasten atomic notes are valuable when a **human** writes them — the act of writing IS the understanding. When AI creates atoms, they become mechanical derivatives: many, contextless, orphaned quickly. Key Ideas in extract.md serve the same function (identify what's important) without creating maintenance burden. When an idea matures across 3+ sources, the human writes a Synthesis note — that's where understanding happens.

### D33: Federated QMD search, not symlinks, for cross-vault knowledge
**Decision:** Knowledge stores connect through QMD search at query time, not filesystem symlinks.
**Why:** Symlinks break on mobile Obsidian (iOS/Android don't support them), corrupt backups, create tight coupling. QMD's `collection` parameter already supports per-collection queries. Adding a new knowledge store = one command (`qmd collection add`), zero impact on existing stores. Each store remains fully independent.

### D34: Visibility = sharing intent, not security boundary
**Decision:** The `visibility` field in knowledge extracts (`public|personal|company|private`) is a tag for future sharing decisions, not an access control mechanism.
**Why:** All knowledge belongs to one person — there's no multi-user access control problem to solve. Visibility marks what *could* be shared if you wanted to: publish publicly, keep personal, or share with a work context. Convention-based, not enforced.

### D35: Domains registry as cross-vault vocabulary
**Decision:** Open list of domain slugs bridging knowledge stores to vault areas. Personal domains (no prefix), work domains (`org/` prefix).
**Why:** A source about "AI strategy" is relevant to both personal career growth and company AI transformation. `domains: [career, org/ai]` bridges both contexts. Slugs map to vault areas but aren't coupled to folder names. New domains added as needed, documented in protocol.

### D36: MCP model config persisted via env var override
**Decision:** Custom model configurations for MCP servers (like PAL) stored in dotfiles and loaded via environment variable (`OPENROUTER_MODELS_CONFIG_PATH`).
**Why:** MCP servers installed via `uvx` keep config in ephemeral cache — overwritten on package update. Env var override points to a git-tracked file in dotfiles. Survives updates, deploys to other machines via dotfiles sync.

## Data Pipeline Hardening

### D37: Pending-transcript status for incomplete syncs
**Decision:** When a sync API returns file metadata but content isn't ready yet, mark as `pending-transcript` instead of `synced`.
**Why:** Previous behavior marked records as "synced" despite no content → permanently skipped on subsequent runs. Separate status enables auto-retry on next sync cycle without manual intervention.

### D38: Auto-extract at sync via lightweight model
**Decision:** Generate a lightweight metadata card (title, summary, people, topics) from raw content at sync time using a fast/cheap model. Interactive extraction with full context (calendar, people profiles) happens separately.
**Why:** Eliminates the "synced but unprocessed" backlog. Quick metadata enables search and triage without waiting for a human session. Opt-in flag (`--auto-extract`), fails silently if model unavailable.
