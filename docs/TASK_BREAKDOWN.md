# WIReader — Task Breakdown
> Рабочий документ для исполнения в Claude Code | основан на Architecture v2.0

---

## Как пользоваться этим документом

Каждая задача — самодостаточный блок для одной сессии Claude Code. Workflow:

1. Берёшь следующую незакрытую задачу
2. Копируешь её содержимое как контекст в Claude Code
3. Claude Code реализует
4. Проверяешь по критерию "Готово когда"
5. Отмечаешь `[x]` и идёшь дальше

**Правила:**
- Не прыгай через задачи — зависимости важны
- Если задача ломает предыдущую — стоп, возвращаешься сюда обсудить
- Каждая задача должна компилироваться перед тем как двигаться дальше
- Сложные решения внутри задачи — сверяемся здесь, в Claude.ai

---

## Phase 0 — Setup проекта

### [x] 0.1 — Xcode проект
**Что делаем:** создаём проект, настраиваем базовые параметры.
**Требования:**
- iOS 17.0 минимум
- SwiftUI lifecycle (App-based, не Storyboard)
- Bundle ID и название — из pre-flight чеклиста
- Interface: SwiftUI, Language: Swift
**Готово когда:** проект собирается, запускается пустой экран на симуляторе.

### [x] 0.2 — Capabilities и entitlements
**Что делаем:** включаем нужные возможности в Signing & Capabilities.
**Требования:**
- iCloud → CloudKit (создать контейнер `iCloud.{bundleID}`)
- iCloud → iCloud Documents (для Ubiquitous Container)
- Background Modes → Background processing (для RAG-индексирования)
- App Groups (на будущее для виджета) — `group.{bundleID}`
**Готово когда:** entitlements-файл содержит все capabilities, проект собирается с подписью.

### [x] 0.3 — Структура папок + ZIPFoundation
**Что делаем:** создаём структуру папок из архитектуры, добавляем единственную зависимость.
**Требования:**
- Папки: Core, Data, Services, Features, Resources (по дереву из Architecture §11)
- Swift Package Manager → добавить ZIPFoundation
**Готово когда:** структура папок создана, ZIPFoundation импортируется без ошибок.

### [x] 0.4 — Core слой
**Что делаем:** базовые расширения, константы, утилиты.
**Файлы:** `Color+Hex.swift`, `Date+Relative.swift`, `View+If.swift`, `AppConstants.swift`, `APIConstants.swift`, `AppLogger.swift`, `ErrorTypes.swift`
**Требования:**
- `AppConstants`: bundle ID, iCloud container ID, App Group ID, StoreKit product IDs
- `APIConstants`: OpenRouter base URL, model name (`anthropic/claude-sonnet-4-5`)
- `ErrorTypes`: enum для ошибок импорта, AI, sync
**Готово когда:** всё компилируется, константы доступны глобально.

---

## Phase 1 — Ядро и базовое чтение

### [x] 1.1 — SwiftData модели
**Что делаем:** все @Model классы по Architecture §3.
**Файлы:** `Book.swift`, `ReadingProgress.swift`, `Bookmark.swift`, `Note.swift`, `ReadingSession.swift`, `ReadingGoal.swift`, `BookCollection.swift`, `ChapterSummary.swift`, `AIChunk.swift`
**Требования (КРИТИЧНО для CloudKit):**
- ВСЕ свойства optional или с default value
- `@Attribute(.unique) var id: UUID = UUID()` на каждой модели
- Связи через `@Relationship`, коллекции с `= []`
- `format`, `type` как String (не enum) для CloudKit-совместимости
**Готово когда:** модели компилируются, нет non-optional свойств без дефолтов.

### [x] 1.2 — ModelContainer с двумя конфигурациями
**Что делаем:** настраиваем контейнер: synced (CloudKit) + local (AIChunk).
**Файлы:** `WIReaderApp.swift`
**Требования:**
- `syncedConfig` с `cloudKitDatabase: .automatic` для 8 моделей
- `localConfig` с `cloudKitDatabase: .none` для AIChunk
- Оба в одном `ModelContainer` (см. Architecture §3, "Инициализация контейнера")
- `.modelContainer(container)` на корневом View
**Готово когда:** приложение запускается, контейнер инициализируется без краша, в CloudKit Dashboard появляется схема.

