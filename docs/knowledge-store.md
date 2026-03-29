# Knowledge Store

A framework for AI-assisted personal knowledge management. Separate Obsidian vault for external sources (articles, books, ideas, podcasts, videos), serving multiple vaults via federated QMD search.

**Core principle:** AI does filing, human does understanding.

## Why a Separate Vault

External knowledge needs its own home — not `_inputs/` (transient pipeline data), not Shared (cross-vault coordination), not inside any content vault. Knowledge Store is a **reference layer** that serves all vaults:

```
Layer 1: Person (~/.claude/)
Layer 2: Walk-up (vaults, projects)
Layer 3: Knowledge Store (~/Obsidian/Knowledge/)
  Cross-vault reference. PARA "Resources" — what you consume.
  Access: QMD federated search (collection parameter)
  Role: external knowledge that enriches any vault
```

Content vaults hold what you **create** (notes, reflections, decisions). Knowledge Store holds what you **consume** (articles, books, research).

## Architecture: Three Tiers of Thinking, Two Tiers of Files

| Tier | Nature | File | Created by |
|------|--------|------|------------|
| **Source** | Raw material, immutable | `Sources/{date}_{hash8}/source.md` | AI capture |
| **Extract** | Mechanical filing: summary, key ideas, tags | `Sources/{date}_{hash8}/extract.md` | AI extraction |
| **Synthesis** | Human understanding: connecting ideas across sources | `Synthesis/{topic-slug}.md` | Human only |

### Why No Atoms Tier

Classical Zettelkasten (Luhmann) and Evergreen Notes (Matuschak) use atomic notes — one idea per file. This works when a **human writes** them, because the act of writing IS the understanding.

When AI creates atomic notes, they become mechanical derivatives: many, contextless, orphaned. The understanding hasn't happened — you just have more files.

**Solution:** Key Ideas live embedded in `extract.md` (AI filing). When an idea grows significant enough across 3+ sources, the **human** writes a Synthesis note. The promotion from Key Idea to Synthesis IS the understanding.

```
Source (AI captures)  →  Extract (AI files)  →  Synthesis (HUMAN thinks)
     immutable              mechanical              understanding
```

This is kepano's "don't delegate understanding" principle, refined: **delegation is fine for filing. Understanding requires the human.**

## Federated Search via QMD

Knowledge stores connect through search, not symlinks:

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Knowledge    │    │ Work         │    │ Future       │
│ Store        │    │ Knowledge    │    │ Store N      │
│ (collection-1)│   │ (collection-2)│   │ (collection-n)│
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       └──────────┬────────┘─────────────────┘
           ┌──────┴──────┐
           │  QMD Search  │  ← query-time federation
           │  (MCP API)   │
           └──────────────┘
```

**Why not symlinks:**
- Symlinks break on mobile Obsidian, in backups, in git
- Each store is fully independent: own CLAUDE.md, own git, own config
- Adding a new store = `qmd collection add <path> --name <name>`. Zero impact on existing stores
- Cross-store search = separate QMD calls per collection

## Source Types

| Type | Capture method | Fallback |
|------|---------------|----------|
| `article` | `defuddle parse <url> --md` | WebFetch, manual paste |
| `book` | Manual: title, author, key quotes | Readwise MCP (future) |
| `podcast` | Transcript URL via defuddle | YouTube subtitles, manual |
| `video` | `yt-dlp --write-subs --skip-download` | defuddle on video page |
| `paper` | PDF read, key sections paste | Manual summary |
| `message` | Paste from Telegram/Slack/email | Screenshot → describe |
| `repo` | `defuddle parse <github-url> --md` | Manual paste |
| `idea` | Inline during session | Voice recording → reference |

## Extract Schema

```yaml
---
type: extract
source_type: article
visibility: public | personal | company | private
status: extracted | integrated
title: "Human-readable title"
author: ""
url: ""
created: YYYY-MM-DD
extracted: YYYY-MM-DD
tags: []
people: []
domains: []    # bridges to vault areas
---

## Summary
[2-3 sentences: what and why]

