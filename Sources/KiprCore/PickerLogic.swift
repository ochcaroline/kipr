import Foundation

public struct PickerItem: Equatable, Sendable {
    public let title: String
    public let shortcut: String?

    public init(title: String, shortcut: String? = nil) {
        self.title = title
        self.shortcut = shortcut
    }
}

public enum PickerLogic {
    public static func filtered(_ items: [PickerItem], query: String) -> [PickerItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return items }
        return items.filter { $0.title.lowercased().contains(query) }
    }

    public static func moveSelection(current: Int, offset: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (current + offset + count) % count
    }
}
