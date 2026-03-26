import AppKit

struct KeyboardShortcutDisplay {
    static func string(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        charactersIgnoringModifiers: String?
    ) -> String? {
        guard let key = keyName(for: keyCode, charactersIgnoringModifiers: charactersIgnoringModifiers) else {
            return nil
        }

        return modifierSymbols(from: modifierFlags) + key
    }

    private static func modifierSymbols(from flags: NSEvent.ModifierFlags) -> String {
        let deviceIndependentFlags = flags.intersection(.deviceIndependentFlagsMask)
        var symbols = ""

        if deviceIndependentFlags.contains(.command) {
            symbols += "⌘"
        }
        if deviceIndependentFlags.contains(.control) {
            symbols += "⌃"
        }
        if deviceIndependentFlags.contains(.option) {
            symbols += "⌥"
        }
        if deviceIndependentFlags.contains(.shift) {
            symbols += "⇧"
        }

        return symbols
    }

    private static func keyName(for keyCode: UInt16, charactersIgnoringModifiers: String?) -> String? {
        switch keyCode {
        case 36:
            return "Return"
        case 48:
            return "Tab"
        case 49:
            return "Space"
        case 51, 117:
            return "Delete"
        case 53:
            return "Escape"
        case 123:
            return "←"
        case 124:
            return "→"
        case 125:
            return "↓"
        case 126:
            return "↑"
        case 55, 54, 56, 60, 59, 62, 58, 61, 57:
            return nil
        default:
            break
        }

        guard let charactersIgnoringModifiers else {
            return nil
        }

        let trimmed = charactersIgnoringModifiers.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        return trimmed.uppercased()
    }

    static func matches(event: NSEvent, shortcut: String) -> Bool {
        guard event.type == .keyDown else {
            return false
        }

        return matches(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            shortcut: shortcut
        )
    }

    static func matches(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        charactersIgnoringModifiers: String?,
        shortcut: String
    ) -> Bool {
        string(
            keyCode: keyCode,
            modifierFlags: modifierFlags,
            charactersIgnoringModifiers: charactersIgnoringModifiers
        ) == shortcut
    }
}
