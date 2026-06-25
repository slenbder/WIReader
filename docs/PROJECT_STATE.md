# Project State

> Last updated: 2026-06-25
> Branch: main
> Canonical docs: docs/ (see docs/DOCUMENTATION_POLICY.md)
> Original archived docs: wireader/docs/ — do not use as active source of truth

> **Ownership:** This file is maintained primarily by the project owner.
> Agent-generated suggestions (inferred from git log, code analysis, etc.) must be reviewed and confirmed before being treated as accurate project state.

---

## Version

Pre-release. No App Store submission yet.

## Current Branch

`main`

## Last Completed Task

Phase 2.7 — TableOfContentsView

---

## Implemented Features

### Phase 0 — Project Setup
- ✅ 0.1 Xcode project (SwiftUI lifecycle, iOS 17+, bundle ID: com.slenbder.wireader)
- ✅ 0.2 Capabilities & entitlements (iCloud, CloudKit, Background Modes, App Groups)
- ✅ 0.3 Folder structure + ZIPFoundation dependency
- ✅ 0.4 Core layer (AppConstants, APIConstants, AppLogger, ErrorTypes, extensions)

### Phase 1 — Core Reading
- ✅ 1.1 SwiftData models (Book, ReadingProgress, Bookmark, Note, ReadingSession, ReadingGoal, BookCollection, ChapterSummary, AIChunk) — CloudKit-compatible (all properties optional or with defaults)
- ✅ 1.2 ModelContainer with two configurations: synced (CloudKit) + local (AIChunk)
- ✅ 1.3 FileStorageService (iCloud Ubiquitous Container, local fallback)
- ✅ 1.4 EPUBParser (ZIPFoundation, OPF manifest, NCX/NAV table of contents, cover)
- ✅ 1.5 BookImportService (EPUB full, TXT/FB2/PDF stubs)
- ✅ 1.6 BookRepository (@MainActor, CRUD, cascade delete)
- ✅ 1.7 LibraryView + LibraryViewModel (@Observable, grid/list, file importer, search)
- ✅ 1.8 ReaderContainerView + EPUBReaderView (WKWebView, loadFileURL, chapter navigation)
- ✅ 1.9 Reading progress — JS bridge, throttled save, restore on open
- ✅ 1.10 BookDetailView + BookDetailViewModel

### Phase 2 — Full Reading Experience (partial)
- ✅ 2.1 TXTParser + FB2Parser (format-independent BookChapter + ChapterContent model)
- ✅ 2.2 TextReaderView (TextKit 2, UITextView, deterministic position restore)
- ✅ 2.3 PDFReaderView (PDFKit, as-is rendering, page-based progress save/restore)
- ✅ 2.4 Theme system + @AppStorage (ReaderTheme; light, dark, sepia, midnight, forest; EPUB CSS injection; TextKit 2 theme application)
- ✅ 2.5 ReaderSettingsSheet (theme picker with previews, font size, line spacing, margins, TXT/FB2 font selection, @AppStorage persistence)
- ✅ 2.6 ReaderControlsView (top/bottom bars, auto-hide, EPUB tap bridge)
- ✅ 2.7 TableOfContentsView (chapter list, current chapter highlight, chapter jump, PDF disabled state)

---

## Features In Progress

### Phase 2 — Full Reading Experience (remaining)
- 🚧 2.8 Bookmarks
- 🚧 2.9 Notes (with text selection)
- 🚧 2.10 Paging mode (horizontal page-flip for EPUB + TXT/FB2) — complex
- 🚧 2.11 Reader UI Polish Pass
- 🚧 2.12 Auto-scroll + auto-page-flip

---

## Planned Features

### Phase 3 — AI (killer feature)
- □ 3.1 SubscriptionManager (StoreKit 2) — required gate before AI
- □ 3.2 OpenRouterClient (streaming, Keychain API key, async/await)
- □ 3.3 RAGIndexer + BackgroundTasks (BGProcessingTask)
- □ 3.4 RAGRetriever (chapterIndex+chunkIndex filter) — skeleton exists (G7 in DECISIONS)
- □ 3.5 AIPromptBuilder
- □ 3.6 WhoIsPopupView + context menu (EPUB JS-bridge + TextView UIMenuController)
- □ 3.7 ChapterSummarySheet

### Phase 4 — Gamification
- □ 4.1 ReadingSessionTracker
- □ 4.2 StatisticsService
- □ 4.3 StatisticsView + ReadingChartView (Swift Charts)
- □ 4.4 ActivityGridView (GitHub-style heatmap)
- □ 4.5 GoalsView + Streaks

