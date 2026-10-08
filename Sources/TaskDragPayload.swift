import Foundation

enum TaskDragPayload {
    private static let prefix = "com.isterkh.dailyboard.tasks:"

    static func encode(_ ids: [UUID]) -> String {
        prefix + ids.map(\.uuidString).joined(separator: ",")
    }

    static func decode(_ text: String) -> [UUID]? {
        guard text.hasPrefix(prefix) else { return nil }
        let tail = text.dropFirst(prefix.count)
        let parts = tail.split(separator: ",")
        guard !parts.isEmpty else { return nil }
        let ids = parts.compactMap { UUID(uuidString: String($0)) }
        return ids.count == parts.count ? ids : nil
    }
}