### [x] 1.3 — FileStorageService
**Что делаем:** сервис работы с файлами книг в iCloud Ubiquitous Container.
**Файлы:** `FileStorageService.swift`
**Требования:**
- Получение `ubiquityContainerURL` (с fallback на локальную директорию если iCloud недоступен)
- `save(fileURL:) -> String` (возвращает fileName)
- `url(for fileName:) -> URL`
- `delete(fileName:)`
- Graceful degradation: нет iCloud → работаем локально
**Готово когда:** можно сохранить файл, получить его URL, удалить. Тестируется юнит-тестом или временной кнопкой.

### [x] 1.4 — EPUBParser
**Что делаем:** парсер EPUB — распаковка, метаданные, главы, оглавление, обложка.
**Файлы:** `EPUBParser.swift`, модель `EPUBChapter`, `ParsedBook`
**Требования:**
- Распаковка ZIP в `/tmp/{bookId}/` через ZIPFoundation
- Парсинг `container.xml` → путь к OPF
- Парсинг OPF: метаданные (title, author), spine (порядок глав), обложка
- Парсинг NCX или NAV → оглавление
- Возврат `ParsedBook(title, author, coverData, chapters: [EPUBChapter], tempDir: URL)`
**Готово когда:** на тестовом EPUB извлекаются корректные метаданные и список глав в правильном порядке.

### [x] 1.5 — BookImportService
**Что делаем:** оркестратор импорта — связывает парсер, файловое хранилище и SwiftData.
**Файлы:** `BookImportService.swift`
**Требования:**
- Определение формата по расширению
- EPUB: вызов EPUBParser → сохранение файла → создание Book в SwiftData
- Заглушки для TXT/FB2/PDF (реализуем в Phase 2)
- Если метаданных нет — title = имя файла
- НЕ запускает RAG-индексацию пока (Phase 3)
**Готово когда:** импорт EPUB создаёт Book в базе с обложкой и метаданными.

### [x] 1.6 — BookRepository
**Что делаем:** слой доступа к данным книг поверх SwiftData.
**Файлы:** `BookRepository.swift`
**Требования:**
- `fetchAll() -> [Book]`, `fetch(by id:)`, `delete(_:)`, `search(query:)`
- `@MainActor`, работа с `ModelContext`
- Удаление книги = удаление файла (через FileStorageService) + каскад в SwiftData
**Готово когда:** CRUD по книгам работает через репозиторий.

### [x] 1.7 — LibraryView + LibraryViewModel
**Что делаем:** главный экран библиотеки.
**Файлы:** `LibraryView.swift`, `BookGridView.swift`, `BookCardView.swift`, `LibraryViewModel.swift`
**Требования:**
- `@Observable` ViewModel
- Сетка/список книг с обложками (toggle между видами)
- Кнопка импорта → `.fileImporter` (Files picker)
- Поиск по библиотеке
- Пустое состояние ("Добавьте первую книгу")
**Готово когда:** видно список импортированных книг, работает импорт через Files, работает поиск.

### [x] 1.8 — ReaderContainerView + EPUBReaderView (базовый)
**Что делаем:** контейнер ридера + базовый EPUB-рендер без тем.
**Файлы:** `ReaderContainerView.swift`, `EPUBReaderView.swift`, `ReaderViewModel.swift`
**Требования:**
- `ReaderContainerView` выбирает рендерер по `book.format` (пока только EPUB)
- `EPUBReaderView`: UIViewRepresentable → WKWebView
- Загрузка через `loadFileURL(_:allowingReadAccessTo:)` (см. Architecture §6)
- Навигация между главами (вперёд/назад)
- Открывается через `.fullScreenCover` из BookDetailView
**Готово когда:** EPUB открывается, текст читается, можно листать главы, ассеты (изображения) грузятся.

