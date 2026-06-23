# Codex Reusable Prompts

Paste these as the opening context when starting a Codex session.
Adjust the [PLACEHOLDER] values before use.

---

## Repository Bootstrap

```
You are working on WIReader, an iOS reading app.
Before doing anything:
1. Read docs/PROJECT_STATE.md
2. Read docs/TASK_QUEUE.md
3. Read docs/DOCUMENTATION_POLICY.md
4. Read CLAUDE.md (technical constraints — authoritative)

Do not touch wireader/docs/. Use docs/ for all context.
Explain your plan before editing any file.
```

---

## Small Feature Implementation

```
Implement task [TASK_ID] from docs/TASK_QUEUE.md.

Steps:
1. Read the full task description in docs/TASK_BREAKDOWN.md.
2. Confirm all dependencies are already completed (check docs/PROJECT_STATE.md).
3. Explain your implementation plan before writing code.
4. After implementing: run the build command from CLAUDE.md.
5. Summarize: changed files, line delta, risks.
6. Do not touch files outside the scope of this task.
```

---

## Bugfix

```
Fix the following bug: [DESCRIPTION]

Steps:
1. Read CLAUDE.md for technical constraints before touching any code.
2. Identify the root cause before proposing a fix.
3. Make the smallest diff that fixes the problem.
4. Do not refactor surrounding code.
5. Run the build command from CLAUDE.md after the fix.
6. List: root cause, files changed, risk of regression.
```

---

## Refactor

```
Refactor [COMPONENT/FILE] with the following goal: [GOAL]

Constraints:
- Behavior must not change.
- Do not modify Swift model files without checking CloudKit compatibility (see CLAUDE.md).
- Keep the diff small. One concern per session.
- Build must pass after every step.
- List: what changed, what stayed the same, risk.
```

---

## Documentation Update

```
Update documentation for: [TOPIC]

Rules:
1. Read docs/DOCUMENTATION_POLICY.md first.
2. All changes go to docs/. Do not touch wireader/docs/.
3. If updating docs/PROJECT_STATE.md or docs/TASK_QUEUE.md, flag it explicitly.
4. Do not invent facts — only document what is verifiable from the codebase or project owner input.
```

---

## Architecture Review

```
Review the architecture of [COMPONENT] against the documented design.

Reference files:
- docs/ARCHITECTURE.md — intended design
- docs/DECISIONS.md — rationale for key decisions
- CLAUDE.md — binding technical constraints

Report:
1. Does the implementation match the documented architecture?
2. Any constraint violations (SwiftData, async/await, Keychain, RAG position)?
3. Any undocumented deviations that should be recorded in docs/DECISIONS.md?
4. Recommendation.

Do not edit any files during this review unless asked.
```
