import Foundation

struct KiprConfig: Codable {
    struct Shortcut: Codable {
        let key: String
        let modifiers: [String]
    }

    struct Action: Codable {
        let type: String?
        let path: String?
        let command: String?
        let items: [String: Action]?
        let shortcut: String?
        var operation: String?
    }

    let pickerShortcut: Shortcut
    let actions: [String: Action]
    var windowGap: Double?
}

private struct LegacyConfig: Decodable {
    struct Application: Decodable {
        let title: String
        let path: String
        let shortcut: String?
    }
    struct Action: Decodable {
        let title: String
        let type: String?
        let command: String?
        let items: [Action]?
        let shortcut: String?
    }

    let pickerShortcut: KiprConfig.Shortcut
    let applications: [Application]
    let actions: [Action]

    func migrated() -> KiprConfig {
        var result = Dictionary(uniqueKeysWithValues: applications.map {
            ($0.title, KiprConfig.Action(type: "application", path: $0.path, command: nil, items: nil, shortcut: $0.shortcut))
        })
        for action in actions {
            result[action.title] = KiprConfig.Action(
                type: action.type ?? (action.title.caseInsensitiveCompare("Wallpaper") == .orderedSame ? "wallpaper" : "command"),
                path: nil,
                command: action.command,
                items: action.items.map { Dictionary(uniqueKeysWithValues: $0.map { ($0.title, KiprConfig.Action(type: $0.type, path: nil, command: $0.command, items: nil, shortcut: $0.shortcut)) }) },
                shortcut: action.shortcut
            )
        }
        return KiprConfig(pickerShortcut: pickerShortcut, actions: result)
    }
}

enum ConfigStore {
    private static let windowActions: [String: KiprConfig.Action] = [
        "Left half": .init(type: "window", path: nil, command: nil, items: nil, shortcut: "ctrl+alt+h", operation: "left-half"),
        "Right half": .init(type: "window", path: nil, command: nil, items: nil, shortcut: "ctrl+alt+l", operation: "right-half"),
        "Maximize": .init(type: "window", path: nil, command: nil, items: nil, shortcut: "ctrl+alt+return", operation: "maximize"),
        "Previous display": .init(type: "window", path: nil, command: nil, items: nil, shortcut: "ctrl+alt+cmd+h", operation: "previous-display"),
        "Next display": .init(type: "window", path: nil, command: nil, items: nil, shortcut: "ctrl+alt+cmd+l", operation: "next-display")
    ]

    static func load() -> KiprConfig {
        let fileManager = FileManager.default
        let directory = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".kipr")
        let userURL = directory.appendingPathComponent("config.json")
        let legacyURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".kipr.json")
        let data: Data

        do {
            if fileManager.fileExists(atPath: userURL.path) {
                data = try Data(contentsOf: userURL)
            } else if fileManager.fileExists(atPath: legacyURL.path) {
                data = try Data(contentsOf: legacyURL)
            } else {
                guard let defaultURL = Bundle.main.url(forResource: "config", withExtension: "json") else {
                    fatalError("Missing bundled default config.json")
                }
                data = try Data(contentsOf: defaultURL)
            }
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: directory.appendingPathComponent("wallpapers"), withIntermediateDirectories: true)
        } catch {
            fatalError("Could not read or create Kipr configuration: \(error)")
        }

        if let config = try? JSONDecoder().decode(KiprConfig.self, from: data) {
            if !fileManager.fileExists(atPath: userURL.path) {
                try? data.write(to: userURL, options: .atomic)
            }
            return withBuiltInWindowActions(config)
        }

        guard let legacy = try? JSONDecoder().decode(LegacyConfig.self, from: data) else {
            fatalError("Invalid ~/.kipr/config.json")
        }
        let migrated = legacy.migrated()
        if let migratedData = try? JSONEncoder().encode(migrated) {
            try? migratedData.write(to: userURL, options: .atomic)
        }
        return withBuiltInWindowActions(migrated)
    }

    private static func withBuiltInWindowActions(_ config: KiprConfig) -> KiprConfig {
        var actions = config.actions.filter { $0.value.type != "window" }
        actions.merge(windowActions) { _, builtIn in builtIn }
        return KiprConfig(pickerShortcut: config.pickerShortcut, actions: actions, windowGap: config.windowGap)
    }
}