### Phase 5 — App Store
- □ 5.1 OnboardingView
- □ 5.2 Sign in with Apple (AccountView)
- □ 5.3 Paywall UI (SubscriptionView)
- □ 5.4 App Store submission (icon, screenshots, privacy policy)

---

## Known Bugs / Under Investigation

- **G13 (Triple didFinish in EPUBReaderView):** Three `didFinish` events fire per chapter load with scrollHeight values 195 → 15313 → 14569. Position accuracy depends on reapply at each event. Root cause in `updateUIView` not yet fixed; fixing without preserving reapply semantics causes regression. Status: under investigation.

---

## Technical Debt

- `RAGIndexer.loadChapters` — when content is `.html`, reads raw HTML string with tags before chunking. Tags will pollute RAG chunks. Marked `TODO(3.3)` in code. Must clean HTML before chunking when implementing task 3.3.
- `BookImportService` — TXT/FB2/PDF import paths are stubs from Phase 1. Now replaced by real parsers (2.1), but verify integration is complete.
- `EPUBParser` currently treats spine HTML files as app-level chapters. Some EPUB files contain multiple human-visible book chapters inside one spine item, so app-level TOC entries may not always match visible book headings. Future parser refinement may need NAV/NCX anchor mapping or heading-based subchapter splitting.

---

## Current Focus

Phase 2.8 — Bookmarks.

## Manual Verification Notes

- Phase 2.3 PDFReaderView: manual simulator test passed on a real PDF file. PDF opens with PDFKit; page-based progress saves, updates book preview progress, and restores correctly on reopen. Current PDF UX uses vertical continuous scrolling, acceptable for 2.3.
- Phase 2.4 Theme system: build succeeded and manual simulator testing passed for EPUB, TXT, and FB2. PDF was intentionally unchanged and verified unaffected. `ReaderTheme` implements light, dark, sepia, midnight, and forest; midnight/forest are premium metadata only with no subscription gate. Theme selection is stored via `@AppStorage("selectedThemeId")`. EPUB themes are applied through CSS injection while preserving `didFinish`/reapply restore behavior. TextReader themes are applied through TextKit 2 while preserving G10 restore semantics. Review completed with no High findings.
- Phase 2.5 ReaderSettingsSheet: build succeeded and manual simulator testing passed for EPUB, TXT, FB2, and PDF. Added ReaderSettingsSheet MVP with theme picker previews, font size, line spacing, reader margins, and TXT/FB2 font selection. Settings persist via `@AppStorage` and apply live. EPUB typography was intentionally left unchanged for this task; EPUB themes continue to work and `didFinish`/reapply behavior is preserved. PDF rendering was intentionally unchanged. TextReader G10 restore semantics are preserved. `/review` found no blocking issues.
- Phase 2.6 ReaderControlsView: ReaderControlsView implemented with top/bottom bars and auto-hide behavior. EPUB tap bridge was fixed so taps in WKWebView toggle controls correctly. Manual simulator verification passed for EPUB, TXT, FB2, and PDF. `/review` found no blocking issues.
- Phase 2.7 TableOfContentsView: TableOfContentsView implemented and opened from the ReaderControlsView TOC button. It lists chapters from ReaderViewModel, highlights the current chapter with accent color, semibold text, and checkmark, and selecting a chapter calls `goToChapter(index)` and dismisses the sheet. PDF keeps the TOC button visible but disabled. Build succeeded. `/review` found no blocking issues. Manual simulator verification passed: EPUB TOC opens, highlights the current chapter, jumps correctly, and dismisses; TXT/FB2 TOC flow works correctly; PDF TOC button remains visible but disabled.

## Next Milestone

**After Phase 2:** Full-featured reader for EPUB, TXT, FB2, PDF with themes, bookmarks, notes, paging, and auto-scroll. App is usable for daily reading without AI.

**After Phase 3:** "Who is?" — the core competitive differentiator — is live.

---

## Notes for Agents

- `wireader/docs/` contains the original archived documentation. Use `docs/` for all context. See `docs/DOCUMENTATION_POLICY.md`.
- The canonical task list is `docs/TASK_BREAKDOWN.md`. The priority queue is `docs/TASK_QUEUE.md`.
- Every task must compile before moving to the next. See `CLAUDE.md` for the build command.
- All SwiftData models must have optional or default-valued properties for CloudKit compatibility.
