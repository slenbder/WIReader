# WIReader — Architecture Document
> Версия 2.0 (revised) | iOS 17+ | SwiftUI + MVVM

---

## Что изменилось по сравнению с v1.0

7 реальных проблем исправлено:
1. SwiftData + CloudKit — требования к моделям не были учтены
2. AIAPIClient — Anthropic и OpenRouter имеют разные форматы API
3. RAG позиция — characterOffset не работает для EPUB
4. EPUB в WKWebView — ассеты не загрузятся без правильного подхода к загрузке
5. Sign in with Apple vs CloudKit — это независимые системы, перепутаны
6. SubscriptionManager — был в Phase 5, но нужен уже в Phase 3 для AI-гейта
7. Настройки ридера — были в SwiftData, должны быть в UserDefaults

---

## 1. Технологический стек

| Слой | Решение | Обоснование |
|------|---------|-------------|
| UI | SwiftUI | Декларативный, нативный, современный |
| Архитектурный паттерн | MVVM + Repository | Чистое разделение, тестируемость |
| Локальные данные | SwiftData | iOS 17+, нативный CloudKit sync |
| Настройки ридера | UserDefaults / @AppStorage | Простые key-value, не нужен SwiftData |
| Синхронизация файлов | iCloud Ubiquitous Container | Автосинк файлов книг без бэкенда |
| Синхронизация данных | SwiftData + CloudKit | Прогресс, закладки, заметки |
| EPUB рендеринг | WKWebView + loadFileURL | Стандарт индустрии, правильная загрузка ассетов |
| TXT / FB2 рендеринг | TextKit 2 (UITextView) | Нативный, быстрый, полный контроль |
| PDF рендеринг | PDFKit | Apple-нативный, бесплатный |
| AI API | OpenRouter (OpenAI-compatible) | Единый формат, поддерживает Claude, гибко |
| Подписки | StoreKit 2 | Современный API, async/await |
| Авторизация | Sign in with Apple | Для идентификации пользователя в приложении |
| Фоновые задачи | BackgroundTasks (BGProcessingTask) | RAG-индексирование в фоне |
| Внешние зависимости | ZIPFoundation | Только одна |

---

## 2. Хранение данных — три уровня

```
┌─────────────────────────────────────────────────────────┐
│  UserDefaults / @AppStorage                             │
│                                                         │
│  Настройки ридера:                                      │
│    selectedThemeId, fontSize, lineSpacing,              │
│    margins, readingMode, autoScrollSpeed                │
│                                                         │
│  Простые key-value, не нуждаются в SwiftData            │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  iCloud Ubiquitous Container                            │
│  (FileManager + ubiquityContainerURL)                   │
│                                                         │
│  /Books/                                                │
│    {uuid}.epub                                          │
│    {uuid}.fb2                                           │
│    {uuid}.txt                                           │
│                                                         │
│  Синхронизируется автоматически между устройствами      │
│  Работает независимо от Sign in with Apple              │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  SwiftData — два ModelConfiguration в одном Container   │
│                                                         │
│  [cloudKitDatabase: .automatic] — синхронизируется:     │
│    Book, ReadingProgress, Bookmark, Note,               │
│    ReadingSession, ReadingGoal, BookCollection,         │
│    ChapterSummary                                       │
│                                                         │
│  [cloudKitDatabase: .none] — только локально:           │
│    AIChunk                                              │
│    Причина: тысячи чанков синхронизировать дорого и     │
│    бессмысленно — можно перестроить из файла            │
└─────────────────────────────────────────────────────────┘
```

### Важно: CloudKit требует совместимых моделей

SwiftData + CloudKit накладывает жёсткие ограничения — нарушить их значит получить crash на синке:
- Все свойства должны быть **optional** или иметь **default value**
- `@Attribute(.unique)` для id-полей
- Нет non-optional примитивов без дефолта

---

## 3. Модели данных (SwiftData)

