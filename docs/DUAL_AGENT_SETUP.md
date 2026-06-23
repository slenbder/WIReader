# WIReader Dual-Agent Setup v1.0

**Status:** Complete
**Date:** 2026-06-24
**Maintainer:** Project owner

This document describes the dual-agent infrastructure added to the WIReader repository.
It is a record of what was set up, not a task list.

---

## Supported Agents

| Agent | Entry point | Reads from |
|---|---|---|
| Claude Code | `CLAUDE.md` (auto-loaded) | `docs/` via `@docs/` syntax |
| Codex | `AGENTS.md` | `docs/` directly |

Both agents use the same canonical documentation folder. Neither modifies `wireader/docs/`.

---

## Repository Structure

```
WIReader/
├── CLAUDE.md               ← Claude Code entry point (authoritative for technical constraints)
├── AGENTS.md               ← Codex / general agent entry point
│
├── docs/                   ← Canonical documentation (single source of truth)
│   ├── ARCHITECTURE.md
│   ├── PRD.md
│   ├── TASK_BREAKDOWN.md
│   ├── DECISIONS.md
│   ├── PROJECT_STATE.md    ← Maintained by project owner
│   ├── TASK_QUEUE.md
│   ├── AI_CONTEXT_POLICY.md
│   ├── DOCUMENTATION_POLICY.md
│   └── DUAL_AGENT_SETUP.md ← this file
│
├── agent_docs/
│   ├── claude/
│   │   └── CLAUDE.md.backup
│   └── codex/
│       ├── prompts.md      ← reusable session prompts
│       └── comparison.md   ← Claude vs Codex experiment log
│
└── wireader/
    └── docs/               ← Historical documentation (do not update)
```

---

## Documentation Policy

`docs/` is the canonical folder. `wireader/docs/` is historical and must not be updated.

Full rules: `docs/DOCUMENTATION_POLICY.md`

If a conflict exists between the two folders, `docs/` wins unless the project owner says otherwise.

---

## Documentation Model

This section explains how documentation is structured for a new contributor to understand in under 2 minutes.

### Single Source of Truth

`docs/` (repo root) is the only active documentation directory.

All new architectural decisions, state updates, task lists, and policy changes go here.
Both Claude Code and Codex read from and write to the same folder, so they always work from identical context.

### Historical Snapshots

`wireader/docs/` contains the original documentation files from project setup.
They are preserved for rollback and reference but are never updated during normal development.
A `wireader/docs/README.md` marker makes this clear to anyone who opens the folder.

### Conflict Resolution

If `docs/` and `wireader/docs/` ever disagree, `docs/` wins.
The project owner is the only person who can override this.

### Rollback Strategy

The entire dual-agent infrastructure can be removed in under 2 minutes:

```bash
rm -rf docs/
rm -rf agent_docs/
rm AGENTS.md
```

`CLAUDE.md` and `wireader/docs/` were never modified — Claude Code continues working immediately.

### Agent Reading Order

Agents should read documentation in this order before acting:

1. `docs/PROJECT_STATE.md` — what is built, what is in progress, known bugs
2. `docs/TASK_QUEUE.md` — what to work on next
3. `docs/DOCUMENTATION_POLICY.md` — where to read and write documentation
4. `docs/ARCHITECTURE.md` — system design, data models, rendering pipeline
5. `docs/DECISIONS.md` — rationale for key decisions; consult before proposing changes
6. `docs/PRD.md` — product requirements and feature scope
7. `CLAUDE.md` — binding technical constraints (authoritative for all agents)

---

## Rollback Procedure

To return to Claude-only mode:

```bash
rm -rf docs/
rm -rf agent_docs/
rm AGENTS.md
```

`CLAUDE.md` was never modified. `wireader/docs/` was never modified.
Claude Code continues working immediately. No data is lost.

Estimated time: under 2 minutes.

---

## Comparison Workflow

After running the same task with both agents, record results in:

`agent_docs/codex/comparison.md`

Evaluation dimensions: architecture, diff discipline, tests, prompt adherence, hallucinations, overall.

Patterns across multiple entries reveal each agent's systematic strengths and blind spots, which informs future task routing.

---

## Recommended Workflow

```
Task design (Claude.ai or ChatGPT)
        ↓
Implementation (Codex CLI or Claude Code)
        ↓
Review (Claude.ai / ChatGPT)
        ↓
Build verification (xcodebuild — see CLAUDE.md)
        ↓
Git commit
        ↓
Optional: run same task with other agent → log in comparison.md
```

For complex architectural features, prefer Codex for implementation.
For focused bug fixes with a tight scope, either agent works.
Always explicitly request tests — neither agent writes them unprompted reliably.

---

## Known Limitations

- `docs/PROJECT_STATE.md` and `docs/TASK_QUEUE.md` require manual updates by the project owner. Agent-generated content in these files should be reviewed before acceptance.
- `docs/ARCHITECTURE.md` and `docs/TASK_BREAKDOWN.md` are point-in-time copies from `wireader/docs/`. They do not auto-sync. Update manually when the originals change significantly.
- The comparison log is only as useful as the discipline applied to filling it in consistently.
