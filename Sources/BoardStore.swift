import Combine
import Foundation
import SwiftData

@MainActor
final class BoardStore: ObservableObject {
    @Published private(set) var boards: [BoardRecord] = []
    @Published private(set) var columns: [ColumnRecord] = []
    @Published private(set) var tasks: [TaskRecord] = []
    @Published var errorMessage: String?
    @Published private(set) var startupError: String?

    private var container: ModelContainer?
    private var context: ModelContext?

    init(inMemory: Bool = false, storeURL: URL? = nil) {
        do {
            let configuration: ModelConfiguration
            if let storeURL {
                configuration = ModelConfiguration(url: storeURL)
            } else if inMemory {
                configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            } else {
                let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("com.isterkh.DailyBoard", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                configuration = ModelConfiguration(url: directory.appendingPathComponent("Tasks.store"))
            }
            let container = try ModelContainer(
                for: BoardEntity.self, ColumnEntity.self, TaskEntity.self,
                configurations: configuration
            )
            let context = ModelContext(container)
            context.autosaveEnabled = false
            self.container = container
            self.context = context
            try reload()
        } catch {
            startupError = "Не удалось открыть локальное хранилище: \(error.localizedDescription)"
        }
    }

    private func reload() throws {
        guard let context else { return }
        let loadedBoards = try context.fetch(FetchDescriptor<BoardEntity>())
        let loadedColumns = try context.fetch(FetchDescriptor<ColumnEntity>())
        let loadedTasks = try context.fetch(FetchDescriptor<TaskEntity>())
        boards = loadedBoards.map(BoardRecord.init).sorted { $0.position < $1.position }
        columns = loadedColumns.map(ColumnRecord.init).sorted { $0.position < $1.position }
        tasks = loadedTasks.map(TaskRecord.init)
    }

    @discardableResult
    private func transact(_ change: (ModelContext) throws -> Void) -> Bool {
        guard let context else { return false }
        do {
            try context.transaction { try change(context) }
            try reload()
            return true
        } catch {
            context.rollback()
            errorMessage = "Не удалось сохранить изменения: \(error.localizedDescription)"
            return false
        }
    }

    private func allBoards(_ context: ModelContext) throws -> [BoardEntity] {
        try context.fetch(FetchDescriptor<BoardEntity>())
    }

    private func allColumns(_ context: ModelContext) throws -> [ColumnEntity] {
        try context.fetch(FetchDescriptor<ColumnEntity>())
    }

    private func allTasks(_ context: ModelContext) throws -> [TaskEntity] {
        try context.fetch(FetchDescriptor<TaskEntity>())
    }

    private func requiredTitle(_ title: String) throws -> String {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw StoreError.emptyTitle }
        return clean
    }

    func columns(in boardID: UUID) -> [ColumnRecord] {
        columns.filter { $0.boardID == boardID }.sorted { $0.position < $1.position }
    }

    func tasks(in columnID: UUID, completed: Bool) -> [TaskRecord] {
        tasks.filter { $0.columnID == columnID && $0.archivedAt == nil && $0.isCompleted == completed }
            .sorted { $0.position < $1.position }
    }