```swift
// ⚠️ CloudKit-совместимые модели: все свойства с дефолтами или optional

@Model class Book {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String = ""
    var author: String? = nil
    var format: String = "epub"              // "epub" | "pdf" | "txt" | "fb2"
    var fileName: String = ""               // имя файла в iCloud container
    var coverImageData: Data? = nil
    var dateAdded: Date = Date()
    var lastReadDate: Date? = nil
    var tags: [String] = []
    var isIndexed: Bool = false             // RAG-индекс построен?

    @Relationship(deleteRule: .cascade) var progress: ReadingProgress?
    @Relationship(deleteRule: .cascade) var bookmarks: [Bookmark] = []
    @Relationship(deleteRule: .cascade) var notes: [Note] = []
    @Relationship(deleteRule: .cascade) var sessions: [ReadingSession] = []
    @Relationship(deleteRule: .cascade) var chapterSummaries: [ChapterSummary] = []
    var collection: BookCollection? = nil
    // AIChunk — в отдельном local-only контейнере, связь через bookId
}

@Model class ReadingProgress {
    @Attribute(.unique) var id: UUID = UUID()
    var bookId: UUID = UUID()
    var chapterIndex: Int = 0
    var positionInChapter: Double = 0.0     // 0.0 – 1.0 scroll offset
    var overallProgress: Double = 0.0       // 0.0 – 1.0
    var lastUpdated: Date = Date()
    var isFinished: Bool = false
    // ⚠️ Нет characterOffset — см. секцию RAG
}

@Model class Bookmark {
    @Attribute(.unique) var id: UUID = UUID()
    var bookId: UUID = UUID()
    var chapterIndex: Int = 0
    var positionInChapter: Double = 0.0
    var title: String? = nil
    var dateCreated: Date = Date()
}

@Model class Note {
    @Attribute(.unique) var id: UUID = UUID()
    var bookId: UUID = UUID()
    var chapterIndex: Int = 0
    var positionInChapter: Double = 0.0
    var selectedText: String = ""
    var noteText: String = ""
    var dateCreated: Date = Date()
}

@Model class ReadingSession {
    @Attribute(.unique) var id: UUID = UUID()
    var bookId: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date? = nil
    var wordsRead: Int = 0
    var pagesRead: Int = 0
}

@Model class ReadingGoal {
    @Attribute(.unique) var id: UUID = UUID()
    var year: Int = Calendar.current.component(.year, from: Date())
    var type: String = "books"              // "books" | "pages" | "minutes"
    var target: Int = 12
    var current: Int = 0
}

@Model class BookCollection {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#5B7FA6"
    var dateCreated: Date = Date()
    @Relationship var books: [Book] = []
}

@Model class ChapterSummary {
    @Attribute(.unique) var id: UUID = UUID()
    var bookId: UUID = UUID()
    var chapterIndex: Int = 0
    var summaryText: String = ""
    var generatedAt: Date = Date()
}

// ⚠️ Только локально — отдельный ModelConfiguration без CloudKit
@Model class AIChunk {
    @Attribute(.unique) var id: UUID = UUID()
    var bookId: UUID = UUID()
    var chapterIndex: Int = 0
    var chunkIndex: Int = 0
    var text: String = ""
    // ⚠️ Нет characterOffset — позиция определяется через (chapterIndex, chunkIndex)
}
```

### Инициализация контейнера

```swift
// WIReaderApp.swift
let syncedSchema = Schema([
    Book.self, ReadingProgress.self, Bookmark.self,
    Note.self, ReadingSession.self, ReadingGoal.self,
    BookCollection.self, ChapterSummary.self
])

let localSchema = Schema([AIChunk.self])

let syncedConfig = ModelConfiguration(
    "Synced",
    schema: syncedSchema,
    cloudKitDatabase: .automatic
)

let localConfig = ModelConfiguration(
    "Local",
    schema: localSchema,
    cloudKitDatabase: .none
)

let container = try ModelContainer(
    for: syncedSchema,
    configurations: [syncedConfig, localConfig]
)
```

---

## 4. AI API Client — OpenRouter

