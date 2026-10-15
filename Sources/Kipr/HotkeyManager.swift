import Carbon.HIToolbox

final class HotkeyManager {
    private var handler: EventHandlerRef?
    private var hotkeys: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]

    func registerPicker(_ shortcut: KiprConfig.Shortcut, onPress: @escaping () -> Void) throws {
        try register(key: shortcut.key, modifiers: shortcut.modifiers, id: 1, onPress: onPress)
    }

    func registerAction(_ shortcut: String, id: UInt32, onPress: @escaping () -> Void) throws {
        let parts = shortcut.lowercased().split(separator: "+").map(String.init)
        guard let key = parts.last else { throw HotkeyError.invalidShortcut(shortcut) }
        try register(key: key, modifiers: Array(parts.dropLast()), id: id, onPress: onPress)
    }

    private func register(key: String, modifiers modifierNames: [String], id: UInt32, onPress: @escaping () -> Void) throws {
        if handler == nil {
            var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let callback: EventHandlerUPP = { _, event, userData in
                guard let event, let userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                manager.actions[hotKeyID.id]?()
                return noErr
            }
            let status = InstallEventHandler(
                GetEventDispatcherTarget(), callback, 1, &eventSpec,
                Unmanaged.passUnretained(self).toOpaque(), &handler
            )
            guard status == noErr else { throw HotkeyError.status(status) }
        }

        let id = EventHotKeyID(signature: OSType(0x4B495052), id: id)
        var hotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(
            try keyCode(for: key), try modifiers(for: modifierNames), id,
            GetEventDispatcherTarget(), 0, &hotKey
        )
        guard status == noErr, let hotKey else { throw HotkeyError.status(status) }
        hotkeys[id.id] = hotKey
        actions[id.id] = onPress
    }

    func unregister() {
        for hotKey in hotkeys.values { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotkeys.removeAll()
        actions.removeAll()
        handler = nil
    }

    private static let keyCodes: [String: Int] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
        "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38,
        "k": 40, "n": 45, "m": 46,
        "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
        "left": 123, "right": 124, "down": 125, "up": 126,
        "space": 49, "return": 36, "enter": 36, "escape": 53, "esc": 53, "tab": 48,
    ]

    private func keyCode(for key: String) throws -> UInt32 {
        guard let code = Self.keyCodes[key] else { throw HotkeyError.invalidShortcut(key) }
        return UInt32(code)
    }

    private func modifiers(for values: [String]) throws -> UInt32 {
        var result: UInt32 = 0
        for value in values { result |= try modifier(for: value) }
        return result
    }

    private func modifier(for value: String) throws -> UInt32 {
        switch value {
        case "option", "alt": return UInt32(optionKey)
        case "command", "cmd": return UInt32(cmdKey)
        case "control", "ctrl": return UInt32(controlKey)
        case "shift": return UInt32(shiftKey)
        default: throw HotkeyError.invalidShortcut(value)
        }
    }
}

private enum HotkeyError: LocalizedError {
    case status(OSStatus)
    case invalidShortcut(String)

    var errorDescription: String? {
        switch self {
        case .status(let status): return "Carbon hot-key registration failed (\(status))"
        case .invalidShortcut(let shortcut): return "Unsupported shortcut: \(shortcut)"
        }
    }
}