### [x] 1.9 — Прогресс чтения (EPUB)
**Что делаем:** отслеживание и сохранение позиции чтения.
**Файлы:** `ProgressCalculator.swift`, обновление `ReaderViewModel`, `ProgressRepository.swift`
**Требования:**
- JS-bridge в WKWebView: scroll offset → positionInChapter
- Вычисление overallProgress (глава + позиция в главе)
- Сохранение ReadingProgress в SwiftData при изменении (throttled)
- При повторном открытии — возврат на сохранённую позицию
**Готово когда:** закрыл книгу на середине, открыл снова — вернулся на то же место. Прогресс синхронизируется (проверить на втором устройстве/симуляторе).

### [x] 1.10 — BookDetailView
**Что делаем:** экран книги перед чтением.
**Файлы:** `BookDetailView.swift`, `BookDetailViewModel.swift`
**Требования:**
- Обложка, название, автор, прогресс
- Кнопка "Читать" / "Продолжить" → открывает ReaderContainerView
- Кнопка удаления книги
**Готово когда:** тап на книгу → детали → "Читать" открывает ридер.

---

## Phase 2 — Полноценное чтение

### [x] 2.1 — TXTParser + FB2Parser
**Что делаем:** парсеры для TXT и FB2.
**Файлы:** `TXTParser.swift`, `FB2Parser.swift`
**Требования:**
- TXT: разбивка на "главы" по размеру или по двойным переносам, `NSAttributedString`
- FB2: парсинг XML (XMLParser), извлечение метаданных из `<description>`, тело из `<body>`, главы из `<section>`
- Оба возвращают тот же `ParsedBook` контракт что EPUBParser
**Готово когда:** TXT и FB2 импортируются, метаданные FB2 корректны.

### [x] 2.2 — TextReaderView (TextKit 2)
**Что делаем:** рендер для TXT/FB2.
**Файлы:** `TextReaderView.swift`
**Требования:**
- UIViewRepresentable → UITextView с TextKit 2 (`NSTextLayoutManager`)
- Вертикальный скролл
- Применение прогресса (как в 1.9)
- Интеграция в ReaderContainerView
**Готово когда:** TXT и FB2 читаются, прогресс сохраняется.

### [x] 2.3 — PDFReaderView
**Что делаем:** рендер PDF.
**Файлы:** `PDFReaderView.swift`
**Требования:**
- UIViewRepresentable → PDFView (PDFKit)
- Прогресс = currentPage / pageCount
- Интеграция в ReaderContainerView
- Без AI, без тем (по PRD)
**Готово когда:** PDF открывается, листается, прогресс по страницам сохраняется.
**Проверено:** ручной тест в симуляторе на реальном PDF: PDF открывается, page-based progress обновляет preview, сохраняется и восстанавливается при повторном открытии. Текущий UX — vertical continuous scrolling; это принято для 2.3.

### [x] 2.4 — Система тем + @AppStorage
**Что делаем:** темы ридера и их хранение.
**Файлы:** `ReaderTheme.swift`, обновление рендереров
**Требования:**
- `ReaderTheme` struct (Architecture §10): light, dark, sepia (free) + midnight, forest (premium)
- `@AppStorage("selectedThemeId")`
- EPUB: инъекция CSS-оверрайда в WKWebView
- TextReaderView: применение через NSAttributedString + backgroundColor
- Premium-темы помечены `isPremium`, пока без гейта (гейт в Phase 3)
**Готово когда:** переключение тем меняет вид во всех текстовых рендерерах, выбор сохраняется между запусками.
**Проверено:** `ReaderTheme` реализован с темами light, dark, sepia, midnight и forest; midnight/forest — premium metadata only, без subscription gate. Выбор темы хранится через `@AppStorage("selectedThemeId")`. EPUB применяет темы через CSS injection; `didFinish`/reapply restore behavior сохранён. TextReader применяет темы через TextKit 2; G10 restore semantics сохранены. PDF намеренно не изменялся и проверен как unaffected. Ручная проверка в симуляторе прошла для EPUB, TXT, FB2 и PDF unaffected. Build succeeded. Review completed with no High findings.