### Почему OpenRouter, а не прямой Anthropic API

Anthropic API и OpenRouter используют **разные форматы запросов и заголовков** — нельзя просто поменять baseURL:

| | Anthropic Direct | OpenRouter |
|--|--|--|
| Endpoint | `/v1/messages` | `/api/v1/chat/completions` |
| Формат | Anthropic Messages API | OpenAI Chat Completions |
| Auth header | `x-api-key` + `anthropic-version` | `Authorization: Bearer` |

Решение: **OpenRouter как единственный клиент**.
- Поддерживает `anthropic/claude-sonnet-4-5` и все Claude-модели
- OpenAI-совместимый формат — проще, документации больше
- Ты уже работаешь с ним через OpenClaw на маке
- При желании легко подключить другие модели без изменения кода

```swift
// AIAPIClient.swift
protocol AIAPIClientProtocol {
    func complete(messages: [AIMessage], system: String?) async throws -> String
    func stream(messages: [AIMessage], system: String?) -> AsyncThrowingStream<String, Error>
}

struct OpenRouterClient: AIAPIClientProtocol {
    let baseURL = "https://openrouter.ai/api/v1/chat/completions"
    let model = "anthropic/claude-sonnet-4-5"
    // apiKey из Keychain (никогда не хардкодим)
}
```

### Streaming для лучшего UX

"Who is?" ответ стримится по токенам — пользователь видит ответ в реальном времени, не ждёт полного ответа. Это значительно улучшает ощущение от фичи.

---

## 5. RAG-пайплайн — исправленная позиция

### Проблема с characterOffset

В черновике использовался единый `characterOffset: Int` — абсолютная позиция в тексте книги. Это не работает для EPUB: каждая глава — отдельный HTML-файл, нет единого текстового потока. Считать "суммарный offset" через все главы — хрупко и избыточно.

### Правильное решение: (chapterIndex, chunkIndex)

```
Позиция пользователя: chapterIndex=5, positionInChapter=0.43
    │
RAGRetriever
    ├── фильтр 1: AIChunk WHERE chapterIndex < 5       → всё до текущей главы
    ├── фильтр 2: AIChunk WHERE chapterIndex = 5
    │                        AND chunkIndex <= (0.43 * totalChunksInChapter5)
    │                                                   → прочитанная часть главы
    └── объединяем, ищем упоминания запрошенного имени
        (localizedStandardContains для регистронезависимого поиска)
```

### Индексирование

```
BookImportService
    └── [async, background Task] → RAGIndexer
            │
            ├── читает книгу по главам (EPUBParser / TXTParser / FB2Parser)
            ├── делит каждую главу на чанки по абзацам (~300 символов)
            ├── сохраняет AIChunk(bookId, chapterIndex, chunkIndex, text)
            └── book.isIndexed = true
```

### Who is? — полный flow

```
Долгий тап на "Фродо" → "Who is?"
    │
    ├── берём: name="Фродо", chapterIndex, positionInChapter из ReaderViewModel
    │
RAGRetriever
    ├── запрос в SwiftData (localConfig): чанки до текущей позиции
    ├── localizedStandardContains("Фродо") — регистро/диакритиконезависимо
    ├── берём топ-15 чанков (приоритет: ближе к текущей позиции)
    └── собираем context string
    │
AIPromptBuilder
    ├── system: "Ты помощник читателя. Отвечай строго по тексту.
    │           Информация за пределами контекста тебе недоступна.
    │           Не упоминай факты о персонаже, которых нет в тексте."
    └── user: "Кто такой Фродо? [context]"
    │
OpenRouterClient.stream() → AsyncThrowingStream<String>
    │
WhoIsPopupView
    └── показывает токены по мере поступления (streaming UI)
```

### Саммари главы

```
Меню главы → "Саммари"
    │
    ├── есть ChapterSummary в SwiftData? → показать кэш
    │
    └── нет → берём полный текст главы
              → OpenRouterClient.complete()
              → сохранить ChapterSummary (синхронизируется на другие устройства)
              → показать в ChapterSummarySheet
```

