# Claude Environment

## What this is

Framework for running Claude Code across multiple machines with data pipelines, automation, and Obsidian vault integration. Patterns, templates, and reference implementations.

## Repo structure

```
├── dotfiles/           # Claude Code config examples (user symlinks to ~/.claude/)
│   ├── CLAUDE.md.example       # Global CLAUDE.md template
│   ├── settings.json.example   # Global settings template
│   ├── rules/
│   │   └── environment.md.example  # Machine identity template
│   ├── skills/
│   │   └── example-skill/      # Skill file structure example
│   └── templates/              # Project-level settings templates
│       ├── settings.local.obsidian.json
│       └── settings.local.coding.json
├── docs/               # Architecture, decisions, security, guides
├── pipelines/          # Data integration patterns
│   ├── calendar/       # Google Calendar → per-day JSON (reference implementation)
│   ├── health/         # Oura/Apple Health (pattern description)
│   └── voice/          # Voice recorder transcripts (pattern description)
├── jobs/               # Cron job wrappers (examples, server only)
├── multi-machine/      # Multi-machine sync patterns
├── install.sh          # Dotfiles installer (symlinks + backup)
├── server-setup.sh     # Server bootstrap (deploy key, LaunchAgents, symlinks)
└── check.sh            # Validation script
```

Note: The author's private dotfiles (actual bin/, rules/, launchd/) are not in this repo.
This repo provides templates and examples; users build their own dotfiles from these.

## Conventions

- Docs in `docs/` are the canonical source for framework documentation
- Scripts in `dotfiles/bin/` must work on both macOS laptop and server
- Templates in `dotfiles/templates/` are starting points — users customize per project
- Pipeline READMEs must state whether they are "reference implementation" or "pattern description"
- `install.sh` must be idempotent — safe to re-run

## Vault mirror

This repo has a mirror in the author's Obsidian vault (`Projects/Environment Setup/`). The vault copy contains:
- `index.md` — project overview, jobs table, ways of working (private)
- `Architecture.md`, `Decisions.md`, etc. — detailed versions with personal context
- `Progress.md` — per-machine status (private, contains hostnames/IPs)
- `Migration Plan.md` — personal timeline (private)

**Publishing flow:** vault files are depersonalized and published to `docs/`. Vault versions may have more detail (personal context, wiki links, frontmatter). Published versions are standalone, no Obsidian dependencies.

## Companion project

[obsidian-seed](https://github.com/dkushnikov/obsidian-seed) — vault setup wizard. Seed = vault content, Environment = infrastructure around it.

## Key design decisions

See [docs/decisions.md](docs/decisions.md) for the full log. Key ones:
- D1: Symlinks, not copies (single source of truth)
- D4: Universal skills global, domain skills in projects (clean context)
- D6: Global CLAUDE.md = identity only (no domain noise)
- D8: Bash scripts, not chezmoi (simple for 2 machines)
- D9: Machine identity via environment.md (same repo, different behavior)

## Security

- Never commit secrets (API tokens, SSH keys, .env files)
- `config/` directory is gitignored
- `environment.md` is gitignored (machine-specific, created by install.sh)
- See [docs/security.md](docs/security.md) for trust model
