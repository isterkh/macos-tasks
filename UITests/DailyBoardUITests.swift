import XCTest

final class DailyBoardUITests: XCTestCase {
    @MainActor
    func testChecklistCanBeEditedAndCheckedOnCard() {
        let app = launchApp()
        app.buttons["Новая доска"].click()
        let boardName = app.textFields["Название"]
        XCTAssertTrue(boardName.waitForExistence(timeout: 5))
        boardName.typeText("Доска")
        app.buttons["Сохранить"].click()
        app.buttons["Колонка"].click()
        let columnName = app.textFields["Название"]
        XCTAssertTrue(columnName.waitForExistence(timeout: 5))
        columnName.typeText("Сегодня")
        app.buttons["Сохранить"].click()

        let quickTask = app.textFields["Быстрая задача"]
        XCTAssertTrue(quickTask.waitForExistence(timeout: 5))
        quickTask.click()
        quickTask.typeText("Задача\n")
        let task = app.staticTexts["Задача"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.click()

        let newItem = app.textFields["Новый пункт"]
        XCTAssertTrue(newItem.waitForExistence(timeout: 5))
        newItem.click()
        newItem.typeText("Шаг один")
        app.buttons["Сохранить"].click()
        let checklistRow = app.buttons["Завершить пункт: Шаг один"]
        XCTAssertTrue(checklistRow.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 из 1"].exists)

        checklistRow.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .withOffset(CGVector(dx: 35, dy: 0)).click()
        XCTAssertTrue(app.staticTexts["1 из 1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["Новый пункт"].exists)
        task.click()
        XCTAssertTrue(app.textFields["Новый пункт"].waitForExistence(timeout: 5))

        let secondItem = app.textFields["Новый пункт"]
        secondItem.click()
        secondItem.typeText("Шаг два")
        app.buttons["Добавить"].click()
        let firstHandle = app.images["Перетащить пункт: Шаг один"]
        let secondHandle = app.images["Перетащить пункт: Шаг два"]
        XCTAssertTrue(firstHandle.waitForExistence(timeout: 5))
        XCTAssertTrue(secondHandle.waitForExistence(timeout: 5))
        firstHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.3, thenDragTo: secondHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))

        let firstField = app.textFields.matching(NSPredicate(format: "value == %@", "Шаг один")).firstMatch
        let secondField = app.textFields.matching(NSPredicate(format: "value == %@", "Шаг два")).firstMatch
        XCTAssertLessThan(secondField.frame.midY, firstField.frame.midY)
        app.buttons["Сохранить"].click()
        task.click()
        XCTAssertLessThan(secondField.frame.midY, firstField.frame.midY)

        firstHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.3, thenDragTo: secondHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
        XCTAssertLessThan(firstField.frame.midY, secondField.frame.midY)
        app.buttons["Отмена"].click()
        task.click()
        XCTAssertLessThan(secondField.frame.midY, firstField.frame.midY)
    }

    @MainActor
    func testMoveNewColumnToBeginning() {
        let app = launchApp()

        app.buttons["Новая доска"].click()
        let boardName = app.textFields["Название"]
        XCTAssertTrue(boardName.waitForExistence(timeout: 5))
        boardName.typeText("Доска")
        app.buttons["Сохранить"].click()

        for title in ["Первая", "Вторая", "Новая"] {
            app.buttons["Колонка"].click()
            let columnName = app.textFields["Название"]
            XCTAssertTrue(columnName.waitForExistence(timeout: 5))
            columnName.typeText(title)
            app.buttons["Сохранить"].click()
        }

        let first = app.staticTexts["Первая"]
        let new = app.staticTexts["Новая"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(new.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(new.frame.midX, first.frame.midX)
        new.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.3, thenDragTo: first.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)))
        XCTAssertLessThan(new.frame.midX, first.frame.midX)
    }

    @MainActor
    func testReorderTasksInOneColumn() {
        let app = launchApp()

        app.buttons["Новая доска"].click()
        let name = app.textFields["Название"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Доска")
        app.buttons["Сохранить"].click()
        app.buttons["Колонка"].click()
        let columnName = app.textFields["Название"]
        XCTAssertTrue(columnName.waitForExistence(timeout: 5))
        columnName.typeText("Сегодня")
        app.buttons["Сохранить"].click()

        let quickTask = app.textFields["Быстрая задача"]
        XCTAssertTrue(quickTask.waitForExistence(timeout: 5))
        quickTask.click()
        quickTask.typeText("Первое\nВторое\nТретье\n")
        let first = app.staticTexts["Первое"]
        let third = app.staticTexts["Третье"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(third.waitForExistence(timeout: 5))
        XCTAssertLessThan(third.frame.midY, first.frame.midY)
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.3, thenDragTo: third.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
        XCTAssertLessThan(first.frame.midY, third.frame.midY)
    }

    @MainActor
    func testCreateBoardColumnAndTask() {
        let app = launchApp()

        app.buttons["Новая доска"].click()
        let name = app.textFields["Название"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.typeText("Работа")
        app.buttons["Сохранить"].click()

        let addColumn = app.buttons["Колонка"]
        XCTAssertTrue(addColumn.waitForExistence(timeout: 5))
        addColumn.click()
        let columnName = app.textFields["Название"]
        XCTAssertTrue(columnName.waitForExistence(timeout: 5))
        columnName.typeText("Сегодня")
        app.buttons["Сохранить"].click()

        let quickTask = app.textFields["Быстрая задача"]
        XCTAssertTrue(quickTask.waitForExistence(timeout: 5))
        quickTask.click()
        quickTask.typeText("Первое дело\n")
        XCTAssertTrue(app.staticTexts["Первое дело"].waitForExistence(timeout: 5))
        quickTask.click()
        quickTask.typeText("Черновик")
        quickTask.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        app.typeKey("x", modifierFlags: [])
        XCTAssertEqual(quickTask.value as? String, "Черновик")

        let complete = app.buttons["Завершить задачу"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.click()
        XCTAssertTrue(app.buttons["Отметить незавершённой"].waitForExistence(timeout: 5))

        addColumn.click()
        let destinationName = app.textFields["Название"]
        XCTAssertTrue(destinationName.waitForExistence(timeout: 5))
        destinationName.typeText("Вчера")
        app.buttons["Сохранить"].click()

        let task = app.staticTexts["Первое дело"]
        let destination = app.staticTexts["Вчера"]
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        let originalX = task.frame.midX
        task.click(forDuration: 0.3, thenDragTo: destination)
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(task.frame.midX, originalX + 150)
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.activate()
        let newBoard = app.buttons["Новая доска"]
        if !newBoard.waitForExistence(timeout: 5) {
            let showSidebar = app.buttons["Show Sidebar"]
            if showSidebar.waitForExistence(timeout: 5) { showSidebar.click() }
        }
        XCTAssertTrue(newBoard.waitForExistence(timeout: 10))
        return app
    }
}
