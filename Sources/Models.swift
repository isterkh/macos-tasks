import Foundation
import SwiftData

@Model
final class BoardEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var position: Int
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, position: Int, now: Date = .now) {
        self.id = id
        self.title = title
        self.position = position
        self.createdAt = now
        self.updatedAt = now
    }
}

@Model
final class ColumnEntity {
    @Attribute(.unique) var id: UUID
    var boardID: UUID
    var title: String
    var colorID: String
    var position: Int
    var updatedAt: Date

    init(id: UUID = UUID(), boardID: UUID, title: String, colorID: String, position: Int, now: Date = .now) {
        self.id = id
        self.boardID = boardID
        self.title = title
        self.colorID = colorID
        self.position = position
        self.updatedAt = now
    }
}

@Model
final class TaskEntity {
    @Attribute(.unique) var id: UUID
    var boardID: UUID
    var columnID: UUID?
    var title: String
    var details: String
    var colorID: String?
    var isCompleted: Bool
    var position: Int
    var archivedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), boardID: UUID, columnID: UUID, title: String, position: Int, now: Date = .now) {
        self.id = id
        self.boardID = boardID
        self.columnID = columnID
        self.title = title
        self.details = ""
        self.colorID = nil
        self.isCompleted = false
        self.position = position
        self.archivedAt = nil
        self.createdAt = now
        self.updatedAt = now
    }
}

struct BoardRecord: Identifiable, Hashable {
    let id: UUID
    let title: String
    let position: Int
    let createdAt: Date
    let updatedAt: Date

    init(_ entity: BoardEntity) {
        id = entity.id
        title = entity.title
        position = entity.position
        createdAt = entity.createdAt
        updatedAt = entity.updatedAt
    }
}

struct ColumnRecord: Identifiable, Hashable {
    let id: UUID
    let boardID: UUID
    let title: String
    let colorID: String
    let position: Int
    let updatedAt: Date

    init(_ entity: ColumnEntity) {
        id = entity.id
        boardID = entity.boardID
        title = entity.title
        colorID = entity.colorID
        position = entity.position
        updatedAt = entity.updatedAt
    }
}

struct TaskRecord: Identifiable, Hashable {
    let id: UUID
    let boardID: UUID
    let columnID: UUID?
    let title: String
    let details: String
    let colorID: String?
    let isCompleted: Bool
    let position: Int
    let archivedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    init(_ entity: TaskEntity) {
        id = entity.id
        boardID = entity.boardID
        columnID = entity.columnID
        title = entity.title
        details = entity.details
        colorID = entity.colorID
        isCompleted = entity.isCompleted
        position = entity.position
        archivedAt = entity.archivedAt
        createdAt = entity.createdAt
        updatedAt = entity.updatedAt
    }
}