### [x] 2.5 — ReaderSettingsSheet
**Что делаем:** панель настроек чтения.
**Файлы:** `ReaderSettingsSheet.swift`
**Требования:**
- Выбор темы (превью)
- Размер шрифта (slider)
- Выбор шрифта (несколько вариантов)
- Межстрочный интервал, отступы
- Всё через @AppStorage, применяется вживую
**Готово когда:** открывается из ридера, изменения применяются мгновенно и сохраняются.
**Проверено:** ReaderSettingsSheet MVP реализован: theme picker with previews, font size, line spacing, reader margins, TXT/FB2 font selection. Settings persist via `@AppStorage` and apply live. EPUB typography intentionally unchanged for Task 2.5; EPUB themes continue to work and `didFinish`/reapply behavior is preserved. PDF rendering intentionally unchanged. TextReader G10 restore semantics preserved. Manual simulator testing passed for EPUB, TXT, FB2, and PDF. Build succeeded. `/review` found no blocking issues.

### [x] 2.6 — ReaderControlsView
**Что делаем:** верхняя и нижняя панели управления в ридере.
**Файлы:** `ReaderControlsView.swift`
**Требования:**
- Top bar: назад, название книги, кнопки (оглавление, настройки, закладки, заметки)
- Bottom bar: прогресс-бар, % прочитано, номер главы
- Auto-hide по тапу на текст (через JS-bridge для EPUB)
**Готово когда:** тап показывает/прячет контролы, кнопки открывают нужные панели.
**Проверено:** ReaderControlsView implemented with top and bottom control bars. Auto-hide works for reader controls, including EPUB through the fixed WKWebView tap bridge. Manual simulator verification passed for EPUB, TXT, FB2, and PDF. `/review` found no blocking issues.

### [x] 2.7 — TableOfContentsView
**Что делаем:** оглавление с переходом.
**Файлы:** `TableOfContentsView.swift`
**Требования:**
- Список глав из ParsedBook
- Тап → переход к главе
- Подсветка текущей главы
**Готово когда:** оглавление открывается, переход по главам работает.
**Проверено:** TableOfContentsView implemented and opened from the ReaderControlsView TOC button. It lists chapters from ReaderViewModel, highlights the current chapter with accent color, semibold text, and checkmark, and selecting a chapter calls `goToChapter(index)` and dismisses the sheet. PDF keeps the TOC button visible but disabled. Build succeeded. `/review` found no blocking issues. Manual simulator verification passed for EPUB, TXT, FB2, and PDF behavior.

### [x] 2.8 — Закладки
**Что делаем:** создание и навигация по закладкам.
**Файлы:** `BookmarksPanelView.swift`, обновление ReaderViewModel
**Требования:**
- Добавить закладку на текущей позиции
- Список закладок → тап → переход
- Удаление
- Сохранение в SwiftData (синхронизируется)
**Готово когда:** закладки создаются, переход работает, синхронизируются между устройствами.
**Проверено:** BookmarkRepository added, BookmarksPanelView implemented, and ReaderControlsView bookmark button connected. Positional bookmarks use `chapterIndex + positionInChapter`, not chapter-only navigation. `ReaderViewModel.goToPosition(chapterIndex:positionInChapter:)` added as the canonical positional navigation primitive; `goToChapter` remains chapter-start navigation while bookmarks use `goToPosition`. EPUB/Text live bookmark navigation fixed by moving live restore handling into renderer update paths. PDF bookmarks verified working. Build succeeded. `/review` found no blocking issues. Manual simulator verification passed for EPUB, TXT, FB2, and PDF behavior.

