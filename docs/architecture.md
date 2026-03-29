# Architecture

The layered model for running Claude Code across machines, vaults, and projects.

## Layered Model

The model is tool-agnostic. Obsidian is one domain tool, not the center. The architecture works for any project type and scales to organization use.

```
Layer 1: Person (~/.claude/)
  Who I am, style, universal preferences. Zero domain-specifics.
  PORTABLE — goes with the person, not the role or company.
  Source: ~/dotfiles-claude/ (git repo), symlinks into ~/.claude/
  Sync: git push/pull

Layer 2+: Walk-up chain (as many levels as directory nesting)
  Domain/department/organization rules. Each CLAUDE.md adds context.
  The number of intermediate layers is flexible:

  Personal use:
    ~/Obsidian/CLAUDE.md              — domain (Obsidian conventions)
    ~/Obsidian/Personal/CLAUDE.md     — project (vault rules)

  Company use:
    ~/Company/CLAUDE.md               — organization (company conventions)
    ~/Company/Engineering/CLAUDE.md   — department (coding standards)
    ~/Company/Engineering/backend/CLAUDE.md — project

Bottom layer: Project (CLAUDE.md + .claude/)
  Protocols, permissions, project-only skills.
  Sync: depends on context (Obsidian Sync / Git / company tool)
```

**Key property:** Claude Code searches for CLAUDE.md upward from CWD to `~`. This is a built-in mechanism — walk-up = automatic layer composition. No limit on nesting depth.

**Limitation:** Skills and settings do NOT work via walk-up. Skills load only from `~/.claude/skills/` (global) and `<project>/.claude/skills/` (project-level). Intermediate levels are not scanned. Department/domain skills must be placed in each project's `.claude/skills/`.

### Knowledge Store — cross-vault reference layer

A new layer for external knowledge (articles, books, ideas) that serves all vaults via federated QMD search. Not inside any vault — a standalone vault with its own CLAUDE.md, git, and QMD collection.

```
Layer 1: Person (~/.claude/)          ← who I am
Layer 2: Walk-up (vaults, projects)   ← what I work on
Layer 3: Knowledge Store              ← what I learn from
  Role: PARA "Resources" — external knowledge
  Access: QMD collection (query-time federation)
  Principle: AI does filing, human does understanding
```

This separates what you **create** (vault content) from what you **consume** (external sources). Full framework: [knowledge-store.md](knowledge-store.md). Decisions: D31-D36.

## Identity & Portability

The architecture separates **person** (portable) from **role** (contextual).

| | Person (portable) | Role (contextual) |
|---|---|---|
| **Config** | Layer 1: identity, style, principles | Layer 2+: domain/org/project rules |
| **Skills** | Universal (web scraping, transcription) | Domain/project (obsidian-*, vault-audit) |
| **Integrations** | Personal (health tracker, personal calendar) | Company (Slack, Notion, company Google) |
| **Knowledge** | Personal vault, coaching, goals | Company vault, company data |
| **Memory** | Patterns, preferences | Company-specific context |

### Three Persistence Layers

Each project can have three distinct layers of Claude context, each serving a different purpose:

| Layer | What it stores | Mechanism | Auto-loaded? |
|-------|---------------|-----------|-------------|
| **Instructions** | How to behave — rules, protocols, permissions | CLAUDE.md + `.claude/rules/*.md` | Yes |
| **Facts** | What Claude knows — people, decisions, project state | `memory/` directory + MEMORY.md index | Yes (index) |
| **Identity (Soul)** | Who Claude is — values, relationship with human, limitations | `.claude/rules/soul.md` | Yes |

Instructions change per-project. Facts accumulate over time. Identity persists across sessions and defines the collaboration style.

The soul document is NOT instructions (those are in CLAUDE.md) and NOT facts (those are in memory/) — it's the layer that gives continuity of self between sessions. It answers: who am I in this project, what do I value, how do I relate to this human?

Pattern: the soul document lives in the project's identity layer (e.g., `_meta/Claude Soul.md` in an Obsidian vault) with a symlink in `.claude/rules/` for auto-loading. This gives both project graph connectivity and Claude Code auto-load.

