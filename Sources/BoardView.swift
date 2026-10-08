import AppKit
import SwiftUI

struct BoardView: View {
    @ObservedObject var store: BoardStore
    let board: BoardRecord

    @State private var quickTitles: [UUID: String] = [:]
    @State private var selectedIDs: Set<UUID> = []
    @State private var selectionAnchor: (columnID: UUID, taskID: UUID)?
    @State private var editorDraft: TaskDraft?
    @State private var askingAboutDraft = false
    @State private var showingNewColumn = false
    @State private var editingColumn: ColumnRecord?
    @State private var deletingColumn: ColumnRecord?
    @State private var deletingTaskIDs: [UUID]?
    @State private var destinationRequest: DestinationRequest?
    @State private var showingArchive = false

    private var boardColumns: [ColumnRecord] { store.columns(in: board.id) }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                Divider()
                GeometryReader { geometry in
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(boardColumns) { column in
                                columnView(column)
                                    .frame(height: max(300, geometry.size.height - 24))
                            }
                            Button {
                                showingNewColumn = true
                            } label: {
                                Label("Новая колонка", systemImage: "plus")
                                    .frame(width: 260, height: 50)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(16)
                    }
                }
            }
            if editorDraft != nil {
                editorOverlay
            }
        }
        .sheet(isPresented: $showingNewColumn) {
            NameSheet(title: "Новая колонка", initialName: "") { title in
                if store.createColumn(boardID: board.id, title: title) != nil { showingNewColumn = false }
            } onCancel: {
                showingNewColumn = false
            }
        }
        .sheet(item: $editingColumn) { column in
            ColumnEditorSheet(column: column) { title, colorID in
                if store.updateColumn(column.id, title: title, colorID: colorID) { editingColumn = nil }
            } onCancel: {
                editingColumn = nil
            }
        }
        .sheet(item: $destinationRequest) { request in
            DestinationSheet(title: request.title, columns: boardColumns.filter { $0.id != request.excludedColumnID }) { columnID in
                switch request.action {
                case .move(let ids): store.moveTasks(ids, to: columnID)
                case .deleteColumn(let id): store.deleteColumn(id, destinationID: columnID)
                }
                destinationRequest = nil
                selectedIDs.removeAll()
            } onCancel: {
                destinationRequest = nil
            }
        }
        .sheet(isPresented: $showingArchive) {
            ArchiveView(store: store, board: board)
        }
        .confirmationDialog("Удалить колонку «\(deletingColumn?.title ?? "")»?", isPresented: Binding(get: { deletingColumn != nil }, set: { if !$0 { deletingColumn = nil } })) {
            if let column = deletingColumn {
                Button("Удалить колонку и её задачи", role: .destructive) {
                    store.deleteColumn(column.id, destinationID: nil)
                    deletingColumn = nil
                    selectedIDs.removeAll()
                }
                if boardColumns.count > 1 {
                    Button("Перенести задачи…") {
                        destinationRequest = DestinationRequest(title: "Куда перенести задачи?", excludedColumnID: column.id, action: .deleteColumn(column.id))
                        deletingColumn = nil
                    }
                }
            }
            Button("Отмена", role: .cancel) { deletingColumn = nil }
        } message: {
            Text("Архивные задачи останутся в архиве доски.")
        }
        .alert("Удалить задачи?", isPresented: Binding(get: { deletingTaskIDs != nil }, set: { if !$0 { deletingTaskIDs = nil } })) {
            Button("Удалить окончательно", role: .destructive) {
                if let ids = deletingTaskIDs { store.deleteTasks(ids) }
                deletingTaskIDs = nil
                selectedIDs.removeAll()
            }
            Button("Отмена", role: .cancel) { deletingTaskIDs = nil }
        } message: {
            Text("Это действие нельзя отменить.")
        }
        .alert("Несохранённые изменения", isPresented: $askingAboutDraft) {
            Button("Сохранить") { saveDraft() }
            Button("Не сохранять", role: .destructive) { editorDraft = nil }
            Button("Продолжить редактирование", role: .cancel) { }
        } message: {
            Text("Сохранить изменения задачи перед закрытием?")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(board.title).font(.title2.weight(.semibold))
            Spacer()
            if !selectedIDs.isEmpty {
                Text("Выбрано: \(selectedIDs.count)")
                    .foregroundStyle(.secondary)
                Menu {
                    Menu("Перенести") {
                        ForEach(boardColumns) { column in
                            Button(column.title) { store.moveTasks(Array(selectedIDs), to: column.id); selectedIDs.removeAll() }
                        }
                    }
                    Button("Архивировать") { store.archiveTasks(Array(selectedIDs)); selectedIDs.removeAll() }
                    Button("Удалить…", role: .destructive) { deletingTaskIDs = Array(selectedIDs) }
                    Divider()
                    Button("Снять выделение") { selectedIDs.removeAll() }
                } label: {
                    Label("Действия", systemImage: "ellipsis.circle")
                }
            }
            Button {
                showingArchive = true
            } label: {
                Label("Архив", systemImage: "archivebox")
            }
            Button {
                showingNewColumn = true
            } label: {
                Label("Колонка", systemImage: "plus")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func columnView(_ column: ColumnRecord) -> some View {
        let open = store.tasks(in: column.id, completed: false)
        let done = store.tasks(in: column.id, completed: true)
        return VStack(spacing: 0) {
            Pastel.color(column.colorID)
                .frame(height: 5)
            HStack {
                Text(column.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text("\(open.count + done.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                columnMenu(column, completedTasks: done)
            }
            .padding(12)
            HStack(spacing: 6) {
                TextField("Быстрая задача", text: quickBinding(for: column.id))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addQuickTask(in: column.id) }
                Button {
                    addQuickTask(in: column.id)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Добавить задачу")
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            ScrollView(.vertical) {
                LazyVStack(spacing: 8) {
                    ForEach(open) { task in taskView(task, in: column) }
                    if !done.isEmpty {
                        HStack(spacing: 8) {
                            Rectangle().frame(height: 1)
                            Text("Завершено").font(.caption2).fixedSize()
                            Rectangle().frame(height: 1)
                        }
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                    }
                    ForEach(done) { task in taskView(task, in: column) }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 290)
        .background(Color(nsColor: .underPageBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary) }
        .dropDestination(for: TaskDrag.self) { drags, _ in
            guard let drag = drags.first else { return false }
            store.moveTasks(drag.ids, to: column.id)
            selectedIDs.removeAll()
            return true
        }
    }

    private func columnMenu(_ column: ColumnRecord, completedTasks: [TaskRecord]) -> some View {
        Menu {
            Menu("Перенести завершённые") {
                ForEach(boardColumns.filter { $0.id != column.id }) { destination in
                    Button(destination.title) {
                        store.moveTasks(completedTasks.map(\.id), to: destination.id)
                        selectedIDs.removeAll()
                    }
                }
            }
            .disabled(completedTasks.isEmpty || boardColumns.count < 2)
            Button("Архивировать завершённые") {
                store.archiveTasks(completedTasks.map(\.id))
                selectedIDs.removeAll()
            }
                .disabled(completedTasks.isEmpty)
            Button("Выбрать все завершённые") { selectedIDs = Set(completedTasks.map(\.id)) }
                .disabled(completedTasks.isEmpty)
            Divider()
            Button("Настроить…") { editingColumn = column }
            Button("Влево") { store.moveColumn(column.id, offset: -1) }
                .disabled(column.position == 0)
            Button("Вправо") { store.moveColumn(column.id, offset: 1) }
                .disabled(column.position >= boardColumns.count - 1)
            Divider()
            Button("Удалить…", role: .destructive) { deletingColumn = column }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .help("Действия с колонкой")
    }

    private func taskView(_ task: TaskRecord, in column: ColumnRecord) -> some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(task.colorID == nil ? .clear : Pastel.color(task.colorID))
                .frame(width: 5)
            Button {
                store.toggleTask(task.id)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 10)
            .padding(.trailing, 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(3)
                if !task.details.isEmpty {
                    Text(task.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.trailing, 10)
        }
        .frame(minHeight: 42)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(selectedIDs.contains(task.id) ? Color.accentColor : Color.primary.opacity(0.07), lineWidth: selectedIDs.contains(task.id) ? 2 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { handleTaskClick(task, column: column) }
        .draggable(TaskDrag(ids: dragIDs(for: task))) {
            Label(selectedIDs.contains(task.id) ? "\(selectedIDs.count) задач" : task.title, systemImage: "rectangle.on.rectangle")
                .padding(8)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .dropDestination(for: TaskDrag.self) { drags, _ in
            guard let drag = drags.first, !drag.ids.contains(task.id) else { return false }
            if drag.ids.count == 1,
               let moving = store.tasks.first(where: { $0.id == drag.ids[0] }),
               moving.columnID == column.id,
               moving.isCompleted == task.isCompleted {
                store.reorderTask(moving.id, before: task.id)
            } else {
                store.moveTasks(drag.ids, to: column.id)
            }
            selectedIDs.removeAll()
            return true
        }
        .contextMenu {
            Menu("Перенести") {
                ForEach(boardColumns) { destination in
                    Button(destination.title) { store.moveTasks(actionIDs(for: task), to: destination.id); selectedIDs.removeAll() }
                }
            }
            Button("Архивировать") { store.archiveTasks(actionIDs(for: task)); selectedIDs.removeAll() }
            Button("Удалить…", role: .destructive) { deletingTaskIDs = actionIDs(for: task) }
        }
    }

    private func handleTaskClick(_ task: TaskRecord, column: ColumnRecord) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if selectedIDs.contains(task.id) { selectedIDs.remove(task.id) }
            else { selectedIDs.insert(task.id) }
            selectionAnchor = (column.id, task.id)
        } else if flags.contains(.shift) {
            let visible = store.tasks(in: column.id, completed: false) + store.tasks(in: column.id, completed: true)
            if let anchor = selectionAnchor,
               anchor.columnID == column.id,
               let start = visible.firstIndex(where: { $0.id == anchor.taskID }),
               let end = visible.firstIndex(where: { $0.id == task.id }) {
                for entry in visible[min(start, end)...max(start, end)] { selectedIDs.insert(entry.id) }
            } else {
                selectedIDs.insert(task.id)
                selectionAnchor = (column.id, task.id)
            }
        } else {
            selectedIDs.removeAll()
            selectionAnchor = (column.id, task.id)
            editorDraft = TaskDraft(task)
        }
    }

    private func actionIDs(for task: TaskRecord) -> [UUID] {
        selectedIDs.contains(task.id) ? Array(selectedIDs) : [task.id]
    }

    private func dragIDs(for task: TaskRecord) -> [UUID] {
        guard selectedIDs.contains(task.id) else { return [task.id] }
        let positions = Dictionary(uniqueKeysWithValues: boardColumns.map { ($0.id, $0.position) })
        return store.tasks.filter { selectedIDs.contains($0.id) }
            .sorted {
                (positions[$0.columnID ?? UUID()] ?? Int.max, $0.isCompleted ? 1 : 0, $0.position)
                < (positions[$1.columnID ?? UUID()] ?? Int.max, $1.isCompleted ? 1 : 0, $1.position)
            }
            .map(\.id)
    }

    private func quickBinding(for columnID: UUID) -> Binding<String> {
        Binding(get: { quickTitles[columnID] ?? "" }, set: { quickTitles[columnID] = $0 })
    }

    private func addQuickTask(in columnID: UUID) {
        let title = (quickTitles[columnID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        if store.createTask(columnID: columnID, title: title) != nil { quickTitles[columnID] = "" }
    }

    private var editorOverlay: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: attemptCloseEditor)
            if let draft = editorDraft {
                TaskEditor(draft: Binding(get: { editorDraft ?? draft }, set: { editorDraft = $0 }), onSave: saveDraft, onCancel: { editorDraft = nil }, onEscape: attemptCloseEditor)
                    .frame(width: 410)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(radius: 24)
            }
        }
    }

    private func attemptCloseEditor() {
        if editorDraft?.isDirty == true { askingAboutDraft = true }
        else { editorDraft = nil }
    }

    private func saveDraft() {
        guard let draft = editorDraft else { return }
        if store.updateTask(draft.id, title: draft.title, details: draft.details, colorID: draft.colorID) {
            editorDraft = nil
        }
    }
}

private struct TaskDraft: Equatable {
    let id: UUID
    let originalTitle: String
    let originalDetails: String
    let originalColorID: String?
    var title: String
    var details: String
    var colorID: String?

    init(_ task: TaskRecord) {
        id = task.id
        originalTitle = task.title
        originalDetails = task.details
        originalColorID = task.colorID
        title = task.title
        details = task.details
        colorID = task.colorID
    }

    var isDirty: Bool { title != originalTitle || details != originalDetails || colorID != originalColorID }
}

private struct TaskEditor: View {
    @Binding var draft: TaskDraft
    let onSave: () -> Void
    let onCancel: () -> Void
    let onEscape: () -> Void
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Задача").font(.headline)
            TextField("Название", text: $draft.title)
                .focused($titleFocused)
            Text("Описание").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $draft.details)
                .font(.body)
                .frame(height: 120)
                .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary) }
            Text("Цвет").font(.caption).foregroundStyle(.secondary)
            PalettePicker(selection: $draft.colorID, allowsNone: true)
            HStack {
                Spacer()
                Button("Отмена", action: onCancel)
                Button("Сохранить", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .onAppear { titleFocused = true }
        .onExitCommand(perform: onEscape)
    }
}

private struct ColumnEditorSheet: View {
    let column: ColumnRecord
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    @State private var title: String
    @State private var colorID: String?

    init(column: ColumnRecord, onSave: @escaping (String, String) -> Void, onCancel: @escaping () -> Void) {
        self.column = column
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: column.title)
        _colorID = State(initialValue: column.colorID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Настроить колонку").font(.headline)
            TextField("Название", text: $title)
            Text("Цвет").font(.caption).foregroundStyle(.secondary)
            PalettePicker(selection: $colorID)
            HStack {
                Spacer()
                Button("Отмена", action: onCancel)
                Button("Сохранить") { onSave(title, colorID ?? "lavender") }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onExitCommand(perform: onCancel)
    }
}

struct DestinationSheet: View {
    let title: String
    let columns: [ColumnRecord]
    let onSelect: (UUID) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            ForEach(columns) { column in
                Button {
                    onSelect(column.id)
                } label: {
                    HStack {
                        Circle().fill(Pastel.color(column.colorID)).frame(width: 12, height: 12)
                        Text(column.title)
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Button("Отмена", action: onCancel)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(24)
        .frame(width: 350)
        .onExitCommand(perform: onCancel)
    }
}

private struct DestinationRequest: Identifiable {
    enum Action {
        case move([UUID])
        case deleteColumn(UUID)
    }

    let id = UUID()
    let title: String
    let excludedColumnID: UUID?
    let action: Action
}