### [x] 2.9 — Заметки
**Что делаем:** заметки с привязкой к выделенному тексту.
**Файлы:** `NotesPanelView.swift`, обновление контекстного меню
**Требования:**
- Выделение текста → контекстное меню → "Заметка"
- Ввод текста заметки, привязка к позиции и selectedText
- Список заметок → тап → переход
- Сохранение в SwiftData (синхронизируется)
**Готово когда:** заметка создаётся из выделения, отображается в списке, переход работает.
**Проверено:** NoteRepository, ReaderTextSelection, and NotesPanelView added; ReaderControlsView notes button connected. Notes persist canonical `chapterIndex + positionInChapter` and navigate via `goToPosition(chapterIndex:positionInChapter:)`. TXT/FB2 use the native text-selection menu; EPUB uses a safe MVP selection overlay/action; PDF note creation is deferred. The selected-text presentation race was fixed with `sheet(item:)` and an immutable selection payload. TXT/FB2 selection position mapping was corrected. Stale EPUB selections are prevented by carrying `chapterIndex` in ReaderTextSelection and filtering callbacks from non-current chapters. Note add/delete failures are logged, rolled back, surfaced to the user, and no longer treated as success. Build succeeded, `git diff --check` passed, and `/review` found no High or Medium issues after fixes. Manual simulator verification passed for EPUB, TXT, FB2, and unchanged PDF behavior.

### [ ] 2.10 — Постраничный режим (EPUB + TXT/FB2)
**Что делаем:** горизонтальное постраничное перелистывание как альтернатива вертикальному скроллу. Переключение режима — настройка ридера (@AppStorage).
**Файлы:** обновление `EPUBReaderView`, `TextReaderView`, `ReaderContainerView`, настройки
**Требования:**
- EPUB: CSS multi-column пагинация в WKWebView (стандартная техника reader-приложений), горизонтальный paging
- TXT/FB2: пагинация TextKit 2 (NSTextLayoutManager, постраничный layout)
- КРИТИЧНО: хранимая позиция остаётся positionInChapter (доля 0.0–1.0), номер страницы — производная от позиции под текущий layout. Страница НЕ хранится (зависит от шрифта/экрана/reflow). Сохранение позиции — на каждый флип страницы (дискретно, без throttle)
- Переключение скролл ↔ страницы сохраняет место чтения (одна каноническая позиция, два отображения)
- Учесть поздний reflow EPUB (границы страниц могут сдвинуться после открытия — пересчитывать текущую страницу из доли)
**Готово когда:** обе механики перелистывают все текстовые форматы, позиция переживает переключение режимов и перезапуск, prev/next работают на границах глав.

### [ ] 2.11 — Автоскролл и автоперелистывание
**Что делаем:** авторежимы чтения.
**Файлы:** обновление рендереров и ReaderControlsView
**Требования:**
- Автоскролл (для скролл-режима): настраиваемая скорость
- Автоперелистывание (для постраничного): настраиваемый интервал
- Контрол скорости/интервала
- Старт/стоп
**Готово когда:** автоскролл работает плавно, скорость настраивается, легко остановить.

---

## Phase 3 — AI

### [ ] 3.1 — SubscriptionManager (StoreKit 2)
**Что делаем:** управление подпиской. ОБЯЗАТЕЛЬНО до AI-фич — это гейт.
**Файлы:** `SubscriptionManager.swift`
**Требования:**
- StoreKit 2: загрузка продуктов (monthly, yearly)
- `purchase()`, `restore()`
- `var isActive: Bool` — единственная точка проверки
- Слушатель транзакций (`Transaction.updates`)
- StoreKit Configuration File для локального тестирования
**Готово когда:** в тестовом режиме можно "купить" подписку, isActive меняется, restore работает.

### [ ] 3.2 — OpenRouterClient
**Что делаем:** клиент AI API.
**Файлы:** `AIAPIClient.swift` (протокол), `OpenRouterClient.swift`, Keychain-обёртка
**Требования:**
- Протокол `AIAPIClientProtocol`: `complete()` и `stream()`
- OpenAI-совместимый формат (Architecture §4)
- API-ключ из Keychain (НЕ хардкод, НЕ UserDefaults)
- Streaming через `AsyncThrowingStream`
- Обработка ошибок сети, rate limit
**Готово когда:** тестовый запрос к OpenRouter возвращает ответ Claude, streaming работает по токенам.

