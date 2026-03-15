# Environment Setup Framework — Agent Reference

Technical reference for an AI coding agent implementing a unified Claude Code environment across multiple machines, with identity/role separation and organizational scaling.

## 1. What This Is

A framework for configuring Claude Code so that:

- Launching Claude Code on any machine yields the same identity, style, and universal skills.
- Each machine knows its role (interactive vs background) and adjusts behavior.
- Secrets never leave the machine. Sensitive vaults never leave the primary device.
- A new machine is set up in 5 minutes: `git clone + install.sh + fill in environment.md`.
- A validation script (`check.sh`) confirms everything is in place.

The framework is built on Claude Code's native mechanisms (walk-up CLAUDE.md, rules/, skills/) and requires no custom tooling. It is tool-agnostic in design — the layered model works for any AI coding agent that supports hierarchical config files.

## 2. Core Concepts

### 2.1 Layered Model

The architecture has three conceptual levels, but the number of physical layers is unlimited (determined by directory nesting).

```
Layer 1: Person (~/.claude/)
  Identity, communication style, universal preferences. ZERO domain content.
  Source: ~/Claude/ (dotfiles repo), symlinked into ~/.claude/
  Portable — goes with the person, not the company.

Layer 2+: Walk-up chain (any depth)
  Domain, organization, department rules. Each CLAUDE.md adds context.

  Example — personal use:
    ~/Obsidian/CLAUDE.md           — domain conventions (Obsidian-specific)
    ~/Obsidian/PersonalVault/CLAUDE.md — project (vault-specific rules)

  Example — company use:
    ~/CompanyName/CLAUDE.md               — organization conventions
    ~/CompanyName/Engineering/CLAUDE.md   — department standards
    ~/CompanyName/Engineering/api/CLAUDE.md — project rules

Bottom: Project (CLAUDE.md + .claude/)
  Protocols, permissions, project-only skills.
```

**Key architectural insight:** Claude Code searches for CLAUDE.md files upward from CWD to `~`, composing all files found. This is a built-in mechanism — no custom tooling needed. Walk-up = automatic layer composition.

**Critical limitation:** Skills and `settings.json` do NOT walk up. Skills load only from `~/.claude/skills/` (global) and `<project>/.claude/skills/` (project-level). Intermediate directory levels are not scanned for skills. Domain skills must be placed in each project's `.claude/skills/`.

### 2.2 Identity and Portability

The architecture separates **person** (portable) from **role** (contextual).

| Dimension | Person (portable) | Role (contextual) |
|-----------|-------------------|-------------------|
| Config | Layer 1: identity, style, principles | Layers 2+: org/domain/project rules |
| Skills | Universal (web scraping, transcription) | Domain/project (Obsidian formatting, vault audit) |
| Integrations | Personal (health tracker, personal calendar) | Company (Slack, Notion, company Google Workspace) |
| Knowledge | Personal notes, coaching, goals | Company data, NDA content |
| Memory | Patterns, preferences | Company-specific context |

**Overlap rule:** Generalized form is portable, specifics stay. "I learned to manage 200-person engineering orgs" is portable. "Company Q1 revenue was $X" stays with the role.

**Transitions:**

| Event | Layer 1 (Person) | Layer 2+ (Org/Dept/Project) |
|-------|-----------------|----------------------------|
| Leave company | Goes with you | Stays |
| Change department | Stable | Department layer changes |
| New employee joins | Brings their own | Company provides |

### 2.3 Environment Detection

Each machine has a file `~/.claude/rules/environment.md` that tells Claude Code where it is running. The `rules/` directory is auto-loaded at session start.

The file is **machine-specific**: NOT in git, NOT symlinked from the dotfiles repo. `install.sh` creates it from a template; the user fills in machine details.

### 2.4 Skills Categorization

| Level | Location | What | Loaded when |
|-------|----------|------|-------------|
| Global | `~/.claude/skills/` (from dotfiles repo) | Universal, useful in any project | Always |
| Domain | `<project>/.claude/skills/` | Domain-specific (e.g., Obsidian formatting) | Only in projects of that domain |
| Project | `<project>/.claude/skills/` | This project only (e.g., vault audit) | Only in this project |

Domain and project skills share the same physical location. The distinction is conceptual: domain skills are duplicated across all projects of that domain (from a single source repo), while project skills exist only in one project.

### 2.5 Context Isolation

Each project gets only relevant context through these mechanisms:

