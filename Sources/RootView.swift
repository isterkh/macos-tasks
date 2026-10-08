import SwiftUI

struct RootView: View {
    @StateObject private var store = BoardStore(inMemory: ProcessInfo.processInfo.arguments.contains("--ui-testing"))
    @State private var selectedBoardID: UUID?
    @State private var boardDialog: BoardDialog?
    @State private var deletingBoard: BoardRecord?

    private var selectedBoard: BoardRecord? {
        store.boards.first { $0.id == selectedBoardID }
    }

    var body: some View {
        Group {
            if let startupError = store.startupError {
                ContentUnavailableView("Не удалось открыть задачи", systemImage: "externaldrive.badge.exclamationmark", description: Text(startupError))
            } else {
                NavigationSplitView {
                    sidebar
                        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
                } detail: {
                    if let board = selectedBoard {
                        BoardView(store: store, board: board)
                            .id(board.id)
                    } else {
                        ContentUnavailableView("Пока нет доски", systemImage: "rectangle.split.3x1", description: Text("Создайте доску, затем добавьте колонки и задачи."))
                    }
                }
            }
        }
        .sheet(item: $boardDialog) { dialog in
            NameSheet(title: dialog.boardID == nil ? "Новая доска" : "Название доски", initialName: dialog.initialName) { name in
                if let boardID = dialog.boardID {
                    if store.renameBoard(boardID, title: name) { boardDialog = nil }
                } else {
                    if let id = store.createBoard(name) {
                        selectedBoardID = id
                        boardDialog = nil
                    }
                }
            } onCancel: {
                boardDialog = nil
            }
        }
        .alert("Удалить доску?", isPresented: Binding(get: { deletingBoard != nil }, set: { if !$0 { deletingBoard = nil } })) {
            Button("Удалить доску и все задачи", role: .destructive) {
                guard let board = deletingBoard else { return }
                if store.deleteBoard(board.id) { selectedBoardID = store.boards.first?.id }
                deletingBoard = nil
            }
            Button("Отмена", role: .cancel) { deletingBoard = nil }
        } message: {
            Text("Активные и архивные задачи этой доски будут удалены окончательно.")
        }
        .alert("Ошибка сохранения", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("ОК") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onAppear {
            if selectedBoardID == nil { selectedBoardID = store.boards.first?.id }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedBoardID) {
                ForEach(store.boards) { board in
                    Label(board.title, systemImage: "rectangle.split.3x1")
                        .tag(board.id)
                        .contextMenu {
                            Button("Переименовать…") {
                                boardDialog = BoardDialog(boardID: board.id, initialName: board.title)
                            }
                            Button("Выше") { store.moveBoard(board.id, offset: -1) }
                            .disabled(board.position == 0)
                            Button("Ниже") { store.moveBoard(board.id, offset: 1) }
                            .disabled(board.position >= store.boards.count - 1)
                            Divider()
                            Button("Удалить…", role: .destructive) { deletingBoard = board }
                        }
                }
            }
            HStack {
                Button {
                    boardDialog = BoardDialog(boardID: nil, initialName: "")
                } label: {
                    Label("Новая доска", systemImage: "plus")
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(12)
        }
        .navigationTitle("Доски")
    }
}

private struct BoardDialog: Identifiable {
    let id = UUID()
    let boardID: UUID?
    let initialName: String
}

struct NameSheet: View {
    let title: String
    let initialName: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @FocusState private var focused: Bool

    init(title: String, initialName: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self.initialName = initialName
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: initialName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)
            TextField("Название", text: $name)
                .focused($focused)
                .onSubmit(save)
            HStack {
                Spacer()
                Button("Отмена", action: onCancel)
                Button("Сохранить", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onAppear { focused = true }
        .onExitCommand(perform: onCancel)
    }

    private func save() {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        onSave(clean)
    }
}
