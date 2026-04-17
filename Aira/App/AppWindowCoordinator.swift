import AppKit

enum AppWindowCoordinator {
    static let managerWindowIdentifier = NSUserInterfaceItemIdentifier("aira.manager.window")

    @MainActor
    static func markManagerWindow(_ window: NSWindow?) {
        window?.identifier = managerWindowIdentifier
    }

    @MainActor
    static func managerWindow(in application: NSApplication = .shared) -> NSWindow? {
        application.windows.first(where: isManagerWindow)
    }

    @MainActor
    static func currentTransientMenuBarWindow(in application: NSApplication = .shared) -> NSWindow? {
        guard let keyWindow = application.keyWindow, isTransientMenuBarWindow(keyWindow) else {
            return nil
        }
        return keyWindow
    }

    @MainActor
    static func hideManagerWindowForSession(in application: NSApplication = .shared) {
        managerWindow(in: application)?.orderOut(nil)
        application.setActivationPolicy(.accessory)
        NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.finder" })?
            .activate(options: .activateIgnoringOtherApps)
    }

    @MainActor
    static func restoreManagerWindow(
        in application: NSApplication = .shared,
        fallbackWindow: NSWindow? = nil
    ) {
        application.setActivationPolicy(.regular)

        let candidateWindow =
            managerWindow(in: application)
            ?? fallbackWindow
            ?? application.windows.first(where: { !($0 is NSPanel) && !isTransientMenuBarWindow($0) })

        guard let window = candidateWindow else {
            application.activate(ignoringOtherApps: true)
            return
        }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        application.activate(ignoringOtherApps: true)
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
    private static func isManagerWindow(_ window: NSWindow) -> Bool {
        window.identifier == managerWindowIdentifier
    }

    @MainActor
    private static func isTransientMenuBarWindow(_ window: NSWindow) -> Bool {
        !isManagerWindow(window) && !(window is NSPanel) && window.title.isEmpty
    }
}
