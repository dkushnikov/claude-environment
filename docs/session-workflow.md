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

## Scaling

This pattern works at any scale:

- **Solo coding project:** TODO.md + session logs are enough
- **Obsidian vault:** add health data, calendar, daily reflections
- **Team project:** each person has their CLAUDE.md layer; shared TODO.md

The key insight: **persistent state turns an AI assistant into a collaborator.** Session 38 builds on sessions 1-37.
