# WIReader — iOS Reading App

## Что это
iOS-читалка (EPUB/PDF/TXT/FB2) с AI-фичей "Who is?" — справка по
персонажу строго по прочитанному. SwiftUI + MVVM, iOS 17+.

## КОНТРАКТ (не нарушать без явного разрешения)
- SwiftData модели под CloudKit: ВСЕ свойства optional или с default,
  @Attribute(.unique) на id. Иначе краш на синке.
- API-ключи: ТОЛЬКО Keychain. Никогда не хардкод, никогда не UserDefaults.
- Настройки ридера: @AppStorage, НЕ SwiftData.
- RAG-фильтрация позиции: (chapterIndex, chunkIndex), НЕ characterOffset.
- ViewModels: @Observable, НЕ ObservableObject.
- Только async/await. Нет Combine, нет completion handlers.
- Каждая задача должна компилироваться перед переходом к следующей.
- Не добавляй зависимости кроме ZIPFoundation без спроса.
- Каждый файл, использующий AppLogger с интерполяцией, должен импортировать OSLog — импорты в Swift не транзитивны.
- evaluateJavaScript: всегда с completion handler и логированием ошибки. Инжектируемый JS не собирать интерполяцией Swift-строк без крайней необходимости.

## Стек
- SwiftUI + MVVM + Repository
- SwiftData (2 ModelConfiguration: synced CloudKit + local для AIChunk)
- iCloud Ubiquitous Container — файлы книг
- WKWebView (EPUB) / TextKit 2 (TXT, FB2) / PDFKit (PDF)
- OpenRouter, модель anthropic/claude-sonnet-4-5
- StoreKit 2 — подписки

## Структура
Core/ Data/ Services/ Features/ Resources/
Каждая фича: Views/ + ViewModels/
Репозитории: @MainActor.
Имена файлов: PascalCase = имя типа.

## Сборка
- Проверка компиляции из терминала:
xcodebuild -scheme wireader -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -20

ПРАВИЛО: перед тем как предлагать коммит — запусти эту команду
и убедись, что сборка прошла без ошибок.

- Открыть в Xcode, target: iOS 17 симулятор

## Где что искать
@docs/PRD.md
@docs/Architecture.md
@docs/TaskBreakdown.md

## SwiftUI gotchas
- Несколько .fileImporter на одном view-дереве: срабатывает только последний. Вешать на разные узлы дерева.