---

## 6. EPUB в WKWebView — правильная загрузка

### Проблема

EPUB-глава — HTML-файл, который ссылается на CSS, шрифты и изображения через относительные пути. Если загрузить просто как HTML-строку — ассеты не подтянутся.

### Решение: loadFileURL + временная директория

```
EPUBParser
    ├── распаковывает EPUB в /tmp/{bookId}/ (ZIPFoundation)
    ├── парсит OPF-манифест → список глав в порядке чтения
    └── парсит NCX/NAV → оглавление (Chapter[])

EPUBReaderView (WKWebView)
    ├── loadFileURL(chapterURL, allowingReadAccessTo: bookTempDir)
    │   — WKWebView видит всю папку, относительные пути работают
    ├── после загрузки инжектирует CSS-оверрайд для темы:
    │   evaluateJavaScript("document.body.style.background = '\(theme.bg)'...")
    └── JS-bridge (WKScriptMessageHandler) для:
        ├── scroll offset → прогресс в главе
        ├── выделенный текст → контекстное меню с "Who is?"
        └── tap на пустом месте → show/hide ReaderControlsView
```

### Кастомное контекстное меню в WKWebView

iOS 16+ предоставляет `UIEditMenuInteraction`. Для "Who is?" — инжектируем JS, который перехватывает selection и вызывает Swift через message handler. Это стандартный подход в reader-приложениях.

---

## 7. Рендеринг форматов

### TXT / FB2 → TextKit 2

```
TextReaderView (UIViewRepresentable → UITextView)
    ├── FB2Parser / TXTParser → [Chapter] с NSAttributedString
    ├── TextKit 2 (NSTextLayoutManager) — эффективен для больших текстов
    ├── тема применяется через NSAttributedString + backgroundColor
    └── нативное контекстное меню расширяется через UIMenuController:
        добавляем "Who is?" как UIAction
```

### PDF → PDFKit

```
PDFReaderView (PDFView в UIViewRepresentable)
    ├── as-is рендеринг
    ├── прогресс = currentPage / pageCount
    └── нет AI, нет тем, нет рефлоу
```

---

## 8. Sign in with Apple — уточнение роли

**CloudKit и Sign in with Apple — независимые системы.**

- **CloudKit private database** работает через iCloud-аккаунт устройства автоматически. Sign in with Apple для этого не нужен.
- **Sign in with Apple** — для идентификации пользователя на уровне приложения: показать имя в настройках, связать данные с конкретным человеком (актуально когда появится бэкенд).

В v1 Sign in with Apple нужен только для раздела "Аккаунт" в настройках. Синхронизация работает без него. Поэтому он корректно стоит в конце Phase 5.

---

## 9. Навигация

```
App Launch
│
├── [Первый запуск] → OnboardingView → MainTabView
└── [Повторный] → MainTabView
        │
        ├── Tab: Библиотека
        │   NavigationStack
        │   ├── LibraryView (grid / list + поиск)
        │   ├── → BookDetailView
        │   └── → ReaderContainerView (.fullScreenCover)
        │           ├── EPUBReaderView / TextReaderView / PDFReaderView
        │           ├── ReaderControlsView (top + bottom, auto-hide)
        │           ├── [.sheet] ReaderSettingsSheet
        │           ├── [.sheet] TableOfContentsView
        │           ├── [.sheet] BookmarksPanelView
        │           ├── [.sheet] NotesPanelView
        │           ├── [overlay] WhoIsPopupView   ← не sheet, поверх текста
        │           └── [.sheet] ChapterSummarySheet
        │
        ├── Tab: Статистика
        │   NavigationStack
        │   └── StatisticsView
        │       ├── ReadingChartView (bar chart, дни недели)
        │       ├── ActivityGridView (GitHub heatmap, месяц/год)
        │       ├── Streaks & рекорды
        │       └── GoalsView
        │
        └── Tab: Настройки
            NavigationStack
            ├── SettingsView
            ├── AppearanceSettingsView (темы, шрифты)
            ├── SubscriptionView (trial, plans, restore)
            └── AccountView (Sign in with Apple)
```