## Executive Summary
[0.5-1 page: full argument, through reader's lens]

## Key Ideas
- **Bold Title** #domain/area — one-sentence stand-alone claim.

## Connections
## Raw Quotes
```

### Reader Context — Executive Summary as Editorial Policy

Executive summaries are framed through the reader's current agenda, not neutral summarization. A "Reader Context" section in CLAUDE.md defines:

- Who you are, what you care about
- Current priorities (dynamic, updated each session)
- Per-domain framing (career → leadership lens, health → optimization lens)
- "What does this mean for my decisions?" > "What does this say?"

For freshness: link Reader Context to a shared context file that gets updated by your regular vault sessions, not manually maintained in the Knowledge Store.

## Domains Registry

Domains bridge Knowledge Store to vault areas. Open list — add as needed:

```yaml
# Personal domains (Life Capital areas)
domains: [learning, health, relationships, finance, career, culture, inner-work]

# Work domains (prefix with org/)
domains: [org/product, org/engineering, org/people, org/strategy, org/ai]

# Mixed
domains: [career, org/ai]  # relevant to both personal growth and work AI strategy
```

## Dump Import Protocol

External knowledge already exists in messy piles (Reading List, Apple Notes, YouTube Saved, Telegram Saved). Importing a dump ≠ adding a single source.

**Principles:**
1. A dump is **never processed in one session**. Budget ~20 items per session max
2. **ELT, not ETL** — load raw items first (`status: dumped`), then triage incrementally
3. **Default = skip**. Keep only what you'd read today. "Maybe interesting" ≠ keep
4. Each dump gets a tracker file for multi-session resume

```
Phase 1: EXTRACT  → bulk load raw items, minimal metadata
Phase 2: TRIAGE   → per session, ~20 items. keep / skip / merge
Phase 3: PROCESS  → normal /source-process pipeline on survivors
```

**Accumulation monitoring:** periodic checks on known dump sources (Reading List count, YouTube Saved count). Alert when threshold crossed. Integrate into morning briefing.

## Vault Structure

```
~/Obsidian/Knowledge/
├── .claude/
│   └── commands/     ← /source-add, /source-process, /knowledge-status
├── CLAUDE.md         ← vault identity + Reader Context
├── Sources/          ← {YYYY-MM-DD}_{hash8}/ with source.md + extract.md
├── Synthesis/        ← {topic-slug}.md (human-written, few)
├── _meta/            ← Protocol, Source Types, Taxonomy
├── Templates/        ← Source, Extract, Synthesis
└── index.md
```

## Commands

| Command | Purpose |
|---------|---------|
| `/source-add <URL or title>` | Capture: URL → defuddle → source.md, or manual input |
| `/source-process` | Extract: read source.md → create extract.md with metadata + key ideas |
| `/knowledge-status` | Pipeline status: counts, awaiting extraction, synthesis candidates |

## Tool Landscape (2026)

Evaluated 6 tools as alternatives/complements. Finding: **plain-text markdown on disk is the binding architectural constraint.** Everything in the stack (Claude Code Read/Write/Edit, QMD indexing, git versioning, cron jobs) depends on files. Any tool with proprietary storage breaks the chain.

| Tool | Strength | Why not for us |
|------|----------|----------------|
| AnyType | Best structured data (objects, spaces, local API, MCP) | Protobuf format — no file access for Claude Code/QMD/git |
| Tana | Supertags, AI auto-tagging, Meeting Agent | Cloud-only, no headless server, lossy export |
| Heptabase | Visual canvas, spatial reasoning, markdown export | Multi-space immature, MCP uses backup data |
| Capacities | Schema-enforced objects, labeled graph edges | API too weak, cloud dependency |
| Logseq | Datalog queries (SQL-power), block-level linking | DB version abandons markdown. Datalog = structural, not semantic |
| Khoj | Self-hosted RAG, Obsidian plugin (33K stars) | Vector-only search (no BM25), PostgreSQL dependency, no MCP |

**QMD confirmed best-in-class** for personal markdown search: BM25 + vector hybrid, local, MCP-native, collection-based vault isolation.

## Key Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D30 | Separate vault, not `_inputs/` extension | Needs own git, own CLAUDE.md, standalone sessions, QMD collection |
| D31 | No Atoms tier — Key Ideas in extract.md | AI atoms = mechanical derivatives without understanding |
| D32 | Federated QMD search, not symlinks | Symlinks break mobile/backups, create coupling |
| D33 | Visibility = sharing intent, not security | All knowledge belongs to one person. Tag for future sharing decisions |
| D34 | Domains: open list with namespace prefixes | Personal (9 slugs) + work (`org/` prefix). Bridges stores to vault areas |
| D35 | PAL model config via env var override | `OPENROUTER_MODELS_CONFIG_PATH` survives package updates |
| D36 | Shared context restructured for auto-freshness | Dynamic agenda in Context/, stable vault descriptions in Vaults/ |
