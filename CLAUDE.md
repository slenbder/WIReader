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
- Открыть в Xcode, target: iOS 17 симулятор
- [сюда добавишь команды если соберёшь CLI-сборку]

## Где что искать
@docs/PRD.md
@docs/Architecture.md
@docs/TaskBreakdown.md

## SwiftUI gotchas
- Несколько .fileImporter на одном view-дереве: срабатывает только последний. Вешать на разные узлы дерева.

