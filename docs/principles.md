# Principles

Design decisions that guided this framework. Not rules — context for your own choices.

## 1. Templates, not opinions
Customize everything. The framework provides structure and patterns, not a locked-in way of working. Every file is meant to be edited.

## 2. Secrets are local
API tokens, OAuth credentials, `.env` files — only on the specific machine. Zero secrets in git. Each machine manages its own auth. `*.env` is always gitignored.

## 3. Sync via cloud, not git
Pipeline data (calendar JSON, voice transcripts, health metrics) syncs via iCloud/Dropbox/Syncthing. Git is for config and code only. This keeps the repo small and avoids committing personal data.

## 4. Idempotent scripts
`install.sh` and `check.sh` can run repeatedly without side effects. They detect current state before acting. No "run this only once" scripts.

## 5. Simplicity over frameworks
Bash over chezmoi. JSON files over databases. Symlinks over file copies. Python over Node for scripts (stdlib-rich, no build step). If bash can do it, don't add a dependency.

## 6. Progressive complexity
Start with dotfiles only (5 minutes). Add a pipeline when you need external data. Add cron when manual sync gets annoying. Add a second machine when you want automation. Each layer is optional.

## 7. One source of truth per layer
Don't duplicate config. Symlink instead. Calendar IDs live in `config.json` (L1), not in Claude rules, not in the vault, not in a spreadsheet.

## 8. Machine knows its role
Each machine has `environment.md` that declares: am I interactive (human present) or background (cron, headless)? Claude adjusts behavior accordingly. No "detect if we're in a terminal" heuristics.

## 9. Data pipelines decouple sync from usage
Sync runs on a schedule (every N minutes). Claude reads from local files whenever it needs data. These are independent — a slow API doesn't block a session, a stale cache degrades gracefully.

## 10. Graceful degradation
If L1 is stale → use L2 cache. If L2 is empty → fall back to MCP. If MCP is unavailable → tell the user. Never silently fail, never block on a missing data source.
