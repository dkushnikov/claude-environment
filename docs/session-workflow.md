# Session Workflow

A universal pattern for stateful Claude Code sessions — applicable to Obsidian vaults, coding projects, or any long-running collaboration.

## The Problem

Each Claude Code session starts fresh. Without persistent state, session 38 feels like session 1. The agent doesn't know your goals, open questions, or what you decided last time.

## The Pattern

Three files create continuity between sessions:

```
project/
├── CLAUDE.md         ← what the agent needs to know (walk-up chain)
├── _claude/
│   ├── TODO.md       ← open tasks, cross-session tracker
│   └── session-logs/ ← one file per session: what happened, decisions, next steps
└── .claude/
    └── projects/.../memory/
        └── MEMORY.md  ← agent's long-term memory (auto-managed by Claude Code)
```

### CLAUDE.md — Working Context

The walk-up chain (`~/.claude/CLAUDE.md` → project `CLAUDE.md`) gives the agent persistent context. Key sections:

- **Who you are** — role, communication style, preferences (Layer 1, global)
- **Project conventions** — how this project works (Layer 2+, per-project)
- **Session protocol** — what to do at session start/end

Claude Code reads ALL `CLAUDE.md` files from CWD up to `~`, composing them into a single context. This is the "walk-up chain."

### TODO.md — Cross-Session Tasks

A simple markdown file tracking what's open. Claude checks it at session start, updates during work.

```markdown
## Waiting for me
- [ ] Review the draft PR <!-- since: 2026-03-15 -->

## Waiting for Claude
- [ ] Update the migration script after review

## Deferred
- [ ] Refactor auth module (not urgent)
```

The `<!-- since: YYYY-MM-DD -->` markers enable deferral tracking — how long has this been sitting?

### Session Logs — What Happened

One file per session: plan, decisions, artifacts created, what's next.

```markdown
# 2026-03-18 — Feature X Implementation

## Plan
What we agreed to do.

## What was done
Key decisions, artifacts created.

## What's next
Open threads for the next session.
```

Session logs are append-only history. They answer "why did we do it this way?" months later.

### MEMORY.md — Agent's Long-Term Memory

Claude Code's auto-memory system. Stores observations about you, your preferences, project patterns. Updated automatically across sessions.

Categories: `user` (who you are), `feedback` (how to behave), `project` (what's happening), `reference` (where to find things).

## Session Start Protocol

At the beginning of each session, the agent should:

1. Read TODO.md — what's open, what's stale
2. Read latest session log — where we left off
3. Check for incoming messages (cross-project, if applicable)
4. Show a brief status and ask what's next

This can be automated via a `SessionStart` hook:

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "cat _claude/TODO.md 2>/dev/null | head -20"
      }]
    }]
  }
}
```

Or more sophisticated: a shell script that composes a briefing from cached data.

## Session End Protocol

Before ending:

1. Update session log — finalize "what was done" and "what's next"
2. Update TODO.md — close completed items, add new ones
3. Commit changes

## Session Management Architecture

For projects with complex session needs (multiple domains, knowledge propagation, cross-project sync), the basic start/end protocol can be split into three files:

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

**Key insight:** Session log mechanics (format, naming, cross-project updates) are the same everywhere — they live in shared dotfiles. But what happens at start (context loading, data sources) and end (which checklists, what to verify) varies per project — those stay project-specific.

Projects without an offboarding rule use `session-log.md` standalone — it works both as a standalone rule (triggered by session-end keywords) and as a delegated step within the offboarding orchestrator.

### Offboarding Phases

**Phase 1 — Domain checklists:** Identify which domains were touched in the session and run their specific checklists (e.g., infrastructure → deploy check, data pipelines → index update).

**Phase 2 — Universal checklist:** Every session: update TODO.md, refresh memory, update index files, record decisions.

**Phase 3 — Session log (shared):** Finalize the log, rename the session, send cross-project messages if insights are relevant to other projects.

**Phase 4 — Verify:** All artifacts from the log exist, no deferred updates, documentation is consistent with changes.

### Session Commands

Two optional commands complement the architecture:

- **`/wrap-up`** — triggers the full offboarding protocol. Executes all 4 phases without asking permission for each step.
- **`/session-status`** — shows current state: what's done, what's pending, offboarding readiness. Useful mid-session or before wrapping up.

## Scaling

This pattern works at any scale:

- **Solo coding project:** TODO.md + session logs are enough
- **Obsidian vault:** add health data, calendar, daily reflections
- **Team project:** each person has their CLAUDE.md layer; shared TODO.md

The key insight: **persistent state turns an AI assistant into a collaborator.** Session 38 builds on sessions 1-37.
