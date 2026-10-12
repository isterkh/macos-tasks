import Foundation
import SwiftData
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
        let item = ChecklistItemInput(title: "Сохранённый пункт")
        XCTAssertTrue(first?.updateTask(task, title: "Сохранённая задача", details: "", colorID: nil, checklist: [item]) == true)
        first = nil

        let reopened = BoardStore(storeURL: url)
        XCTAssertNil(reopened.startupError)
        XCTAssertEqual(reopened.boards.map(\.id), [board])
        XCTAssertEqual(reopened.tasks(in: column, completed: false).map(\.id), [task])
        XCTAssertEqual(reopened.checklist(for: task).map(\.title), ["Сохранённый пункт"])
    }

    func testChecklistStaysWithTaskAcrossMoveArchiveRestoreAndDeletesWithTask() {
        let store = BoardStore(inMemory: true)
        let board = tryID(store.createBoard("Доска"))
        let first = tryID(store.createColumn(boardID: board, title: "Первая"))
        let second = tryID(store.createColumn(boardID: board, title: "Вторая"))
        let task = tryID(store.createTask(columnID: first, title: "Задача"))
        let items = [ChecklistItemInput(title: "Первый"), ChecklistItemInput(title: "Второй")]
        XCTAssertTrue(store.updateTask(task, title: "Задача", details: "", colorID: nil, checklist: items))
        store.toggleChecklistItem(items[0].id)
        XCTAssertEqual(store.checklist(for: task).map(\.isCompleted), [true, false])

        store.moveTasks([task], to: second)
        store.archiveTasks([task])
        store.deleteColumn(first, destinationID: nil)
        XCTAssertEqual(store.checklist(for: task).map(\.title), ["Первый", "Второй"])
        XCTAssertTrue(store.restoreTask(task, to: second))
        XCTAssertEqual(store.checklist(for: task).map(\.isCompleted), [true, false])

        store.deleteTasks([task])
        XCTAssertTrue(store.checklist(for: task).isEmpty)
    }

    func testOpensExistingStoreWithoutChecklistEntity() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Tasks.store")
        let legacy = try ModelContainer(for: BoardEntity.self, ColumnEntity.self, TaskEntity.self,
                                        configurations: ModelConfiguration(url: url))
        let board = BoardEntity(title: "Старая доска", position: 0)
        let column = ColumnEntity(boardID: board.id, title: "Колонка", colorID: "lavender", position: 0)
        let task = TaskEntity(boardID: board.id, columnID: column.id, title: "Старая задача", position: 0)
        let context = ModelContext(legacy)
        context.insert(board)
        context.insert(column)
        context.insert(task)
        try context.save()

        let reopened = BoardStore(storeURL: url)
        XCTAssertNil(reopened.startupError)
        XCTAssertEqual(reopened.tasks.map(\.title), ["Старая задача"])
        XCTAssertTrue(reopened.checklist(for: task.id).isEmpty)
    }

    func testDeletingBoardRemovesActiveAndArchivedChecklists() {
        let store = BoardStore(inMemory: true)
        let board = tryID(store.createBoard("Доска"))
        let column = tryID(store.createColumn(boardID: board, title: "Колонка"))
        let active = tryID(store.createTask(columnID: column, title: "Активная"))
        let archived = tryID(store.createTask(columnID: column, title: "Архивная"))
        let first = ChecklistItemInput(title: "Первый")
        let second = ChecklistItemInput(title: "Второй")
        XCTAssertTrue(store.updateTask(active, title: "Активная", details: "", colorID: nil, checklist: [first]))
        XCTAssertTrue(store.updateTask(archived, title: "Архивная", details: "", colorID: nil, checklist: [second]))
        store.archiveTasks([archived])

        XCTAssertTrue(store.deleteBoard(board))
        XCTAssertTrue(store.checklistItems.isEmpty)
        XCTAssertTrue(store.tasks.isEmpty)
    }

    private func tryID(_ value: UUID?, file: StaticString = #filePath, line: UInt = #line) -> UUID {
        guard let value else {
            XCTFail("Операция не вернула ID", file: file, line: line)
            return UUID()
        }
        return value
    }
}
