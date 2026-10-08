import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
    @State private var dropTargetColumnID: UUID?
    @State private var dropTargetTaskID: UUID?
    @State private var draggingIDs: [UUID] = []
    @State private var dragTitle = ""
    @State private var dragLocation: CGPoint?
    @State private var columnFrames: [UUID: CGRect] = [:]
    @State private var taskFrames: [UUID: CGRect] = [:]
    @State private var draggingColumnID: UUID?
    @State private var columnDragLocation: CGPoint?
    @State private var columnDropBeforeID: UUID?
    @State private var columnDropAtEnd = false
    @State private var hoveredColumnID: UUID?
    @State private var hoveredTaskID: UUID?
    @State private var hoveredCheckboxID: UUID?
    @FocusState private var focusedQuickTaskColumnID: UUID?

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
                                focusedQuickTaskColumnID = nil
                                showingNewColumn = true
                            } label: {
                                Label("Новая колонка", systemImage: "plus")
                                    .frame(width: 260, height: 50)
                            }
                            .buttonStyle(.bordered)
                            .modifier(HoverHighlight())
                        }
                        .padding(16)
                    }
                    .background {
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { focusedQuickTaskColumnID = nil }
                    }
                }
            }
            if editorDraft != nil {
                editorOverlay
            }
            if let dragLocation, !draggingIDs.isEmpty {
                Label(draggingIDs.count > 1 ? "\(draggingIDs.count) задач" : dragTitle, systemImage: "hand.draw")
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                    .position(dragLocation)
                    .allowsHitTesting(false)
                    .zIndex(10)
            }
            if let columnDragLocation, let draggingColumnID,
               let column = boardColumns.first(where: { $0.id == draggingColumnID }) {
                Label(column.title, systemImage: "rectangle.split.3x1")
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Pastel.color(column.colorID))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                    .position(columnDragLocation)
                    .allowsHitTesting(false)
                    .zIndex(10)
            }
        }
        .coordinateSpace(name: "board")
        .onPreferenceChange(ColumnFrameKey.self) { columnFrames = $0 }
        .onPreferenceChange(TaskFrameKey.self) { taskFrames = $0 }
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
            Text(board.title)
                .font(.title2.weight(.semibold))
                .onTapGesture { focusedQuickTaskColumnID = nil }
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
                .modifier(HoverHighlight())
            }
            Button {
                focusedQuickTaskColumnID = nil
                showingArchive = true
            } label: {
                Label("Архив", systemImage: "archivebox")
            }
            .modifier(HoverHighlight())
            Button {
                focusedQuickTaskColumnID = nil
                showingNewColumn = true
            } label: {
                Label("Колонка", systemImage: "plus")
            }
            .modifier(HoverHighlight())
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
            HStack(spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(column.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .onTapGesture { focusedQuickTaskColumnID = nil }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5, coordinateSpace: .named("board"))
                        .onChanged { value in updateColumnDrag(column, at: value.location) }
                        .onEnded { value in finishColumnDrag(at: value.location) }
                )
                .help("Перетащить колонку")
                Text("\(open.count + done.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                columnMenu(column, completedTasks: done)
            }
            .padding(12)
            HStack(spacing: 6) {
                TextField("Быстрая задача", text: quickBinding(for: column.id))
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedQuickTaskColumnID, equals: column.id)
                    .onSubmit { addQuickTask(in: column.id) }
                    .onExitCommand { focusedQuickTaskColumnID = nil }
                Button {
                    addQuickTask(in: column.id)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .modifier(HoverHighlight(cornerRadius: 6))
                .help("Добавить задачу")
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            ScrollView(.vertical) {
                LazyVStack(spacing: 8) {
                    ForEach(open) { task in
                        taskView(task, in: column)
                            .id("\(task.id)-open")
                    }
                    if !done.isEmpty {
                        HStack(spacing: 8) {
                            Rectangle().frame(height: 1)
                            Text("Завершено").font(.caption2).fixedSize()
                            Rectangle().frame(height: 1)
                        }
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                    }
                    ForEach(done) { task in
                        taskView(task, in: column)
                            .id("\(task.id)-done")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
            .background {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { focusedQuickTaskColumnID = nil }
            }
        }
        .frame(width: 290)
        .background {
            Color(nsColor: .textBackgroundColor)
                .overlay(Pastel.color(column.colorID).opacity(0.18))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(dropTargetColumnID == column.id ? Color.accentColor : Color.primary.opacity(hoveredColumnID == column.id ? 0.18 : 0.08), lineWidth: dropTargetColumnID == column.id ? 2 : 1)
        }
        .overlay(alignment: .leading) {
            if draggingColumnID != nil && columnDropBeforeID == column.id {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 4)
                    .padding(.vertical, 12)
                    .offset(x: -10)
            }
        }
        .overlay(alignment: .trailing) {
            if columnDropAtEnd,
               column.id == boardColumns.last(where: { $0.id != draggingColumnID })?.id {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 4)
                    .padding(.vertical, 12)
                    .offset(x: 10)
            }
        }
        .shadow(color: .black.opacity(hoveredColumnID == column.id ? 0.075 : 0.035), radius: hoveredColumnID == column.id ? 12 : 5, y: 3)
        .onHover { hoveredColumnID = $0 ? column.id : nil }
        .animation(.easeOut(duration: 0.16), value: hoveredColumnID == column.id)
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: ColumnFrameKey.self, value: [column.id: geometry.frame(in: .named("board"))])
            }
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
        .modifier(HoverHighlight(cornerRadius: 6))
        .help("Действия с колонкой")
    }

    private func taskView(_ task: TaskRecord, in column: ColumnRecord) -> some View {
        HStack(alignment: .center, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(task.colorID == nil ? .clear : Pastel.color(task.colorID))
                .frame(width: 5)
            Button {
                store.toggleTask(task.id)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
                    .frame(width: 36, height: 36)
                    .background {
                        Circle().fill(hoveredCheckboxID == task.id ? Color.accentColor.opacity(0.09) : .clear)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
            .accessibilityLabel(task.isCompleted ? "Отметить незавершённой" : "Завершить задачу")
            .help(task.isCompleted ? "Отметить незавершённой" : "Завершить задачу")
            .onHover { hoveredCheckboxID = $0 ? task.id : nil }
            .animation(.easeOut(duration: 0.15), value: hoveredCheckboxID == task.id)
            .padding(.leading, 5)
            .padding(.trailing, 3)
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
            .contentShape(Rectangle())
            .onTapGesture { handleTaskClick(task, column: column) }
        }
        .frame(minHeight: 42)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(selectedIDs.contains(task.id) || dropTargetTaskID == task.id ? Color.accentColor : Color.primary.opacity(hoveredTaskID == task.id ? 0.2 : 0.07), lineWidth: selectedIDs.contains(task.id) || dropTargetTaskID == task.id ? 2 : 1)
        }
        .shadow(color: .black.opacity(hoveredTaskID == task.id ? 0.1 : 0), radius: 7, y: 2)
        .onHover { inside in
            hoveredTaskID = inside ? task.id : nil
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .animation(.easeOut(duration: 0.15), value: hoveredTaskID == task.id)
        .contentShape(Rectangle())
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: TaskFrameKey.self, value: [task.id: geometry.frame(in: .named("board"))])
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .named("board"))
                .onChanged { value in updateDrag(task: task, at: value.location) }
                .onEnded { value in finishDrag(at: value.location) }
        )
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
        focusedQuickTaskColumnID = nil
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

    private func dragDestination(at point: CGPoint) -> (columnID: UUID, beforeTaskID: UUID?)? {
        guard let column = boardColumns.first(where: { columnFrames[$0.id]?.contains(point) == true }) else { return nil }
        let tasks = store.tasks(in: column.id, completed: false) + store.tasks(in: column.id, completed: true)
        let before = tasks.first { task in
            !draggingIDs.contains(task.id) && (taskFrames[task.id]?.midY ?? -.infinity) > point.y
        }
        return (column.id, before?.id)
    }

    private func columnDragDestination(at point: CGPoint, movingID: UUID) -> (index: Int, beforeID: UUID?)? {
        let frames = boardColumns.compactMap { columnFrames[$0.id] }
        guard let minX = frames.map(\.minX).min(), let maxX = frames.map(\.maxX).max(),
              point.x >= minX, point.x <= maxX,
              frames.contains(where: { point.y >= $0.minY && point.y <= $0.maxY }) else { return nil }
        let remaining = boardColumns.filter { $0.id != movingID }
        let index = remaining.firstIndex { point.x < (columnFrames[$0.id]?.midX ?? .infinity) } ?? remaining.count
        return (index, remaining.indices.contains(index) ? remaining[index].id : nil)
    }

    private func updateColumnDrag(_ column: ColumnRecord, at point: CGPoint) {
        if draggingColumnID == nil {
            draggingColumnID = column.id
            focusedQuickTaskColumnID = nil
        }
        columnDragLocation = point
        let destination = columnDragDestination(at: point, movingID: column.id)
        columnDropBeforeID = destination?.beforeID
        columnDropAtEnd = destination != nil && destination?.beforeID == nil
    }

    private func finishColumnDrag(at point: CGPoint) {
        let destination = draggingColumnID.flatMap { columnDragDestination(at: point, movingID: $0) }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if let draggingColumnID, let destination {
                store.reorderColumn(draggingColumnID, to: destination.index)
            }
            draggingColumnID = nil
            columnDragLocation = nil
            columnDropBeforeID = nil
            columnDropAtEnd = false
        }
    }

    private func updateDrag(task: TaskRecord, at point: CGPoint) {
        if draggingIDs.isEmpty {
            draggingIDs = dragIDs(for: task)
            dragTitle = task.title
        }
        dragLocation = point
        let destination = dragDestination(at: point)
        dropTargetColumnID = destination?.columnID
        dropTargetTaskID = destination?.beforeTaskID
    }

    private func finishDrag(at point: CGPoint) {
        let destination = dragDestination(at: point)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if let destination, !draggingIDs.isEmpty {
                store.placeTasks(draggingIDs, to: destination.columnID, before: destination.beforeTaskID)
                selectedIDs.removeAll()
            }
            draggingIDs = []
            dragLocation = nil
            dropTargetColumnID = nil
            dropTargetTaskID = nil
        }
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

struct HoverHighlight: ViewModifier {
    var cornerRadius: CGFloat = 8
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(3)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isHovered ? Color.accentColor.opacity(0.08) : .clear)
            }
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

private struct ColumnFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct TaskFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] { [:] }

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
