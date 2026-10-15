import AppKit
import SwiftUI

final class PickerPanel: NSPanel {
    private static let pickerSize = NSSize(width: 620, height: 390)
    private let model = PickerModel()
    private let wallpaperModel = WallpaperPickerModel()
    private let windowManager: WindowManager
    private var previousApp: NSRunningApplication?
    private var showingWallpaper = false
    private var ignoreEnterUntilNextRunLoop = false

    init(config: KiprConfig, windowManager: WindowManager) {
        self.windowManager = windowManager
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.pickerSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        model.configure(with: config)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown else { return super.sendEvent(event) }
        let isEnter = event.keyCode == 36 || event.keyCode == 76
        // A held Enter can repeat after a screen transition and immediately
        // select an item in the new screen. Treat each physical press once.
        if isEnter && ignoreEnterUntilNextRunLoop { return }
        if event.isARepeat && (isEnter || (123...126).contains(event.keyCode)) { return }

        if showingWallpaper {
            switch event.keyCode {
            case 53: close()
            case 123, 126: wallpaperModel.move(-1)
            case 124, 125: wallpaperModel.move(1)
            case 36, 76:
                wallpaperModel.apply()
                close()
            default: super.sendEvent(event)
            }
            return
        }
        switch event.keyCode {
        case 53:
            if !model.goBack() { close() }
        case 126: model.move(-1)
        case 125: model.move(1)
        case 36, 76: activate(nil)
        default: super.sendEvent(event)
        }
    }

    private func activate(_ index: Int?) {
        switch model.select(index) {
        case .application(let url):
            Actions.open(url)
            close()
        case .command(let command):
            Actions.run(command)
            close()
        case .window(let operation):
            let app = previousApp
            close()
            app?.activate()
            windowManager.perform(operation, in: app)
        case .submenu(let children):
            model.push(children)
        case .wallpaper:
            showWallpaper()
        case .none:
            break
        }
    }

    private var visibleFrame: NSRect { (NSScreen.main ?? NSScreen.screens[0]).visibleFrame }

    private func showWallpaper() {
        showingWallpaper = true
        ignoreEnterUntilNextRunLoop = true
        DispatchQueue.main.async { [weak self] in self?.ignoreEnterUntilNextRunLoop = false }
        wallpaperModel.reload()
        contentView = NSHostingView(rootView: WallpaperPickerView(model: wallpaperModel))
        let frame = visibleFrame
        setFrame(NSRect(x: frame.minX + 24, y: frame.minY + 24, width: frame.width - 48, height: 230), display: true)
        makeKeyAndOrderFront(nil)
    }

    func showPicker(reset: Bool = true) {
        showingWallpaper = false
        if reset { model.reset() }
        contentView = PickerContentView(model: model) { [weak self] in self?.activate($0) }
        setContentSize(Self.pickerSize)
        let frame = visibleFrame
        setFrameOrigin(NSPoint(x: frame.midX - self.frame.width / 2, y: frame.midY - self.frame.height / 2))
        if reset { previousApp = NSWorkspace.shared.frontmostApplication }
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self] in
            (self?.contentView as? PickerContentView)?.focusSearch()
        }
    }
}