### [ ] 3.3 — RAGIndexer + BackgroundTasks
**Что делаем:** индексирование книги в чанки.
**Файлы:** `RAGIndexer.swift`, `AIRepository.swift`, регистрация BGTask
**Требования:**
- Деление текста книги на чанки по абзацам (~300 символов)
- Сохранение AIChunk(bookId, chapterIndex, chunkIndex, text) в local-конфиг
- Запуск при импорте (Task) + BGProcessingTask для больших книг
- `book.isIndexed = true` по завершении
- Гейт по подписке (индексируем только если есть смысл — или всегда, но AI-доступ за подпиской)
**Готово когда:** после импорта книга индексируется в фоне, чанки появляются в базе.

### [ ] 3.4 — RAGRetriever
**Что делаем:** поиск релевантных чанков до текущей позиции.
**Файлы:** `RAGRetriever.swift`
**Требования (КРИТИЧНО — правильная позиция):**
- Фильтр по `(chapterIndex, chunkIndex)`, НЕ по characterOffset (Architecture §5)
- chapterIndex < current ИЛИ (chapterIndex == current И chunkIndex <= позиция)
- `localizedStandardContains` для регистронезависимого поиска имени
- Топ-15 чанков по близости к текущей позиции
**Готово когда:** на запрос с именем возвращаются только чанки из прочитанной части, без будущих глав.

### [ ] 3.5 — AIPromptBuilder
**Что делаем:** сборка промптов.
**Файлы:** `AIPromptBuilder.swift`
**Требования:**
- Who is: system-промпт с жёстким анти-спойлер ограничением (Architecture §5)
- Summary: промпт для пересказа главы
- Сборка контекста из чанков
**Готово когда:** промпты собираются корректно, контекст вставляется.

### [ ] 3.6 — WhoIsPopupView + контекстное меню
**Что делаем:** киллерфича целиком.
**Файлы:** `WhoIsPopupView.swift`, `AIViewModel.swift`, обновление контекстных меню
**Требования:**
- Пункт "Who is?" в контекстном меню (EPUB через JS-bridge, TextView через UIMenuController)
- Гейт: нет подписки → paywall вместо ответа
- Overlay поверх текста (НЕ sheet), со скроллом
- Streaming-вывод ответа по токенам
- Связка: выделение → RAGRetriever → PromptBuilder → OpenRouterClient → popup
**Готово когда:** долгий тап на имя → "Who is?" → появляется ответ строго по прочитанному, стримится в реальном времени.

### [ ] 3.7 — ChapterSummarySheet
**Что делаем:** саммари главы.
**Файлы:** `ChapterSummarySheet.swift`
**Требования:**
- Кнопка "Саммари" в меню главы
- Проверка кэша (ChapterSummary в SwiftData) → показать если есть
- Если нет → генерация → сохранение (синхронизируется)
- Гейт по подписке
**Готово когда:** саммари генерируется один раз, при повторном запросе берётся из кэша.

---

## Phase 4 — Геймификация

### [ ] 4.1 — ReadingSessionTracker
**Что делаем:** отслеживание сессий чтения.
**Файлы:** `ReadingSessionTracker.swift`
**Требования:**
- Старт сессии при открытии ридера, стоп при закрытии/уходе в фон
- Подсчёт прочитанных слов и страниц за сессию
- Сохранение ReadingSession в SwiftData
**Готово когда:** каждая сессия чтения записывается с корректными метриками.

### [ ] 4.2 — StatisticsService
**Что делаем:** агрегация статистики.
**Файлы:** `StatisticsService.swift`, `StatisticsRepository.swift`
**Требования:**
- Агрегация ReadingSession по дням/неделям/месяцам/годам
- Подсчёт streak (дней подряд)
- Личные рекорды (макс страниц/день, самый длинный streak)
**Готово когда:** сервис отдаёт корректные данные для графиков по любому периоду.

