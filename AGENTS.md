# WIReader — Agent Instructions (Codex / General)

> For Claude Code instructions, see CLAUDE.md.
> This file is the entry point for Codex and any non-Claude agent.

---

## Required Reading Order

Before taking any action, read these files in order:

1. `docs/PROJECT_STATE.md` — current feature status, known bugs, technical debt
2. `docs/TASK_QUEUE.md` — what to work on next, priorities, dependencies
3. `docs/DOCUMENTATION_POLICY.md` — canonical vs. historical docs, conflict rules
4. `docs/ARCHITECTURE.md` — system design, data models, rendering pipeline, AI flow
5. `docs/DECISIONS.md` — rationale behind key decisions; read before proposing changes
6. `docs/PRD.md` — product requirements and feature scope
7. `CLAUDE.md` — project contract (hard rules that apply to all agents, not just Claude)

Do not use `wireader/docs/` as an active source of truth.
It contains historical documentation. If you find a conflict between `wireader/docs/` and `docs/`, `docs/` wins.

---

## Project Overview

WIReader is an AI-assisted iOS reading application.

**Killer feature:** "Who is?" — on long-press of a character name, an AI popup appears with a spoiler-free character summary based strictly on the portion of the book the user has already read.

**Formats:** EPUB, TXT, FB2, PDF
**Platform:** iOS 17+
**Business model:** Freemium. Free reading for all formats. AI features and premium themes require subscription.

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Architecture | MVVM + Repository |
| Local data | SwiftData (two configs: CloudKit-synced + local-only) |
| File sync | iCloud Ubiquitous Container |
| EPUB rendering | WKWebView + loadFileURL |
| TXT/FB2 rendering | TextKit 2 (UITextView) |
| PDF rendering | PDFKit |
| AI API | OpenRouter (OpenAI-compatible), model: anthropic/claude-sonnet-4-5 |
| Subscriptions | StoreKit 2 |
| External dependency | ZIPFoundation (only one) |

---

## Coding Principles

- Preserve the existing architecture. Do not introduce new patterns without discussion.
- Small diffs preferred. One task = one focused change.
- No unnecessary abstractions. Do not design for hypothetical future requirements.
- Prefer native Apple APIs over third-party libraries.
- All ViewModels use `@Observable`, not `ObservableObject`.
- All async code uses `async/await`. No Combine, no completion handlers.
- Do not add dependencies beyond ZIPFoundation without explicit approval.

---

## Technical Constraints

**CLAUDE.md is the authoritative source for all project-specific technical constraints.**
Read it as step 4 of the required reading order above.

If anything in AGENTS.md appears to conflict with CLAUDE.md, CLAUDE.md wins unless the project owner explicitly says otherwise.

CLAUDE.md defines the binding rules for: SwiftData + CloudKit model requirements, API key storage, reader settings storage, RAG position filtering, JavaScript evaluation, and import requirements. Do not infer these from AGENTS.md — read them from CLAUDE.md directly.

---

## Editing Rules

1. Read `docs/PROJECT_STATE.md` and `docs/TASK_QUEUE.md` before selecting a task.
2. Pick the next unchecked task in priority order. Do not skip dependencies.
3. Explain your plan before editing any file.
4. After editing: summarize what changed, list modified files, list risks.
5. Each task must compile cleanly before declaring it complete.

---

## Testing Policy

- Run the build command from CLAUDE.md before declaring a task done:
  ```
  xcodebuild -scheme wireader -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -20
  ```
- If tests cannot run (no test targets, simulator unavailable), say so explicitly. Do not claim success without verification.
- Functional testing of the UI cannot be verified by build alone — flag this when relevant.

---

## AI Context Rules

These are non-negotiable. See `docs/AI_CONTEXT_POLICY.md` for full details.

- Never access book content beyond the reader's current position.
- Never spoil books.
- Only use passages available before `(chapterIndex, chunkIndex)` of the current position.
- If context is insufficient, the AI response must be: `"Not enough context yet"`
- PDF is excluded from all AI processing.

---

## Documentation Rules

- Read `docs/DOCUMENTATION_POLICY.md` before touching any documentation file.
- All documentation updates go to `docs/`. Do not update `wireader/docs/`.
- If you update `docs/PROJECT_STATE.md` or `docs/TASK_QUEUE.md`, say so explicitly in your summary.

---

## Current Priorities

1. Read `docs/PROJECT_STATE.md`
2. Read `docs/TASK_QUEUE.md`
3. The current focus is completing Phase 2 (tasks 2.3–2.11): full reading experience for all formats, themes, bookmarks, notes, paging mode, and auto-scroll.
4. Phase 3 (AI/subscription) begins only after Phase 2 is complete.
