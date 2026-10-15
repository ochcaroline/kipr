import AppKit

enum Actions {
    @MainActor static func open(_ url: URL) {
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    static func run(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        try? process.run()
    }
}