1. **Walk-up CLAUDE.md** — only ancestors of CWD contribute. Sibling domains don't leak.
2. **Skills** — only global + current project. No cross-project contamination.
3. **Permissions** (`settings.local.json`) — different per project type.
4. **Environment detection** — machine-specific behavior without conditional logic in shared config.
5. **`--add-dir`** — explicit opt-in for cross-project context.

## 3. Setup Pattern

### 3.1 Dotfiles Repo Structure

```
~/dotfiles-claude/                        (git repo)
├── CLAUDE.md                             → symlink ~/.claude/CLAUDE.md
├── rules/                                → symlink ~/.claude/rules/
│   └── (environment.md)                  ← NOT in git, machine-specific
├── settings.json                         → symlink ~/.claude/settings.json
├── skills/                               → symlink ~/.claude/skills/
├── templates/
│   ├── settings.local.obsidian.json
│   ├── settings.local.coding.json
│   └── environment.md.example
├── install.sh
├── check.sh
└── .gitignore                            ← environment.md, *.env
```

### 3.2 Adding New Things

**New machine:** `git clone` → `install.sh` → fill `environment.md` → `check.sh`.

**New domain:** Create directory with `CLAUDE.md` → projects inside inherit via walk-up.

**New project:** Create `CLAUDE.md` + copy permissions template + copy domain skills.

## 4. Key Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Dotfiles repo with symlinks, not full directory sync | CVE risks, iCloud eviction, JSONL corruption on concurrent writes |
| D2 | Memory is local per machine | Different tasks = different memory. Shared context in vault files |
| D3 | `--add-dir` for cross-project context | Official mechanism, no CVE risks |
| D4 | Universal skills global, domain skills in projects | Domain skills in wrong project = context waste + noise |
| D5 | Content sync via Obsidian Sync, git for backup | Real-time sync. Git conflicts with Sync on auto-commit |
| D6 | iPad/iPhone: data only, not env setup | Reduces complexity |
| D7 | Deny rules as guardrails | Not security boundaries, but practical safety |
| D8 | Global CLAUDE.md = identity only | Domain conventions at domain level. ~40% of global was noise in coding projects |
| D9 | Permission templates by project type | Different MCPs/tools per project type |
| D10 | Bash over chezmoi | Simple setup. Migration trigger: 3+ machines or 25+ files |
| D11 | Per-project plugin profiles | Works with caveats. Guardrail, not security |
| D12 | Always-on agent = separate runtime | Different interaction model. Shared filesystem, own config |
| D13 | Cron = `claude -p` one-shot + logging | Execution logs → log dir. Results → vault. Simple observability |
| D14 | MCP config not in dotfiles | Partially machine-specific. Manual for now |
| D15 | Periodic cleanup of settings.local.json | Auto-appended commands accumulate. Manual cleanup |
| D16 | Workspace dir separate from dotfiles repo | `~/Claude/` = workspace, `~/Claude/dotfiles/` = repo |

## 5. Data Pipelines

See [pipelines/README.md](../pipelines/README.md) for the three-layer data pipeline architecture and reference implementations.

## 6. Company Scaling

The same layered architecture scales from individual to organization:

| Layer | Provider | Contains |
|-------|----------|----------|
| Person | Employee (own dotfiles repo) | Identity, style, universal skills |
| Organization | Company repo | Communication norms, security policy, shared MCP |
| Department | Department directory/repo | Domain skills, standards, integrations |
| Project | Project repo | Specific rules, protocols, project skills |

Walk-up CLAUDE.md handles this naturally: `~/Company/Engineering/api/` composes Person + Organization + Department + Project layers automatically.

**What's uniform (organization level):** communication style, security policy, tooling conventions, company-wide MCP connectors.

**MCP connector layers:**

| Level | Scope | Who provides |
|-------|-------|-------------|
| Cloud (claude.ai account) | Company-wide: Slack, Notion, Google | Company IT |
| Global local (`~/.claude.json`) | Person-wide: personal tools | Employee |
| Project local (`.mcp.json`) | Project-specific: APIs, databases | Team lead |

## 7. Principles

1. **Context isolation.** Each project gets only relevant context.
2. **Secrets are local.** Zero secrets in git.
3. **Sensitive vaults — primary device only.** Not on server, not in sync.
4. **Evolvability.** New domains/machines/jobs addable without redesign.
5. **Simplicity.** Bash over frameworks. Files over databases.
6. **One source of truth per layer.** Don't duplicate — symlink.
7. **Idempotency.** Scripts run repeatedly without side effects.
8. **Memory is local.** Shared context in synced content files.
9. **Permissions are guardrails, not security boundaries.**
