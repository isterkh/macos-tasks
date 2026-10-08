# Tasks for macOS

Личный канбан для macOS 26. Доски и колонки создаются вручную; задачи хранятся локально на этом Mac в `~/Library/Application Support/com.isterkh.DailyBoard/`. Описание поведения — в [спецификации](docs/daily-board-spec.md).

## Открыть и собрать

Откройте `DailyBoard.xcodeproj` в Xcode 26.4 или новее и запустите схему `DailyBoard` на Mac. Проект также можно пересоздать из `project.yml` командой `xcodegen generate`.

Если в системе активны только Command Line Tools, для сборки из терминала укажите установленный Xcode:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project DailyBoard.xcodeproj -scheme DailyBoard \
  -derivedDataPath DerivedData build
```

После сборки приложение находится в `DerivedData/Build/Products/Debug/DailyBoard.app`. Запуск: `open DerivedData/Build/Products/Debug/DailyBoard.app`.

## Основные действия

- Создайте доску в боковой панели и колонку кнопкой «Колонка».
- Перетащите колонку за заголовок, чтобы изменить её место на доске; команды «Влево» и «Вправо» есть в меню колонки.
- Добавьте задачу через поле «Быстрая задача» в колонке. Enter сохраняет её.
- Галочка перемещает задачу между группами. Клик по карточке открывает редактор; ⌘-клик выбирает несколько задач, Shift-клик — диапазон в одной колонке.
- Перетащите выбранные карточки в другую колонку или используйте меню действий. Меню колонки содержит перенос и архивирование всех завершённых задач.
- Архив доски открывается кнопкой «Архив». При восстановлении выберите колонку.

Групповые изменения сохраняются через транзакции SwiftData. При ошибке запись откатывается, а приложение показывает сообщение.

## Проверка

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project DailyBoard.xcodeproj -scheme DailyBoard \
  -derivedDataPath DerivedData test
```

Тесты интерфейса используют системное разрешение macOS на управление приложением. При первом запуске тестов подтвердите запрос для тестового runner.
