import AppKit
import KiprCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var config = ConfigStore.load()
    private var panel: PickerPanel!
    private var windowManager: WindowManager!
    private var hotkeyManager: HotkeyManager!
    private var statusItem: NSStatusItem!
    private let loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLogin), keyEquivalent: "")
    private let reloadItem = NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let start = CFAbsoluteTimeGetCurrent()
        windowManager = WindowManager(gap: config.windowGap)
        panel = PickerPanel(config: config, windowManager: windowManager)
        NSLog("Kipr picker prepared in %.3fs", CFAbsoluteTimeGetCurrent() - start)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "K"
        let menu = NSMenu()
        menu.delegate = self
        loginItem.target = self
        menu.addItem(loginItem)
        reloadItem.target = self
        menu.addItem(reloadItem)
        let quitItem = NSMenuItem(title: "Quit Kipr", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu

        registerHotkeys()
    }

    private func registerHotkeys() {
        hotkeyManager = HotkeyManager()
        do {
            try hotkeyManager.registerPicker(config.pickerShortcut) { [weak self] in self?.togglePanel() }
            for (index, action) in config.actions.values.enumerated() {
                guard let shortcut = action.shortcut else { continue }
                let id = UInt32(index + 2)
                switch action.type {
                case "application":
                    guard let path = action.path else { continue }
                    try hotkeyManager.registerAction(shortcut, id: id) { Actions.open(URL(fileURLWithPath: path)) }
                case "command":
                    guard let command = action.command else { continue }
                    try hotkeyManager.registerAction(shortcut, id: id) { Actions.run(command) }
                case "window":
                    guard let operation = action.operation.flatMap(WindowOperation.init) else { continue }
                    try hotkeyManager.registerAction(shortcut, id: id) { [windowManager] in windowManager?.perform(operation) }
                default:
                    continue
                }
            }
        } catch {
            statusItem.button?.title = "K!"
            NSLog("Could not register configured picker shortcut: %@", error.localizedDescription)
        }
    }

    @objc private func reloadConfig() {
        panel.close()
        hotkeyManager.unregister()
        config = ConfigStore.load()
        windowManager = WindowManager(gap: config.windowGap)
        panel = PickerPanel(config: config, windowManager: windowManager)
        registerHotkeys()
    }

    private func togglePanel() {
        if panel.isVisible {
            panel.close()
        } else {
            panel.showPicker()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSLog("Could not change login item: %@", error.localizedDescription)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
    }
}
