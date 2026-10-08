import XCTest

final class DailyBoardUITests: XCTestCase {
    @MainActor
    func testCreateBoardColumnAndTask() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

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
}
