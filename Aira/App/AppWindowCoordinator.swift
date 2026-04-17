import AppKit

enum AppWindowCoordinator {
    static let managerWindowIdentifier = NSUserInterfaceItemIdentifier("aira.manager.window")
    static let settingsWindowIdentifier = NSUserInterfaceItemIdentifier("aira.settings.window")
    static let transientMenuBarWindowIdentifier = NSUserInterfaceItemIdentifier("aira.menu-bar.window")
    private static let standardManagerWindowStyleMask: NSWindow.StyleMask = [
        .titled,
        .closable,
        .miniaturizable,
        .resizable
    ]

    @MainActor
    static func markManagerWindow(_ window: NSWindow?) {
        window?.identifier = managerWindowIdentifier
    }

    @MainActor
    static func markSettingsWindow(_ window: NSWindow?) {
        window?.identifier = settingsWindowIdentifier
    }

    @MainActor
    static func markTransientMenuBarWindow(_ window: NSWindow?) {
        guard let window, !isManagerWindowIdentifier(window.identifier) else {
            return
        }

        window.identifier = transientMenuBarWindowIdentifier
        removeStandardWindowChrome(from: window)
    }

    @MainActor
    static func managerWindow(in application: NSApplication? = nil) -> NSWindow? {
        let application = application ?? .shared
        return application.windows.first(where: isManagerWindow)
    }

    @MainActor
    static func settingsWindow(in application: NSApplication? = nil) -> NSWindow? {
        let application = application ?? .shared
        return application.windows.first(where: isSettingsWindow)
    }

    @MainActor
    static func currentTransientMenuBarWindow(in application: NSApplication? = nil) -> NSWindow? {
        let application = application ?? .shared
        guard let keyWindow = application.keyWindow, isTransientMenuBarWindow(keyWindow) else {
            return nil
        }
        return keyWindow
    }

