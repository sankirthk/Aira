import AppKit
import SwiftUI

@MainActor
final class MenuBarStatusItemController: NSObject {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private var popover = NSPopover()
  private var appState: AppState?
  private var overlayController: OverlayWindowController?
  private var preferredColorSchemeProvider: (() -> ColorScheme?)?

  override init() {
    super.init()
    popover = Self.makePopover()

    if let button = statusItem.button {
      button.image = NSImage(
        systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Aira")
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
    resetPopoverIfNeeded()
    updatePopoverContent()

    if popover.isShown {
      popover.performClose(nil)
    } else {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      markPopoverWindowAsTransient()
      activateAppForPopover()
    }
  }

  private func showContextMenu(from button: NSStatusBarButton) {
    popover.performClose(nil)

    let menu = NSMenu()

    let openItem = NSMenuItem(
      title: "Open Aira", action: #selector(openAiraFromMenu), keyEquivalent: "")
    openItem.target = self
    menu.addItem(openItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(
      title: "Quit Aira", action: #selector(quitFromMenu), keyEquivalent: "")
    quitItem.target = self
    menu.addItem(quitItem)

    statusItem.menu = menu
    button.performClick(nil)
    statusItem.menu = nil
  }

  private func resetPopoverIfNeeded() {
    let hasAttachedWindow = popover.contentViewController?.view.window != nil
    guard Self.shouldRebuildPopover(isShown: popover.isShown, hasAttachedWindow: hasAttachedWindow)
    else {
      return
    }

    popover.performClose(nil)
    popover.contentViewController = nil
    popover = Self.makePopover()
  }

  @objc private func openAiraFromMenu() {
    AppWindowCoordinator.closeAllTransientMenuBarWindows()
    AppWindowCoordinator.restoreManagerWindow()
  }

  @objc private func quitFromMenu() {
    AppWindowCoordinator.closeAllTransientMenuBarWindows()
    NSApp.terminate(nil)
  }

  private func markPopoverWindowAsTransient() {
    let resolveWindow: @MainActor () -> NSWindow? = { [weak self] in
      self?.popover.contentViewController?.view.window
    }

    configurePopoverHostWindow(resolveWindow())

    Task { @MainActor in
      configurePopoverHostWindow(resolveWindow())
    }
  }

  nonisolated static func shouldRebuildPopover(isShown: Bool, hasAttachedWindow: Bool) -> Bool {
    isShown && !hasAttachedWindow
  }

  nonisolated static func promotedPopoverWindowLevel(from level: NSWindow.Level) -> NSWindow.Level {
    NSWindow.Level(rawValue: max(level.rawValue, NSWindow.Level.floating.rawValue))
  }

  private static func makePopover() -> NSPopover {
    let popover = NSPopover()
    popover.behavior = .transient
    popover.animates = true
    return popover
  }

  private func activateAppForPopover() {
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
    }
  }

  private func configurePopoverHostWindow(_ window: NSWindow?) {
    guard let window else {
      return
    }

    AppWindowCoordinator.markTransientMenuBarWindow(window)
    window.level = Self.promotedPopoverWindowLevel(from: window.level)
    window.collectionBehavior.insert(.moveToActiveSpace)
    window.orderFrontRegardless()
    window.makeKeyAndOrderFront(nil)
  }
}
