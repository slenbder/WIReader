# WIReader — Константы и статус setup
> Заполнено 9 июня 2026 | держать в Project Knowledge
> Это содержимое AppConstants.swift и APIConstants.swift (задача 0.4)

---

## Лист констант

```
APP_NAME:                  WIReader
BUNDLE_ID:                 com.slenbder.wireader
DISPLAY_NAME:              WIReader

iCLOUD_CONTAINER:          iCloud.com.slenbder.wireader
APP_GROUP:                 group.com.slenbder.wireader

STOREKIT_PRODUCT_MONTHLY:  com.slenbder.wireader.premium.monthly
STOREKIT_PRODUCT_YEARLY:   com.slenbder.wireader.premium.yearly

DEPLOYMENT_TARGET:         iOS 17.0
OPENROUTER_MODEL:          anthropic/claude-sonnet-4-5

APPLE_TEAM_ID:             ⏳ pending (enrollment отложен)
```

---

## Окружение

```
Mac:           MacBook Pro M3 Pro (Apple Silicon ✓)
Тестовое устр: iPhone 17 Pro Max
macOS:         последняя (Tahoe ✓)
Xcode:         последняя (26.3+ ✓)
```

**Следствие:** нативный AI-агент в Xcode доступен. Гибридный воркфлоу
работает: терминальный CLI как основной драйвер + Xcode-агент с визуальной
верификацией превью для UI-задач (Phase 1.7, Phase 2 ридер/темы, Phase 4 графики).

---

## Статус и что осталось

| Пункт | Статус |
|-------|--------|
| Bundle ID | ✓ решён: com.slenbder.wireader |
| Название | ✓ WIReader (рабочее = финальное) |
| Окружение | ✓ всё последнее, топовое железо |
| OpenRouter аккаунт | ✓ есть, ⏳ залить баланс (пару дней; нужен только в Phase 3) |
| Apple Developer | ⏳ enrollment отложен |

---

## Что значит "Apple Developer отложен" для старта

CloudKit, App Groups, Sign in with Apple, тест покупок на устройстве —
заблокированы до enrollment. Но старт это НЕ блокирует.

**Можешь делать сейчас (на локальном хранилище, personal team):**
- 0.1 Создать проект
- 0.3 Структура + ZIPFoundation
- 0.4 Core слой (этот лист констант → AppConstants/APIConstants)
- 1.1 SwiftData модели
- 1.4 EPUBParser
- 1.5 BookImportService
- 1.6 BookRepository
- 1.7 LibraryView
- 1.8 EPUBReaderView
- 1.10 BookDetailView

**Ждёт enrollment:**
- 0.2 Capabilities (iCloud, CloudKit, App Groups)
- 1.2 ModelContainer с CloudKit-синком (локальную версию можно сделать раньше, переключить потом)
- 1.3 FileStorageService для iCloud (локальный fallback можно раньше)
- 1.9 Синхронизация прогресса (логику можно, проверку синка — после)

**Практический путь:** начинаешь Phase 0-1 на локальном SwiftData (config
`.none` вместо `.automatic`). Когда аккаунт активен — включаешь CloudKit:
меняешь конфигурацию контейнера, добавляешь capabilities. Это небольшая
правка, не переделка.

⚠️ Запиши enrollment пораньше — он занимает время, а понадобится для всего
ядра синхронизации.

---

## Последовательность старта (твоя)

```
СЕЙЧАС:
1. ✓ Bundle ID, название, окружение — готово
2. Записаться в Apple Developer (параллельно, не ждём)
3. Положить в проект: CLAUDE.md + docs/ (PRD, Architecture,
   TaskBreakdown, Workflow, DecisionLog)
4. → Phase 0.1: создать проект (personal team)
5. → git init + .gitignore
6. → Phase 0.3, 0.4 (этот лист → AppConstants/APIConstants)
7. → Phase 1.1, 1.4–1.8, 1.10 (локально, без CloudKit)

ЧЕРЕЗ ПАРУ ДНЕЙ:
8. OpenRouter — залить баланс (понадобится в Phase 3)
9. Apple Developer активен → включить CloudKit:
   Phase 0.2, 1.2 (CloudKit), 1.3 (iCloud), 1.9 (проверка синка)
```

---

## .gitignore — обязательные строки

Чтобы не утёк ключ и не засорять репо:

```
# Secrets
*.env
Secrets.swift
APIKeys.plist

# Xcode
DerivedData/
*.xcuserstate
.DS_Store
build/
```

API-ключ OpenRouter — никогда в репозиторий. В приложении только Keychain.
