# Documentation Policy

## Documentation Source of Truth

`docs/` at the repository root is the single source of truth for all project documentation.

All new architectural decisions, plans, state updates, and task management records must be written here.
All agent workflows — Claude Code, Codex, or any future agent — must read from and write to `docs/`.

## Historical Documentation Folder

`wireader/docs/` contains preserved snapshots of documentation from project setup.
These files are retained for rollback and historical reference only.

**Do not update `wireader/docs/` during normal development. Do not use it as an active source of truth.**

## Rules

1. New documentation goes to `docs/`.
2. Documentation updates go to `docs/`.
3. Do not update `wireader/docs/` unless the user explicitly asks.
4. Do not manually keep both folders in sync.
5. If a conflict exists between `docs/` and `wireader/docs/`, `docs/` wins unless the user says otherwise.

## File Mapping

| Canonical — use this         | Historical — do not update                    |
|------------------------------|-----------------------------------------------|
| docs/ARCHITECTURE.md         | wireader/docs/WIReader_Architecture.md        |
| docs/PRD.md                  | wireader/docs/WIReader_PRD.md                 |
| docs/TASK_BREAKDOWN.md       | wireader/docs/WIReader_TaskBreakdown.md       |
| docs/DECISIONS.md            | wireader/docs/WIReader_DecisionLog.md         |
| docs/PROJECT_STATE.md        | (no historical equivalent)                        |
| docs/TASK_QUEUE.md           | (no historical equivalent)                        |
| docs/AI_CONTEXT_POLICY.md    | (no historical equivalent)                        |
| docs/DOCUMENTATION_POLICY.md | (no historical equivalent)                        |
