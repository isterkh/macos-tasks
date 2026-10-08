import Foundation
import XCTest
@testable import DailyBoard

@MainActor
final class BoardStoreTests: XCTestCase {
    func testArchiveRestoreAndColumnDeletion() {
        let store = BoardStore(inMemory: true)
        XCTAssertNil(store.startupError)
        let board = tryID(store.createBoard("Работа"))
        let today = tryID(store.createColumn(boardID: board, title: "Сегодня"))
        let yesterday = tryID(store.createColumn(boardID: board, title: "Вчера"))
        let task = tryID(store.createTask(columnID: today, title: "Задача"))

        store.toggleTask(task)
        XCTAssertEqual(store.tasks(in: today, completed: true).map(\.id), [task])
        store.archiveTasks([task])
        XCTAssertEqual(store.archivedTasks(in: board).first?.columnID, nil)
        XCTAssertEqual(store.archivedTasks(in: board).first?.isCompleted, true)

        store.deleteColumn(today, destinationID: nil)
        XCTAssertEqual(store.archivedTasks(in: board).map(\.id), [task])
        XCTAssertTrue(store.restoreTask(task, to: yesterday))
        XCTAssertEqual(store.tasks(in: yesterday, completed: true).map(\.id), [task])
        XCTAssertTrue(store.archivedTasks(in: board).isEmpty)
    }

    func testBulkMovePreservesStatusAndVisualOrder() {
        let store = BoardStore(inMemory: true)
        let board = tryID(store.createBoard("Доска"))
        let first = tryID(store.createColumn(boardID: board, title: "Первая"))
        let second = tryID(store.createColumn(boardID: board, title: "Вторая"))
        let a = tryID(store.createTask(columnID: first, title: "А"))
        let b = tryID(store.createTask(columnID: first, title: "Б"))
        let c = tryID(store.createTask(columnID: second, title: "В"))
        store.toggleTask(a)
        store.toggleTask(b)

        store.moveTasks([a, b], to: second)
        XCTAssertEqual(store.tasks(in: second, completed: true).map(\.id), [b, a])
        XCTAssertEqual(store.tasks(in: second, completed: false).map(\.id), [c])
    }

    func testPlaceTasksReordersWithinColumnAndAppends() {
        let store = BoardStore(inMemory: true)
        let board = tryID(store.createBoard("Доска"))
        let column = tryID(store.createColumn(boardID: board, title: "Сегодня"))
        let first = tryID(store.createTask(columnID: column, title: "Первое"))
        let second = tryID(store.createTask(columnID: column, title: "Второе"))
        let third = tryID(store.createTask(columnID: column, title: "Третье"))

        store.placeTasks([first], to: column, before: third)
        XCTAssertEqual(store.tasks(in: column, completed: false).map(\.id), [first, third, second])

        store.placeTasks([third], to: column, before: nil)
        XCTAssertEqual(store.tasks(in: column, completed: false).map(\.id), [first, second, third])

        let otherColumn = tryID(store.createColumn(boardID: board, title: "Вчера"))
        store.placeTasks([first, second], to: otherColumn, before: nil)
        XCTAssertEqual(store.tasks(in: otherColumn, completed: false).map(\.id), [first, second])
        XCTAssertEqual(store.tasks(in: column, completed: false).map(\.id), [third])
    }

    func testReorderColumnToBeginning() {
        let store = BoardStore(inMemory: true)
        let board = tryID(store.createBoard("Доска"))
        let first = tryID(store.createColumn(boardID: board, title: "Первая"))
        let second = tryID(store.createColumn(boardID: board, title: "Вторая"))
        let third = tryID(store.createColumn(boardID: board, title: "Третья"))

        store.reorderColumn(third, to: 0)
        XCTAssertEqual(store.columns(in: board).map(\.id), [third, first, second])
        XCTAssertEqual(store.columns(in: board).map(\.position), [0, 1, 2])

        store.moveColumn(third, offset: 1)
        XCTAssertEqual(store.columns(in: board).map(\.id), [first, third, second])
    }

    func testDataSurvivesReopeningStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Tasks.store")
        var first: BoardStore? = BoardStore(storeURL: url)
        XCTAssertNil(first?.startupError)
        let board = tryID(first?.createBoard("Сохранённая доска"))
        let column = tryID(first?.createColumn(boardID: board, title: "Сегодня"))
        let task = tryID(first?.createTask(columnID: column, title: "Сохранённая задача"))
        first = nil

        let reopened = BoardStore(storeURL: url)
        XCTAssertNil(reopened.startupError)
        XCTAssertEqual(reopened.boards.map(\.id), [board])
        XCTAssertEqual(reopened.tasks(in: column, completed: false).map(\.id), [task])
    }

    private func tryID(_ value: UUID?, file: StaticString = #filePath, line: UInt = #line) -> UUID {
        guard let value else {
            XCTFail("Операция не вернула ID", file: file, line: line)
            return UUID()
        }
        return value
    }
}
