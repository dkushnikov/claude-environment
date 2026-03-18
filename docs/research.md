# Research

Community patterns, tool evaluations, and future research items.

## Dotfiles Management

**Decision: bash script for now.** chezmoi is a mature tool (templating, secrets, multi-machine), but overkill for ~10 files on 2 machines. Go template syntax for a simple hostname check is overengineering. chezmoi copies files by default (doesn't symlink) — would fight the model.

**Migration trigger to chezmoi:** 3rd machine with a different role, or 25+ files, or need secrets from 1Password/Keychain.

GNU Stow also doesn't fit — no templating, and environment.md requires machine-specific content.

## Community Patterns

**Our approach = community consensus.** Dotfiles repo + symlinks is the most popular pattern. Examples: [brianlovin/agent-config](https://github.com/brianlovin/agent-config), [jarrodwatts/claude-code-config](https://github.com/jarrodwatts/claude-code-config).

**No official multi-machine sync from Anthropic.** Multiple open feature requests. Zero responses. All local state is per-machine by design.

**Purpose-built tools exist:** `daniel7an/dotclaude` (git sync), `toroleapinc/claude-brain` (semantic merge for memory), `miwidot/ccms` (rsync over SSH). Not needed yet — bash script is sufficient.

**CLAUDE.md best practice:** <200 lines per file. Skills for domain knowledge (loaded on demand), CLAUDE.md for broad rules (loaded always). Confirms the decision to keep global CLAUDE.md slim.

## Per-Project Plugins

**Works, but buggy.** `enabledPlugins` is supported in `.claude/settings.json` at project level. Project `false` overrides global `true`.

**Known bugs:**
- `enabledPlugins` only in `settings.local.json` (without `settings.json`) — silently ignored. Workaround: key must also exist in global settings
- `false` doesn't fully disable plugin, MCP server may continue loading
- Project-scoped plugins "leak" into other projects' UI

**Practical impact:** Can do per-project plugin profiles, but don't rely on them for security. For coding projects: `.claude/settings.json` with `enabledPlugins` disabling irrelevant plugins.

## Claude Desktop + Cowork

**Three separate products, zero shared config.**

| Aspect | Claude Desktop | Claude Code | Cowork |
|--------|---------------|-------------|--------|
| MCP config | `~/Library/Application Support/Claude/claude_desktop_config.json` | `~/.claude.json` + `.mcp.json` | claude.ai connectors (cloud) |
| Settings | GUI | `~/.claude/settings.json` | None |
| CLAUDE.md | Doesn't read | Walk-up hierarchy | Doesn't read |
| Execution | Native | Native | Isolated Linux VM |
| Sync | None | None (dotfiles repo) | Via claude.ai account |

**Bridges:**
- `claude mcp add-from-claude-desktop` — one-time import of MCP servers from Desktop to Code (not live sync)
- claude.ai MCP connectors — sync via account, visible in Code
- `claude mcp serve` — Code as MCP server for Desktop (reverse bridge)

## Future Research

### Multi-model routing

How to use different LLM models depending on task complexity. What opencode and openclaw solve: routing between providers (Anthropic, OpenAI, etc.), model selection per task type (cheap for simple, expensive for complex). Relevant for agent runtime and cost optimization at scale.

### Storage: files vs vector DB vs structured memory

Is working with files on disk sufficient, or do you need: vector database for document search/retrieval, structured object memory (mem0-like) for agents that need to store and query structured data. Relevant for company KB, agent memory, and scaling beyond vault files.

### Observability for AI agent execution

Monitoring, alerting, dashboards for scheduled and autonomous agent runs. What exists: Helicone, LangSmith, Braintrust, Arize Phoenix — all API-focused, not CLI. When does simple logging stop being enough. Relevant for cron jobs, always-on agents, company scale.

### Source tracking conventions for Company KB

From [VsevolodUstinov/ai-first-workspace-template](https://github.com/VsevolodUstinov/ai-first-workspace-template): `[CANONICAL]` / `[REF: source]` / `[PLACEHOLDER: owner]` tag system for traceable provenance. Every claim linked to its source, prevents hallucination and duplication across multi-department docs. Useful for high-stakes structured documents.

### Standalone agent pattern

From same repo: `agent.py` + `agent-prompt.md` + `agent-config.json` — minimal autonomous agent. Simple, portable pattern for task-specific agents. Lightweight alternative to full agent runtimes for single-purpose use.

## Sources

- [brianlovin/agent-config](https://github.com/brianlovin/agent-config)
- [jarrodwatts/claude-code-config](https://github.com/jarrodwatts/claude-code-config)
- [Arun's Blog — Sync Claude Code with chezmoi and Age](https://www.arun.blog/sync-claude-code-with-chezmoi-and-age/)
- [Nick Babich — CLAUDE.md Best Practices](https://uxplanet.org/claude-md-best-practices-1ef4f861ce7c)
- [Best Practices — Claude Code Docs](https://code.claude.com/docs/en/best-practices)