---

## 10. Система тем

```swift
struct ReaderTheme: Identifiable, Codable {
    let id: String
    let name: String
    let backgroundColor: Color
    let textColor: Color
    let cssOverride: String     // инжектируется в WKWebView
    let isPremium: Bool
}

// Бесплатные
static let light   = ReaderTheme(id: "light",   isPremium: false, ...)
static let dark    = ReaderTheme(id: "dark",    isPremium: false, ...)
static let sepia   = ReaderTheme(id: "sepia",   isPremium: false, ...)

// Premium
static let midnight = ReaderTheme(id: "midnight", isPremium: true, ...)
static let forest   = ReaderTheme(id: "forest",   isPremium: true, ...)
// + custom (color picker)

// Выбранная тема — @AppStorage, не SwiftData
@AppStorage("selectedThemeId") var selectedThemeId: String = "light"
```

---

## 11. Структура проекта

```
WIReader/
│
├── WIReaderApp.swift               # @main, ModelContainer (2 configs), DI setup
├── AppState.swift                  # @Observable, глобальное состояние
│
├── Core/
│   ├── Extensions/
│   │   ├── Color+Hex.swift
│   │   ├── Date+Relative.swift
│   │   └── View+If.swift
│   ├── Constants/
│   │   ├── AppConstants.swift      # bundle ID, iCloud container ID, product IDs
│   │   └── APIConstants.swift      # OpenRouter base URL, model name
│   └── Utils/
│       ├── AppLogger.swift
│       └── ErrorTypes.swift
│
├── Data/
│   ├── Models/                     # все SwiftData @Model классы
│   │   ├── Book.swift
│   │   ├── ReadingProgress.swift
│   │   ├── Bookmark.swift
│   │   ├── Note.swift
│   │   ├── ReadingSession.swift
│   │   ├── ReadingGoal.swift
│   │   ├── BookCollection.swift
│   │   ├── ChapterSummary.swift
│   │   └── AIChunk.swift           # local-only config
│   └── Repositories/
│       ├── BookRepository.swift
│       ├── ProgressRepository.swift
│       ├── StatisticsRepository.swift
│       └── AIRepository.swift
│
├── Services/
│   ├── Import/
│   │   ├── BookImportService.swift
│   │   ├── FileStorageService.swift  # iCloud Ubiquitous Container
│   │   ├── EPUBParser.swift
│   │   ├── FB2Parser.swift
│   │   └── TXTParser.swift
│   ├── AI/
│   │   ├── AIAPIClient.swift         # протокол
│   │   ├── OpenRouterClient.swift    # реализация
│   │   ├── RAGIndexer.swift
│   │   ├── RAGRetriever.swift
│   │   └── AIPromptBuilder.swift
│   ├── Reading/
│   │   ├── ReadingSessionTracker.swift
│   │   └── ProgressCalculator.swift
│   ├── Statistics/
│   │   └── StatisticsService.swift
│   └── Subscription/
│       └── SubscriptionManager.swift  # StoreKit 2
│
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── OnboardingViewModel.swift
│   ├── Library/
│   │   ├── Views/
│   │   │   ├── LibraryView.swift
│   │   │   ├── BookGridView.swift
│   │   │   ├── BookCardView.swift
│   │   │   ├── BookDetailView.swift
│   │   │   ├── CollectionView.swift
│   │   │   └── LibrarySearchView.swift
│   │   └── ViewModels/
│   │       ├── LibraryViewModel.swift
│   │       └── BookDetailViewModel.swift
│   ├── Reader/
│   │   ├── Views/
│   │   │   ├── ReaderContainerView.swift
│   │   │   ├── EPUBReaderView.swift
│   │   │   ├── TextReaderView.swift
│   │   │   ├── PDFReaderView.swift
│   │   │   ├── ReaderControlsView.swift
│   │   │   ├── ReaderSettingsSheet.swift
│   │   │   └── Panels/
│   │   │       ├── TableOfContentsView.swift
│   │   │       ├── BookmarksPanelView.swift
│   │   │       └── NotesPanelView.swift
│   │   └── ViewModels/
│   │       └── ReaderViewModel.swift
│   ├── AI/
│   │   ├── Views/
│   │   │   ├── WhoIsPopupView.swift
│   │   │   └── ChapterSummarySheet.swift
│   │   └── ViewModels/
│   │       └── AIViewModel.swift
│   ├── Statistics/
│   │   ├── Views/
│   │   │   ├── StatisticsView.swift
│   │   │   ├── ReadingChartView.swift
│   │   │   ├── ActivityGridView.swift
│   │   │   └── GoalsView.swift
│   │   └── ViewModels/
│   │       └── StatisticsViewModel.swift
│   └── Settings/
│       ├── Views/
│       │   ├── SettingsView.swift
│       │   ├── AppearanceSettingsView.swift
│       │   └── SubscriptionView.swift
│       └── ViewModels/
│           └── SettingsViewModel.swift
│
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.strings
    └── Fonts/
```

