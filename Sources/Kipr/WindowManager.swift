import AppKit
import ApplicationServices
import KiprCore

@MainActor
final class WindowManager {
    private let gap: CGFloat

    init(gap: Double?) { self.gap = CGFloat(gap ?? 0) }

    /// Acts on `app`'s focused window, or the frontmost app's when nil.
    func perform(_ operation: WindowOperation, in app: NSRunningApplication? = nil) {
        guard AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary),
              let app = app ?? NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != getpid(),
              let window = focusedWindow(of: app),
              let position: CGPoint = read(window, kAXPositionAttribute, .cgPoint, .zero),
              let size: CGSize = read(window, kAXSizeAttribute, .cgSize, .zero) else { return }

        let current = CGRect(origin: position, size: size)
        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
        guard let index = screens.indices.max(by: { overlap(current, screens[$0]) < overlap(current, screens[$1]) }) else { return }
        let step = operation == .nextDisplay ? 1 : operation == .previousDisplay ? -1 : 0
        let target = screens[(index + step + screens.count) % screens.count]

        let frame = WindowLayout.frame(for: operation, in: axRect(target.visibleFrame), gap: gap, windowSize: size)
        var origin = frame.origin, newSize = frame.size
        // Size first so the window fits the target display, then position, then size again
        // because macOS may clamp the first resize while the window is on another display.
        set(window, kAXSizeAttribute, .cgSize, &newSize)
        set(window, kAXPositionAttribute, .cgPoint, &origin)
        set(window, kAXSizeAttribute, .cgSize, &newSize)
    }

    private func overlap(_ rect: CGRect, _ screen: NSScreen) -> CGFloat {
        let i = rect.intersection(axRect(screen.frame))
        return i.isNull ? 0 : i.width * i.height
    }

    /// AppKit uses a bottom-left origin relative to the primary screen; Accessibility uses top-left.
    private func axRect(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: NSScreen.screens[0].frame.height - r.maxY, width: r.width, height: r.height)
    }

    private func focusedWindow(of app: NSRunningApplication) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(app.processIdentifier),
                                            kAXFocusedWindowAttribute as CFString, &value) == .success else { return nil }
        return (value as! AXUIElement)
    }

    private func read(_ window: AXUIElement, _ attribute: String, _ type: AXValueType, _ zero: CGPoint) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success,
              let value else { return nil }
        let axValue = value as! AXValue
        var result = zero
        return AXValueGetValue(axValue, type, &result) ? result : nil
    }

    private func read(_ window: AXUIElement, _ attribute: String, _ type: AXValueType, _ zero: CGSize) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success,
              let value else { return nil }
        let axValue = value as! AXValue
        var result = zero
        return AXValueGetValue(axValue, type, &result) ? result : nil
    }

    private func set(_ window: AXUIElement, _ attribute: String, _ type: AXValueType, _ value: inout CGPoint) {
        guard let axValue = AXValueCreate(type, &value) else { return }
        AXUIElementSetAttributeValue(window, attribute as CFString, axValue)
    }

    private func set(_ window: AXUIElement, _ attribute: String, _ type: AXValueType, _ value: inout CGSize) {
        guard let axValue = AXValueCreate(type, &value) else { return }
        AXUIElementSetAttributeValue(window, attribute as CFString, axValue)
    }
}
