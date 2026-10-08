import AppKit
import Foundation
import UniformTypeIdentifiers

enum TaskDragPayload {
    private static let prefix = "com.isterkh.dailyboard.tasks:"
    static let contentType = UTType(exportedAs: "com.isterkh.dailyboard.tasks")

    static func itemProvider(for ids: [UUID]) -> NSItemProvider {
        let text = encode(ids)
        let provider = NSItemProvider(object: NSString(string: text))
        provider.registerDataRepresentation(forTypeIdentifier: contentType.identifier, visibility: .ownProcess) { completion in
            completion(text.data(using: .utf8), nil)
            return nil
        }
        return provider
    }

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
