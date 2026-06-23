# Project State

> Last updated: 2026-06-24
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

Phase 2.2 — TextReaderView (TextKit 2), deterministic position restore

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

---

## Features In Progress

### Phase 2 — Full Reading Experience (remaining)
- 🚧 2.3 PDFReaderView (PDFKit)
- 🚧 2.4 Theme system (ReaderTheme, @AppStorage, CSS injection for EPUB, NSAttributedString for TextKit)
- 🚧 2.5 ReaderSettingsSheet (font size, font choice, line spacing, margins, theme picker)
- 🚧 2.6 ReaderControlsView (top/bottom bars, auto-hide)
- 🚧 2.7 TableOfContentsView
- 🚧 2.8 Bookmarks
- 🚧 2.9 Notes (with text selection)
- 🚧 2.10 Paging mode (horizontal page-flip for EPUB + TXT/FB2) — complex
- 🚧 2.11 Auto-scroll + auto-page-flip

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

---

## Current Focus

Complete Phase 2 (tasks 2.3–2.11) to reach a fully functional reader for all supported formats before adding AI.

## Next Milestone

**After Phase 2:** Full-featured reader for EPUB, TXT, FB2, PDF with themes, bookmarks, notes, paging, and auto-scroll. App is usable for daily reading without AI.

**After Phase 3:** "Who is?" — the core competitive differentiator — is live.

---

## Notes for Agents

- `wireader/docs/` contains the original archived documentation. Use `docs/` for all context. See `docs/DOCUMENTATION_POLICY.md`.
- The canonical task list is `docs/TASK_BREAKDOWN.md`. The priority queue is `docs/TASK_QUEUE.md`.
- Every task must compile before moving to the next. See `CLAUDE.md` for the build command.
- All SwiftData models must have optional or default-valued properties for CloudKit compatibility.