---

## 12. Внешние зависимости

| Библиотека | Назначение |
|-----------|-----------|
| **ZIPFoundation** | Распаковка EPUB (ZIP) |

Всё остальное — Apple frameworks: SwiftData, CloudKit, PDFKit, StoreKit 2, WKWebView, TextKit 2, BackgroundTasks.

Нет Alamofire, нет Combine, нет RxSwift. Только async/await + @Observable.

---

## 13. Ключевые принципы

- **Offline-first**: всё работает без сети, синк в фоне
- **Async/await везде**: никакого completion-hell
- **@Observable вместо ObservableObject**: iOS 17+, чище
- **AI за протоколом AIAPIClientProtocol**: смена Claude → Apple Foundation Models = замена одного файла
- **SubscriptionManager.isActive — единственный гейт**: одна точка проверки подписки
- **UserDefaults для настроек, SwiftData для данных**: правильное разделение
- **Graceful degradation**: нет iCloud → работаем локально; нет сети → нет AI, но чтение работает

---

## 14. Phase Plan (исправленный)

### Phase 1 — Ядро и чтение
1. Проект, структура папок, AppConstants
2. SwiftData модели + два ModelConfiguration (synced + local)
3. FileStorageService (iCloud Ubiquitous Container)
4. EPUBParser (ZIPFoundation + OPF + NCX)
5. BookImportService
6. LibraryView + LibraryViewModel
7. EPUBReaderView (WKWebView + loadFileURL, базовый)
8. ReaderViewModel (прогресс, позиция)

### Phase 2 — Полноценное чтение
9. TXT/FB2 парсеры + TextReaderView (TextKit 2)
10. PDFReaderView (PDFKit)
11. ReaderControlsView (top/bottom bar, auto-hide)
12. ReaderSettingsSheet (темы, шрифты, размер) + @AppStorage
13. TableOfContentsView, BookmarksPanelView, NotesPanelView
14. Автоскролл, автоперелистывание

### Phase 3 — AI
15. **SubscriptionManager (StoreKit 2)** ← нужен здесь, до AI
16. OpenRouterClient (streaming)
17. RAGIndexer + BackgroundTasks (BGProcessingTask)
18. RAGRetriever (chapterIndex + chunkIndex фильтрация)
19. AIPromptBuilder
20. WhoIsPopupView (streaming) + контекстное меню
21. ChapterSummarySheet

### Phase 4 — Геймификация
22. ReadingSessionTracker
23. StatisticsService
24. StatisticsView + ReadingChartView (Swift Charts)
25. ActivityGridView (heatmap)
26. GoalsView + Streaks

### Phase 5 — Финал
27. Onboarding + trial flow
28. Sign in with Apple (AccountView)
29. Paywall UI для AI и premium тем
30. App Store: иконка, скриншоты, описание, privacy policy
