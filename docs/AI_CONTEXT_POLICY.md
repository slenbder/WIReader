# AI Context Policy

## Core Principle

WIReader's AI features must never spoil books.
AI responses are generated strictly from text the user has already read — never from future chapters.

## Rules for All AI Features

1. Only use content from chapters at or before the current reader position.
2. Position is defined by `(chapterIndex, chunkIndex)` — never by `characterOffset`.
   Filter: `chapterIndex < current` OR `(chapterIndex == current AND chunkIndex <= position)`.
3. The system prompt must explicitly forbid referencing facts not present in the provided context.
4. If insufficient context is available, the response must be exactly:
   > "Not enough context yet"
5. PDF is excluded from all AI processing (no reliable text layer for RAG).
6. Do not generate, infer, or summarize content from chapters the user has not reached.

## Feature-Specific Notes

### Who is?
- Triggered by long-press on a character name in the reader.
- Context: top-15 RAG chunks from the read portion, ranked by proximity to current position.
- Displayed as an overlay popup — not a separate screen.
- Requires active subscription.

### Chapter Summary
- Triggered on demand by the user, never automatically.
- Uses the full text of the already-read chapter.
- Cached in SwiftData after first generation (synced across devices).
- Requires active subscription.

## Implementation Reference

See docs/ARCHITECTURE.md §5 for the full RAG pipeline specification.
See docs/DECISIONS.md entries C4, C5, C6, C7 for the rationale behind these rules.
