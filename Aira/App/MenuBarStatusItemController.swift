import AppKit
import SwiftUI

@MainActor
final class MenuBarStatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var appState: AppState?
    private var overlayController: OverlayWindowController?
    private var preferredColorSchemeProvider: (() -> ColorScheme?)?

    override init() {
        super.init()

        popover.behavior = .transient
        popover.animates = true

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Aira")
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    func install(
        appState: AppState,
        overlayController: OverlayWindowController,
        preferredColorScheme: @escaping () -> ColorScheme?
    ) {
        self.appState = appState
        self.overlayController = overlayController
        self.preferredColorSchemeProvider = preferredColorScheme
        updatePopoverContent()
        AppWindowCoordinator.closeAllTransientMenuBarWindows()
    }

    private func updatePopoverContent() {
        guard let appState, let overlayController else {
            return
        }

        let rootView = MenuBarQuickAccessView(overlayController: overlayController)
            .environmentObject(appState)
            .preferredColorScheme(preferredColorSchemeProvider?())

        let hostingController = NSHostingController(rootView: rootView)
        popover.contentViewController = hostingController
        popover.contentSize = hostingController.view.fittingSize
    }

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let button = statusItem.button else {
            return
        }

        switch NSApp.currentEvent?.type {
        case .rightMouseUp:
            showContextMenu(from: button)
        default:
            togglePopover(from: button)
        }
    }

    private func togglePopover(from button: NSStatusBarButton) {
        updatePopoverContent()

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        popover.performClose(nil)

        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Aira", action: #selector(openAiraFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Aira", action: #selector(quitFromMenu), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openAiraFromMenu() {
        AppWindowCoordinator.restoreManagerWindow()
        AppWindowCoordinator.closeAllTransientMenuBarWindows()
    }

    @objc private func quitFromMenu() {
        AppWindowCoordinator.closeAllTransientMenuBarWindows()
        NSApp.terminate(nil)
    }
}