    @MainActor
    static func hideManagerWindowForSession(in application: NSApplication? = nil) {
        let application = application ?? .shared
        closeAllTransientMenuBarWindows(in: application)
        managerWindow(in: application)?.orderOut(nil)
        application.setActivationPolicy(.accessory)
        if let finder = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
            if #available(macOS 14.0, *) {
                finder.activate()
            } else {
                finder.activate(options: .activateIgnoringOtherApps)
            }
        }
    }

    @MainActor
    static func restoreManagerWindow(
        in application: NSApplication? = nil,
        fallbackWindow: NSWindow? = nil
    ) {
        let application = application ?? .shared
        application.setActivationPolicy(.regular)

        let identified = managerWindow(in: application)
        let fallback = validManagerFallbackWindow(fallbackWindow)
        let window = identified ?? fallback

        AiraLogger.shared.info(
            "restoreManagerWindow: identified=\(identified != nil) fallback=\(fallback != nil) totalWindows=\(application.windows.count) styleMask=\(window?.styleMask.rawValue ?? 0) isVisible=\(window?.isVisible ?? false) frame=\(window?.frame ?? .zero)",
            category: "window"
        )

        guard let window else {
            AiraLogger.shared.info("restoreManagerWindow: no window found, activating app only", category: "window")
            activateApp(application)
            return
        }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        // If the window was found via fallback (SwiftUI recreated it),
        // stamp it with the manager identifier so future restores find it.
        if identified == nil {
            markManagerWindow(window)
        }

        // After orderOut + activation-policy round-trips, macOS can leave a
        // SwiftUI WindowGroup without the standard titlebar/traffic-light
        // chrome. Repair only the validated manager candidate selected above;
        // transient menu-bar windows are rejected before this point.
        restoreStandardManagerWindowChrome(on: window)

        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        activateApp(application)
    }

    @MainActor
    static func closeTransientMenuBarWindow(_ window: NSWindow?) {
        guard let window, isTransientMenuBarWindow(window) else {
            return
        }

        window.orderOut(nil)
        window.close()
    }

    @MainActor
    static func closeAllTransientMenuBarWindows(in application: NSApplication? = nil) {
        let application = application ?? .shared
        let transientWindows = application.windows.filter { isTransientMenuBarWindow($0) }

        for window in transientWindows {
            window.orderOut(nil)
            window.close()
        }
    }

    @MainActor
    private static func isManagerWindow(_ window: NSWindow) -> Bool {
        isManagerWindowIdentifier(window.identifier)
    }

    @MainActor
    private static func isSettingsWindow(_ window: NSWindow) -> Bool {
        isSettingsWindowIdentifier(window.identifier)
    }

    @MainActor
    private static func isTransientMenuBarWindow(_ window: NSWindow) -> Bool {
        isTransientMenuBarWindow(
            identifier: window.identifier,
            isPanel: window is NSPanel,
            title: window.title,
            sharingType: window.sharingType,
            level: window.level
        )
    }

    static func isManagerWindowIdentifier(_ identifier: NSUserInterfaceItemIdentifier?) -> Bool {
        identifier == managerWindowIdentifier
    }

    static func isSettingsWindowIdentifier(_ identifier: NSUserInterfaceItemIdentifier?) -> Bool {
        identifier == settingsWindowIdentifier
    }

    static func isTransientMenuBarWindowIdentifier(_ identifier: NSUserInterfaceItemIdentifier?) -> Bool {
        identifier == transientMenuBarWindowIdentifier
    }

    static func isTransientMenuBarWindow(
        identifier: NSUserInterfaceItemIdentifier?,
        isPanel: Bool,
        title: String,
        sharingType: NSWindow.SharingType = .readOnly,
        level: NSWindow.Level = .normal
    ) -> Bool {
        if isTransientMenuBarWindowIdentifier(identifier) {
            return true
        }

        return !isManagerWindowIdentifier(identifier)
            && title.isEmpty
            && sharingType != .none
            && level != .screenSaver
    }

    static func isManagerRestoreFallbackCandidate(
        identifier: NSUserInterfaceItemIdentifier?,
        isPanel: Bool,
        title: String,
        sharingType: NSWindow.SharingType = .readOnly,
        level: NSWindow.Level = .normal
    ) -> Bool {
        guard !isTransientMenuBarWindowIdentifier(identifier) else {
            return false
        }

        guard !isPanel, sharingType != .none, level != .screenSaver else {
            return false
        }

        return isManagerWindowIdentifier(identifier)
    }

    static func repairedManagerWindowStyleMask(_ styleMask: NSWindow.StyleMask) -> NSWindow.StyleMask {
        var repaired = styleMask
        repaired.formUnion(standardManagerWindowStyleMask)
        return repaired
    }

    @MainActor
    private static func activateApp(_ application: NSApplication) {
        if #available(macOS 14.0, *) {
            application.activate()
        } else {
            NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
        }
    }

    @MainActor
    private static func validManagerFallbackWindow(_ window: NSWindow?) -> NSWindow? {
        guard let window, isManagerRestoreFallbackCandidate(window) else {
            return nil
        }
        return window
    }

    @MainActor
    private static func isManagerRestoreFallbackCandidate(_ window: NSWindow) -> Bool {
        isManagerRestoreFallbackCandidate(
            identifier: window.identifier,
            isPanel: window is NSPanel,
            title: window.title,
            sharingType: window.sharingType,
            level: window.level
        )
    }

    @MainActor
    private static func removeStandardWindowChrome(from window: NSWindow) {
        window.styleMask.subtract(standardManagerWindowStyleMask)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
    }

    @MainActor
    private static func restoreStandardManagerWindowChrome(on window: NSWindow) {
        let repairedMask = repairedManagerWindowStyleMask(window.styleMask)
        if window.styleMask != repairedMask {
            window.styleMask = repairedMask
        }

        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false

        for button in [
            NSWindow.ButtonType.closeButton,
            .miniaturizeButton,
            .zoomButton
        ] {
            let standardButton = window.standardWindowButton(button)
            standardButton?.isHidden = false
            standardButton?.isEnabled = true
        }
    }
}
