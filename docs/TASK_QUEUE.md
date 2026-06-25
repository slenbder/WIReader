# Task Queue

> Last updated: 2026-06-25
> Full task details: docs/TASK_BREAKDOWN.md
> Current project state: docs/PROJECT_STATE.md

Tasks are ordered within each priority tier by recommended execution order (dependencies first).
Do not skip tasks — earlier tasks have dependencies that later ones assume are complete.

---

## Priority: High

| Task | Status | Complexity | Depends On | Notes |
|------|--------|------------|------------|-------|
| 2.10 Paging mode (EPUB + TXT/FB2) | Todo | High | 2.3, 2.4 | Canonical position = positionInChapter (0.0–1.0). Page number is derived, never stored. See G10, G11 in DECISIONS. |
| 3.1 SubscriptionManager (StoreKit 2) | Todo | Medium | Phase 2 complete | Required gate before any AI feature can be built. Must implement first in Phase 3. |
| 3.2 OpenRouterClient | Todo | Medium | 3.1 | API key from Keychain only. Streaming via AsyncThrowingStream. |
| 3.3 RAGIndexer + BackgroundTasks | Todo | High | 3.2 | Fix HTML tag pollution before chunking (TODO(3.3) in code). |
| 3.6 WhoIsPopupView + context menu | Todo | High | 3.2, 3.3, 3.4, 3.5 | Killer feature. Overlay, not sheet. Streaming output. Two context menu entry points: WKWebView JS-bridge and UIMenuController. |

---

## Priority: Medium

| Task | Status | Complexity | Depends On | Notes |
|------|--------|------------|------------|-------|
| 2.11 Auto-scroll + auto-page-flip | Todo | Medium | 2.10 | Configurable speed/interval. Easy to start/stop. |
| 3.4 RAGRetriever | Todo | Medium | 3.3 | Skeleton exists (Decision G7). Filter by (chapterIndex, chunkIndex). Top-15 chunks by proximity. |
| 3.5 AIPromptBuilder | Todo | Low | 3.4 | Who is? system prompt with hard anti-spoiler constraint. Chapter summary prompt. |
| 3.7 ChapterSummarySheet | Todo | Medium | 3.2, 3.5 | Cache check first (ChapterSummary in SwiftData). Generate once, sync across devices. |
| 4.1 ReadingSessionTracker | Todo | Low | Phase 3 complete | Start on reader open, stop on close/background. |
| 4.2 StatisticsService | Todo | Medium | 4.1 | Aggregate by day/week/month/year. Streak calculation. |
| 4.3 StatisticsView + ReadingChartView | Todo | Medium | 4.2 | Swift Charts, bar chart, period toggle. |
| 5.1 OnboardingView | Todo | Medium | Phase 4 complete | First-launch only (@AppStorage flag). Trial offer. Import first book in-flow. |
| 5.3 Paywall UI | Todo | Medium | 3.1 | Triggered by gated feature tap. Month/year plans, 14-day trial. |

---

## Priority: Low

| Task | Status | Complexity | Depends On | Notes |
|------|--------|------------|------------|-------|
| 2.8 Bookmarks | Todo | Low | 2.6 | Current next task. Add at current position, list, navigate, delete. Synced via SwiftData. |
| 2.9 Notes | Todo | Low | 2.8 | Text selection → note with position binding. List, navigate, delete. Synced. |
| 4.4 ActivityGridView | Todo | Medium | 4.2 | GitHub-style heatmap, year/month view. |
| 4.5 GoalsView + Streaks | Todo | Medium | 4.2 | Annual goal (books/pages/minutes), daily streak, personal challenges. |
| 5.2 Sign in with Apple | Todo | Low | 5.1 | AccountView in Settings only. Keychain credential storage. No effect on sync. |
| 5.4 App Store submission | Todo | High | Phase 5 tasks | Icon, screenshots, privacy policy, StoreKit products, App Store Connect upload. |

---

## Completed (reference)

See docs/PROJECT_STATE.md — Implemented Features section.
Full details with criteria: docs/TASK_BREAKDOWN.md.

Recent completion:

| Task | Status | Complexity | Depends On | Notes |
|------|--------|------------|------------|-------|
| 2.7 TableOfContentsView | Done | Low | 2.6 | TableOfContentsView opens from ReaderControlsView, lists ReaderViewModel chapters, highlights current chapter, jumps via `goToChapter(index)`, and dismisses. PDF TOC button remains visible but disabled. Build succeeded; manual EPUB/TXT/FB2/PDF verification passed; `/review` found no blocking issues. |
| 2.6 ReaderControlsView | Done | Medium | 2.5 | Top/bottom reader controls with auto-hide implemented. EPUB tap bridge fixed. Manual simulator verification passed for EPUB/TXT/FB2/PDF. `/review` found no blocking issues. |
| 2.5 ReaderSettingsSheet | Done | Medium | 2.4 | ReaderSettingsSheet MVP complete: theme picker with previews, font size, line spacing, margins, TXT/FB2 font selection, all persisted via @AppStorage and live-applied. EPUB typography intentionally unchanged; EPUB themes, G10 restore semantics, EPUB didFinish/reapply behavior, and PDF rendering preserved. Build succeeded, manual EPUB/TXT/FB2/PDF simulator checks passed, `/review` found no blocking issues. |
| 2.4 Theme system + @AppStorage | Done | Medium | 2.2 | ReaderTheme complete: light/dark/sepia; midnight/forest premium metadata only. `@AppStorage("selectedThemeId")`; EPUB CSS injection; TextKit 2 theme application; PDF unchanged. Build succeeded, manual EPUB/TXT/FB2/PDF-unaffected simulator checks passed, review had no High findings. |
| 2.3 PDFReaderView | Done | Low | 2.2 | PDFKit as-is rendering. Page-based progress saves/restores correctly. Manual simulator test passed on a real PDF file. |
