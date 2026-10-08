import SwiftUI

struct ArchiveView: View {
    @ObservedObject var store: BoardStore
    let board: BoardRecord

    @Environment(\.dismiss) private var dismiss
    @State private var restoringTask: TaskRecord?
    @State private var deletingTask: TaskRecord?

    private var archived: [TaskRecord] { store.archivedTasks(in: board.id) }
    private var columns: [ColumnRecord] { store.columns(in: board.id) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Архив").font(.title2.weight(.semibold))
                    Text(board.title).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Готово") { dismiss() }
            }
            .padding(.horizontal, 20)
            .frame(height: 88)
            Divider()
            if archived.isEmpty {
                ContentUnavailableView("Архив пуст", systemImage: "archivebox")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(archived) { task in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(task.colorID == nil ? .clear : Pastel.color(task.colorID))
                            .frame(width: 4, height: 42)
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.isCompleted ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                            if !task.details.isEmpty {
                                Text(task.details).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        Button("Восстановить…") { restoringTask = task }
                            .disabled(columns.isEmpty)
                        Button(role: .destructive) { deletingTask = task } label: {
                            Image(systemName: "trash")
                        }
                        .help("Удалить окончательно")
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
            if columns.isEmpty && !archived.isEmpty {
                Text("Чтобы восстановить задачу, сначала создайте колонку на доске.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
        }
        .frame(minWidth: 650, minHeight: 450)
        .sheet(item: $restoringTask) { task in
            DestinationSheet(title: "Восстановить в колонку", columns: columns) { columnID in
                if store.restoreTask(task.id, to: columnID) { restoringTask = nil }
            } onCancel: {
                restoringTask = nil
            }
        }
        .alert("Удалить задачу окончательно?", isPresented: Binding(get: { deletingTask != nil }, set: { if !$0 { deletingTask = nil } })) {
            Button("Удалить", role: .destructive) {
                if let task = deletingTask { store.deleteTasks([task.id]) }
                deletingTask = nil
            }
            Button("Отмена", role: .cancel) { deletingTask = nil }
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }
}