    func archivedTasks(in boardID: UUID) -> [TaskRecord] {
        tasks.filter { $0.boardID == boardID && $0.archivedAt != nil }
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    @discardableResult
    func createBoard(_ title: String) -> UUID? {
        let id = UUID()
        let success = transact { context in
            let name = try requiredTitle(title)
            let position = (try allBoards(context).map(\.position).max() ?? -1) + 1
            context.insert(BoardEntity(id: id, title: name, position: position))
        }
        return success ? id : nil
    }

    @discardableResult
    func renameBoard(_ id: UUID, title: String) -> Bool {
        transact { context in
            guard let board = try allBoards(context).first(where: { $0.id == id }) else { throw StoreError.notFound }
            board.title = try requiredTitle(title)
            board.updatedAt = .now
        }
    }

    func moveBoard(_ id: UUID, offset: Int) {
        transact { context in
            let ordered = try allBoards(context).sorted { $0.position < $1.position }
            guard let index = ordered.firstIndex(where: { $0.id == id }),
                  ordered.indices.contains(index + offset) else { return }
            let now = Date.now
            ordered[index].position = index + offset
            ordered[index + offset].position = index
            ordered[index].updatedAt = now
            ordered[index + offset].updatedAt = now
        }
    }

    @discardableResult
    func deleteBoard(_ id: UUID) -> Bool {
        transact { context in
            for task in try allTasks(context).filter({ $0.boardID == id }) { context.delete(task) }
            for column in try allColumns(context).filter({ $0.boardID == id }) { context.delete(column) }
            guard let board = try allBoards(context).first(where: { $0.id == id }) else { throw StoreError.notFound }
            context.delete(board)
            let survivors = try allBoards(context).filter { $0.id != id }.sorted { $0.position < $1.position }
            for (position, survivor) in survivors.enumerated() where survivor.position != position {
                survivor.position = position
                survivor.updatedAt = .now
            }
        }
    }

    @discardableResult
    func createColumn(boardID: UUID, title: String, colorID: String = "lavender") -> UUID? {
        let id = UUID()
        let success = transact { context in
            guard try allBoards(context).contains(where: { $0.id == boardID }) else { throw StoreError.notFound }
            let name = try requiredTitle(title)
            let position = (try allColumns(context).filter { $0.boardID == boardID }.map(\.position).max() ?? -1) + 1
            context.insert(ColumnEntity(id: id, boardID: boardID, title: name, colorID: colorID, position: position))
        }
        return success ? id : nil
    }

    @discardableResult
    func updateColumn(_ id: UUID, title: String, colorID: String) -> Bool {
        transact { context in
            guard let column = try allColumns(context).first(where: { $0.id == id }) else { throw StoreError.notFound }
            column.title = try requiredTitle(title)
            column.colorID = colorID
            column.updatedAt = .now
        }
    }

    func moveColumn(_ id: UUID, offset: Int) {
        transact { context in
            let all = try allColumns(context)
            guard let column = all.first(where: { $0.id == id }) else { throw StoreError.notFound }
            let ordered = all.filter { $0.boardID == column.boardID }.sorted { $0.position < $1.position }
            guard let index = ordered.firstIndex(where: { $0.id == id }),
                  ordered.indices.contains(index + offset) else { return }
            let now = Date.now
            ordered[index].position = index + offset
            ordered[index + offset].position = index
            ordered[index].updatedAt = now
            ordered[index + offset].updatedAt = now
        }
    }

    // destinationID == nil means delete the active tasks with the column.
    func deleteColumn(_ id: UUID, destinationID: UUID?) {
        transact { context in
            let all = try allColumns(context)
            guard let column = all.first(where: { $0.id == id }) else { throw StoreError.notFound }
            let affected = try allTasks(context).filter { $0.columnID == id && $0.archivedAt == nil }
            if let destinationID {
                guard destinationID != id,
                      all.contains(where: { $0.id == destinationID && $0.boardID == column.boardID }) else {
                    throw StoreError.invalidDestination
                }
                if !affected.isEmpty {
                    try moveEntities(affected, to: destinationID, context: context)
                }
            } else {
                for task in affected { context.delete(task) }
            }
            context.delete(column)
            let survivors = all.filter { $0.boardID == column.boardID && $0.id != id }.sorted { $0.position < $1.position }
            for (position, survivor) in survivors.enumerated() {
                survivor.position = position
                survivor.updatedAt = .now
            }
        }
    }

    @discardableResult
    func createTask(columnID: UUID, title: String) -> UUID? {
        let id = UUID()
        let success = transact { context in
            guard let column = try allColumns(context).first(where: { $0.id == columnID }) else { throw StoreError.notFound }
            let name = try requiredTitle(title)
            let current = try allTasks(context).filter { $0.columnID == columnID && $0.archivedAt == nil && !$0.isCompleted }
            for task in current {
                task.position += 1
                task.updatedAt = .now
            }
            context.insert(TaskEntity(id: id, boardID: column.boardID, columnID: columnID, title: name, position: 0))
        }
        return success ? id : nil
    }

    @discardableResult
    func updateTask(_ id: UUID, title: String, details: String, colorID: String?) -> Bool {
        transact { context in
            guard let task = try allTasks(context).first(where: { $0.id == id }) else { throw StoreError.notFound }
            task.title = try requiredTitle(title)
            task.details = details
            task.colorID = colorID
            task.updatedAt = .now
        }
    }

    func toggleTask(_ id: UUID) {
        transact { context in
            let all = try allTasks(context)
            guard let task = all.first(where: { $0.id == id }),
                  let columnID = task.columnID, task.archivedAt == nil else { throw StoreError.notFound }
            let oldStatus = task.isCompleted
            task.isCompleted.toggle()
            task.updatedAt = .now
            let target = all.filter { $0.columnID == columnID && $0.archivedAt == nil && $0.isCompleted == task.isCompleted && $0.id != id }
            for other in target {
                other.position += 1
                other.updatedAt = .now
            }
            task.position = 0
            normalize(all.filter { $0.columnID == columnID && $0.archivedAt == nil && $0.isCompleted == oldStatus && $0.id != id })
        }
    }

    func moveTasks(_ ids: [UUID], to destinationID: UUID) {
        transact { context in
            let all = try allTasks(context)
            let chosen = all.filter { ids.contains($0.id) && $0.archivedAt == nil }
            try moveEntities(chosen, to: destinationID, context: context)
        }
    }

    func placeTasks(_ ids: [UUID], to destinationID: UUID, before targetID: UUID?) {
        transact { context in
            let all = try allTasks(context)
            let columns = try allColumns(context)
            guard let destination = columns.first(where: { $0.id == destinationID }) else { throw StoreError.invalidDestination }
            let chosenByID = Dictionary(uniqueKeysWithValues: all.filter { ids.contains($0.id) && $0.archivedAt == nil }.map { ($0.id, $0) })
            let chosen = ids.compactMap { chosenByID[$0] }
            guard !chosen.isEmpty, chosen.count == ids.count,
                  chosen.allSatisfy({ $0.boardID == destination.boardID }) else { throw StoreError.invalidDestination }
            let chosenIDs = Set(ids)
            let oldGroups = Set(chosen.compactMap { task -> GroupKey? in
                guard let columnID = task.columnID else { return nil }
                return GroupKey(columnID: columnID, completed: task.isCompleted)
            })
            let target = all.first { $0.id == targetID && $0.columnID == destinationID && $0.archivedAt == nil && !chosenIDs.contains($0.id) }
            let now = Date.now
            for status in [false, true] {
                let moved = chosen.filter { $0.isCompleted == status }
                let remaining = all.filter { $0.columnID == destinationID && $0.archivedAt == nil && $0.isCompleted == status && !chosenIDs.contains($0.id) }
                    .sorted { $0.position < $1.position }
                let insertion = target?.isCompleted == status
                    ? remaining.firstIndex(where: { $0.id == target?.id }) ?? remaining.count
                    : remaining.count
                var ordered = remaining
                ordered.insert(contentsOf: moved, at: insertion)
                for (index, task) in ordered.enumerated() {
                    if task.position != index || task.columnID != destinationID {
                        task.position = index
                        task.columnID = destinationID
                        task.updatedAt = now
                    }
                }
            }
            for key in oldGroups where key.columnID != destinationID {
                normalize(all.filter { $0.columnID == key.columnID && $0.archivedAt == nil && $0.isCompleted == key.completed && !chosenIDs.contains($0.id) })
            }
        }
    }

    private func moveEntities(_ chosen: [TaskEntity], to destinationID: UUID, context: ModelContext) throws {
        let allColumns = try allColumns(context)
        guard let destination = allColumns.first(where: { $0.id == destinationID }) else { throw StoreError.invalidDestination }
        guard !chosen.isEmpty, chosen.allSatisfy({ $0.boardID == destination.boardID }) else { throw StoreError.invalidDestination }
        let all = try allTasks(context)
        let chosenIDs = Set(chosen.map(\.id))
        let columnPositions = Dictionary(uniqueKeysWithValues: allColumns.map { ($0.id, $0.position) })
        let ordered = chosen.sorted {
            let left = (columnPositions[$0.columnID ?? UUID()] ?? Int.max, $0.isCompleted ? 1 : 0, $0.position)
            let right = (columnPositions[$1.columnID ?? UUID()] ?? Int.max, $1.isCompleted ? 1 : 0, $1.position)
            return left < right
        }
        let oldGroups = Set(chosen.compactMap { task -> GroupKey? in
            guard let columnID = task.columnID else { return nil }
            return GroupKey(columnID: columnID, completed: task.isCompleted)
        })
        let now = Date.now
        for task in chosen {
            task.columnID = destinationID
            task.updatedAt = now
        }
        for status in [false, true] {
            let moved = ordered.filter { $0.isCompleted == status }
            let remaining = all.filter { $0.columnID == destinationID && $0.archivedAt == nil && $0.isCompleted == status && !chosenIDs.contains($0.id) }
                .sorted { $0.position < $1.position }
            for (index, task) in (moved + remaining).enumerated() where task.position != index {
                task.position = index
                task.updatedAt = now
            }
        }
        for key in oldGroups where key.columnID != destinationID {
            normalize(all.filter { $0.columnID == key.columnID && $0.archivedAt == nil && $0.isCompleted == key.completed && !chosenIDs.contains($0.id) })
        }
    }

    func reorderTask(_ id: UUID, before targetID: UUID) {
        transact { context in
            let all = try allTasks(context)
            guard let task = all.first(where: { $0.id == id }),
                  let target = all.first(where: { $0.id == targetID }),
                  task.id != target.id,
                  task.columnID == target.columnID,
                  task.isCompleted == target.isCompleted,
                  task.archivedAt == nil, target.archivedAt == nil else { throw StoreError.invalidDestination }
            var group = all.filter { $0.columnID == task.columnID && $0.archivedAt == nil && $0.isCompleted == task.isCompleted && $0.id != id }
                .sorted { $0.position < $1.position }
            guard let index = group.firstIndex(where: { $0.id == targetID }) else { throw StoreError.notFound }
            group.insert(task, at: index)
            normalize(group)
            task.updatedAt = .now
        }
    }

    func archiveTasks(_ ids: [UUID]) {
        transact { context in
            let all = try allTasks(context)
            let chosen = all.filter { ids.contains($0.id) && $0.archivedAt == nil }
            let groups = Set(chosen.compactMap { task -> GroupKey? in
                guard let columnID = task.columnID else { return nil }
                return GroupKey(columnID: columnID, completed: task.isCompleted)
            })
            let now = Date.now
            for task in chosen {
                task.columnID = nil
                task.archivedAt = now
                task.updatedAt = now
            }
            for key in groups {
                normalize(all.filter { $0.columnID == key.columnID && $0.archivedAt == nil && $0.isCompleted == key.completed })
            }
        }
    }

    @discardableResult
    func restoreTask(_ id: UUID, to columnID: UUID) -> Bool {
        transact { context in
            guard let task = try allTasks(context).first(where: { $0.id == id && $0.archivedAt != nil }),
                  try allColumns(context).contains(where: { $0.id == columnID && $0.boardID == task.boardID }) else {
                throw StoreError.invalidDestination
            }
            let group = try allTasks(context).filter { $0.columnID == columnID && $0.archivedAt == nil && $0.isCompleted == task.isCompleted }
            for other in group {
                other.position += 1
                other.updatedAt = .now
            }
            task.columnID = columnID
            task.archivedAt = nil
            task.position = 0
            task.updatedAt = .now
        }
    }

    func deleteTasks(_ ids: [UUID]) {
        transact { context in
            let all = try allTasks(context)
            let selected = all.filter { ids.contains($0.id) }
            let groups = Set(selected.compactMap { task -> GroupKey? in
                guard let columnID = task.columnID, task.archivedAt == nil else { return nil }
                return GroupKey(columnID: columnID, completed: task.isCompleted)
            })
            let selectedIDs = Set(selected.map(\.id))
            for task in selected { context.delete(task) }
            for key in groups {
                normalize(all.filter { $0.columnID == key.columnID && $0.archivedAt == nil && $0.isCompleted == key.completed && !selectedIDs.contains($0.id) })
            }
        }
    }

    private func normalize(_ tasks: [TaskEntity]) {
        for (index, task) in tasks.sorted(by: { $0.position < $1.position }).enumerated() where task.position != index {
            task.position = index
            task.updatedAt = .now
        }
    }
}

private struct GroupKey: Hashable {
    let columnID: UUID
    let completed: Bool
}

private enum StoreError: LocalizedError {
    case emptyTitle
    case notFound
    case invalidDestination

    var errorDescription: String? {
        switch self {
        case .emptyTitle: "Название не может быть пустым."
        case .notFound: "Запись не найдена."
        case .invalidDestination: "Нельзя переместить задачу в выбранную колонку."
        }
    }
}