### [ ] 4.3 — StatisticsView + графики
**Что делаем:** экран статистики.
**Файлы:** `StatisticsView.swift`, `StatisticsViewModel.swift`, `ReadingChartView.swift`
**Требования:**
- Swift Charts: bar chart по дням недели
- Детализация: неделя / месяц / год (переключатель)
- Блок рекордов и текущего streak
**Готово когда:** статистика отображается, переключение периодов работает.

### [ ] 4.4 — ActivityGridView
**Что делаем:** GitHub-style heatmap активности.
**Файлы:** `ActivityGridView.swift`
**Требования:**
- Сетка дней, интенсивность цвета = объём чтения
- Год / месяц
**Готово когда:** heatmap отображает реальную активность чтения.

### [ ] 4.5 — GoalsView + Streaks
**Что делаем:** цели и челленджи.
**Файлы:** `GoalsView.swift`
**Требования:**
- Создание годовой цели (книг/страниц/минут)
- Прогресс к цели
- Ежедневный streak с визуализацией
- Личные челленджи (например "читать N минут в день")
- Только личные цели (без соцэлемента — по PRD)
**Готово когда:** цель создаётся, прогресс обновляется по мере чтения, streak считается.

---

## Phase 5 — Финал

### [ ] 5.1 — OnboardingView
**Что делаем:** приветственные экраны.
**Файлы:** `OnboardingView.swift`, `OnboardingViewModel.swift`
**Требования:**
- Несколько экранов: миссия, киллерфичи (Who is?, цели), trial
- Флаг "онбординг пройден" в @AppStorage
- Возможность импортировать первую книгу из онбординга
**Готово когда:** при первом запуске показывается онбординг, при повторных — нет.

### [ ] 5.2 — Sign in with Apple
**Что делаем:** авторизация для раздела аккаунта.
**Файлы:** `AccountView.swift`, обновление SettingsView
**Требования:**
- `SignInWithAppleButton`
- Хранение credential identifier в Keychain
- Раздел "Аккаунт" в настройках (имя, выход)
- НЕ влияет на синхронизацию (она через iCloud, Architecture §8)
**Готово когда:** вход через Apple работает, имя отображается в настройках.

### [ ] 5.3 — Paywall UI
**Что делаем:** экраны подписки.
**Файлы:** `SubscriptionView.swift`, paywall-компонент
**Требования:**
- Описание premium-фич (AI, premium-темы, расширенная статистика)
- Планы: месяц / год (год со скидкой)
- 14-дневный trial (настраивается в App Store Connect)
- Кнопки покупки + restore
- Триггерится при попытке использовать gated-фичу
**Готово когда:** paywall показывается при тапе на premium-фичу без подписки, покупка проходит в тестовом режиме.

### [ ] 5.4 — App Store подготовка
**Что делаем:** всё для сабмита.
**Требования:**
- Иконка приложения (все размеры)
- Скриншоты для App Store
- Описание, ключевые слова
- Privacy Policy (обязательно — есть сбор данных через iCloud + AI)
- Privacy Nutrition Labels в App Store Connect
- App Store Connect: продукты подписки, trial
**Готово когда:** билд загружен в App Store Connect, прошёл валидацию, готов к ревью.

---

## Сводка по фазам

| Phase | Задач | Результат |
|-------|-------|-----------|
| 0 | 4 | Проект готов к разработке |
| 1 | 10 | EPUB читается, прогресс синхронизируется |
| 2 | 11 | Все форматы, темы, закладки, заметки |
| 3 | 7 | AI-киллерфича работает |
| 4 | 5 | Статистика и геймификация |
| 5 | 4 | Готово к App Store |
| **Итого** | **41** | **Публичный релиз** |

---

## Контрольные точки (milestones)

- **После Phase 1**: можно читать EPUB и прогресс синхронизируется — это уже работающий каркас
- **После Phase 2**: полноценная читалка для всех форматов — уже можно пользоваться самому
- **После Phase 3**: киллерфича на месте — главное конкурентное отличие
- **После Phase 4**: продукт с геймификацией — соответствует миссии
- **После Phase 5**: публичный релиз