**Transitions:**
- Leave company → Layer 1 goes with person. Layers 2+ stay.
- Change department → Layer 1 + org layer stable. Department layer changes.
- New employee → brings their Layer 1. Company provides Layers 2+.

### Session Management

Three rules govern the session lifecycle. Shared mechanics live in dotfiles, project-specific behavior in project rules.

```
START                          END
session-onboarding.md    →     session-offboarding.md (orchestrator)
(project rule)                   Phase 1: Domain checklists
  Phase 1: Context load          Phase 2: Universal checklist (TODO, memory, indexes)
  Phase 2: Briefing              Phase 3: → session-log.md (shared)
  Phase 3: Session setup                    log, rename, cross-project
                                 Phase 4: Verify
```

| File | Location | Scope | Owns |
|------|----------|-------|------|
| `session-onboarding.md` | Project `.claude/rules/` | Project-specific | Context load, briefing, session setup |
| `session-log.md` | Dotfiles `rules/` | Shared (all projects) | Log format, rename, cross-project messages |
| `session-offboarding.md` | Project `.claude/rules/` | Project-specific | Knowledge propagation, verification |

Projects without an offboarding rule use `session-log.md` standalone. See [session-workflow.md](session-workflow.md#session-management-architecture) for details on each phase.

### Company scaling

For organization-wide rollout:

| Layer | Provided by | Contains |
|---|---|---|
| Person | Employee (own dotfiles) | Identity, style, universal skills |
| Organization | Company repo | Communication norms, security rules, shared MCP (Slack, Notion) |
| Department | Department repo/dir | Domain skills, integrations, conventions, permission templates |
| Project | Project repo | Specific rules, protocols, project skills |

**What's uniform (organization level):** communication style, security policy, tooling conventions (git, Slack), company-wide MCP connectors.

**What varies (department level):**

| Department | Skills focus | Key integrations |
|---|---|---|
| Engineering | Code review, testing, CI/CD, debug | GitHub, CI, monitoring, DBs |
| Product & Design | Specs, research, competitive analysis | Figma, analytics, research tools |
| Operations | Processes, runbooks, vendor management | Notion, Slack, vendor portals |
| Marketing | Content, campaigns, SEO | Analytics, CMS, ad platforms |
| People (HR) | Recruiting, perf reviews, policy | ATS, HRIS, comp tools |
| Analytics | SQL, dashboards, data modeling | BI tools, data warehouse, dbt |
| CX & Support | Ticket analysis, KB, escalation | Zendesk/Intercom, product |
| Sales | Pipeline, outreach, proposals | CRM, email sequences |
| Finance | Financial analysis, budgeting | Accounting, payroll, banking |

## Sync Architecture

Multi-device sync uses three non-competing layers. Full details in [multi-machine/](../multi-machine/README.md#sync-architecture).

| Layer | Mechanism | Speed | Who writes |
|-------|-----------|-------|------------|
| Vault content | Obsidian Sync | Seconds | All devices |
| Version history | Git | Hours/days | Laptop only (single committer) |
| Data pipelines | iCloud / local files | Minutes | Cron jobs |

Key decisions:
- **D17:** Single git committer — laptop commits, server `pull --ff-only`. Zero merge conflicts
- **D18:** Obsidian app on server as LaunchAgent — enables Sync + CLI
- **D19:** Telegram bot (persistent Claude session) for mobile access
- **D20:** Applet wrappers must use `try/on error` — see [jobs/](../jobs/README.md#macos-icloud-drive-and-tcc)
- **D21:** No Syncthing — iCloud + FDA covers data pipeline sync needs

## Configurations

Jobs map to configurations. Each config = a CWD + layers combination.

| Config | CWD / Runtime | Layers | Example jobs |
|--------|---------------|--------|------|
| **Obsidian vault** | `~/Obsidian/<vault>/` | 1+2+3 | Vault content, reflections, data integration |
| **Cross-vault** | `~/Obsidian/` | 1+2 | Weekly reviews, cross-vault search |
| **Infrastructure** | `~/dotfiles-claude/` | 1 | Dotfiles, permissions, server admin |
| **Coding / product** | `~/Projects/<name>/` | 1+2+3 | Code, scripts, tools |
| **Server (CLI)** | vault on server | same | Cron, SSH sessions |
| **Agent runtime** | daemon | own config | Always-on agent (Telegram, webhooks) |
| **Mobile pipeline** | iPhone → server → vault | capture + processing | Voice/dictation capture |
| **Browser automation** | Chrome CDP :9222 | Playwright / Claude | Scraping, monitoring, forms |

## Device Roles

### Laptop — interactive work

Primary machine. Runs all interactive sessions: vault content, coding, coaching, data integration, cross-vault work. Also the only machine with access to the private vault.

### Server — background + automation

Always-on machine. Runs cron jobs (reflections, audits, data sync), SSH sessions from iPad, always-on agent, mobile capture processing, browser automation. No private vault access.

### iPad — remote access

SSH into server for quick edits and reviews.

### iPhone — capture

Voice/dictation on the go → server → vault.

## Tool Ecosystem

Claude Code is the primary orchestrator. Other tools complement it:

- **Cursor** — coding projects, company KB work
- **Obsidian** — GUI for personal knowledge (vaults)

Principles:
1. **Claude Code = foundation.** The layered model, dotfiles repo, install.sh — all built on Claude Code mechanisms
2. **Don't build for tool portability.** But use portable standards where free: CLAUDE.md, SKILL.md, `.mcp.json`
3. **Each tool owns its config space.** Don't unify `.cursorrules` with `.claude/settings.json`
4. **Code/projects = multi-tool.** Directory layout must not assume a single tool

## Skills Categorization

| Level | Location | What | Loaded when |
|-------|----------|------|-------------|
| Global | `~/.claude/skills/` (from dotfiles repo) | Universal, useful in any project | Description at start (~100 tokens), full SKILL.md on-demand |
| Domain | `<project>/.claude/skills/` | Domain-specific (Obsidian, coding) | Same — on-demand when relevant |
| Project | `<project>/.claude/skills/` | This project only | Same — on-demand when relevant |

**Trade-off:** Domain skills are duplicated across projects of the same type. Deliberate choice — duplicates are manageable, clean context in cross-domain projects matters more.

## Environment Detection

Machine-specific context lives in `~/.claude/rules/environment.md`. Auto-loaded by Claude Code at session start. NOT in git — created by `install.sh` from a template.

```markdown
# Environment: Laptop
- machine: laptop
- hostname: my-laptop
- role: interactive — primary work machine
- hardware: MacBook Pro, 48 GB
- services: Obsidian GUI, iCloud Drive
- vaults: Personal, Work, Private, Shared
```

```markdown
# Environment: Server
- machine: server
- hostname: my-server
- role: background — cron, SSH, automation
- hardware: MacBook Pro, 16 GB
- services: Chrome CDP :9222, cron, tmux
- tailscale: 100.x.x.x
- vaults: Personal, Work, Shared (NO Private)
```

## Extensibility

### New Obsidian vault

1. Obsidian Sync pulls content automatically
2. Install domain skills → `.claude/skills/`
3. Create `.claude/settings.local.json` from template
4. Create CLAUDE.md (vault-specific rules)
5. Domain CLAUDE.md already works via walk-up

### New coding project

1. `mkdir ~/Projects/<name>/ && cd ~/Projects/<name>/`
2. Domain CLAUDE.md (`~/Projects/CLAUDE.md`) — coding conventions
3. `git init`, create CLAUDE.md with project description
4. `.claude/settings.local.json` from coding template
5. Project-specific skills in `.claude/skills/` as needed

### New machine

1. `git clone <your-repo>/dotfiles-claude ~/dotfiles-claude/`
2. `cd ~/dotfiles-claude/ && ./install.sh`
3. Fill in `~/.claude/rules/environment.md` — hostname, role, hardware, vaults
4. `./check.sh` — validation
5. For Obsidian vaults: install domain skills

### New domain (not Obsidian, not coding)

1. Create root directory: `~/NewDomain/`
2. Create `~/NewDomain/CLAUDE.md` — domain conventions (Layer 2)
3. Projects inside: `~/NewDomain/<project>/CLAUDE.md` (Layer 3)
4. Domain-specific skills → `<project>/.claude/skills/`
5. Permissions template → `~/dotfiles-claude/templates/settings.local.<domain>.json`
