import AppKit
import SwiftUI

@MainActor
final class MenuBarStatusItemController: NSObject, NSPopoverDelegate {
  private var statusItem: NSStatusItem?
  private var popover = NSPopover()
  private var appState: AppState?
  private var overlayController: OverlayWindowController?
  private var preferredColorSchemeProvider: (() -> ColorScheme?)?
  private var hasCompletedLaunch = false
  private var localPopoverDismissMonitor: Any?
  private var globalPopoverDismissMonitor: Any?

  override init() {
    super.init()
    popover = Self.makePopover()
    popover.delegate = self
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleApplicationDidFinishLaunching),
      name: .airaApplicationDidFinishLaunching,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  func install(
    appState: AppState,
    overlayController: OverlayWindowController,
    preferredColorScheme: @escaping () -> ColorScheme?
  ) {
    self.appState = appState
    self.overlayController = overlayController
    self.preferredColorSchemeProvider = preferredColorScheme
    if hasCompletedLaunch == false {
      hasCompletedLaunch = AppLifecycleDelegate.hasFinishedLaunching
    }
    createStatusItemIfNeeded()
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

  @objc private func handleApplicationDidFinishLaunching() {
    hasCompletedLaunch = true
    createStatusItemIfNeeded()
  }

  @objc private func handleStatusItemClick(_ sender: Any?) {
    guard let button = statusItem?.button else {
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
      closePopover()
    } else {
      activateAppForPopover()
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      markPopoverWindowAsTransient()
      installPopoverDismissMonitors()
    }
  }

  private func showContextMenu(from button: NSStatusBarButton) {
    closePopover()

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

    statusItem?.menu = menu
    button.performClick(nil)
    statusItem?.menu = nil
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
    popover.delegate = self
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

  nonisolated static func shouldCreateStatusItem(
    hasCompletedLaunch: Bool,
    hasStatusItem: Bool
  ) -> Bool {
    hasCompletedLaunch && !hasStatusItem
  }

  nonisolated static func promotedPopoverWindowLevel(from level: NSWindow.Level) -> NSWindow.Level {
    NSWindow.Level(rawValue: max(level.rawValue, NSWindow.Level.statusBar.rawValue))
  }

  nonisolated static func popoverCollectionBehavior() -> NSWindow.CollectionBehavior {
    [.canJoinAllSpaces, .fullScreenAuxiliary, .moveToActiveSpace]
  }

  nonisolated static func statusItemUsesTemplateRendering() -> Bool {
    true
  }

  nonisolated static func shouldDismissPopoverForOutsideInteraction(
    isPopoverShown: Bool,
    interactionInsidePopover: Bool,
    interactionOnStatusItem: Bool
  ) -> Bool {
    isPopoverShown && !interactionInsidePopover && !interactionOnStatusItem
  }

  private static func makePopover() -> NSPopover {
    let popover = NSPopover()
    popover.behavior = .transient
    popover.animates = true
    return popover
  }

  private func createStatusItemIfNeeded() {
    guard
      Self.shouldCreateStatusItem(
        hasCompletedLaunch: hasCompletedLaunch,
        hasStatusItem: statusItem != nil
      )
    else {
      return
    }

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    self.statusItem = statusItem

    guard let button = statusItem.button else {
      return
    }

    button.image = Self.makeStatusItemImage()
    button.target = self
    button.action = #selector(handleStatusItemClick(_:))
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
  }

  private static func makeStatusItemImage() -> NSImage? {
    let targetSize = NSSize(width: 18, height: 18)
    let iconColor = NSColor.black

    let image = NSImage(size: targetSize, flipped: false) { rect in
      let scale = min(rect.width, rect.height) / 48.0

      func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(
          x: rect.midX + (x - 24.0) * scale,
          y: rect.midY + (y - 24.0) * scale
        )
      }

      iconColor.setFill()
      iconColor.setStroke()

      let centerCircle = NSBezierPath(
        ovalIn: NSRect(
          x: rect.midX - 4.5 * scale,
          y: rect.midY - 4.5 * scale,
          width: 9.0 * scale,
          height: 9.0 * scale
        ))
      centerCircle.lineWidth = 1.5 * scale
      centerCircle.fill()
      centerCircle.stroke()

      let mainRays = NSBezierPath()
      mainRays.lineWidth = 2.5 * scale
      mainRays.lineCapStyle = .round

      mainRays.move(to: point(24, 19))
      mainRays.curve(
        to: point(24, 8), controlPoint1: point(23.5, 14), controlPoint2: point(24.5, 14))

      mainRays.move(to: point(29, 24))
      mainRays.curve(
        to: point(40, 24), controlPoint1: point(34, 23.5), controlPoint2: point(34, 24.5))

      mainRays.move(to: point(24, 29))
      mainRays.curve(
        to: point(24, 40), controlPoint1: point(24.5, 34), controlPoint2: point(23.5, 34))

      mainRays.move(to: point(19, 24))
      mainRays.curve(
        to: point(8, 24), controlPoint1: point(14, 24.5), controlPoint2: point(14, 23.5))

      mainRays.stroke()

      iconColor.withAlphaComponent(0.72).setStroke()
      let diagonalRays = NSBezierPath()
      diagonalRays.lineWidth = 2.0 * scale
      diagonalRays.lineCapStyle = .round

      diagonalRays.move(to: point(28, 20))
      diagonalRays.curve(
        to: point(34, 14), controlPoint1: point(31, 17), controlPoint2: point(31, 17))

      diagonalRays.move(to: point(28, 28))
      diagonalRays.curve(
        to: point(34, 34), controlPoint1: point(31, 31), controlPoint2: point(31, 31))

      diagonalRays.move(to: point(20, 28))
      diagonalRays.curve(
        to: point(14, 34), controlPoint1: point(17, 31), controlPoint2: point(17, 31))

      diagonalRays.move(to: point(20, 20))
      diagonalRays.curve(
        to: point(14, 14), controlPoint1: point(17, 17), controlPoint2: point(17, 17))

      diagonalRays.stroke()

      iconColor.withAlphaComponent(0.18).setStroke()
      let crosshatch = NSBezierPath()
      crosshatch.lineWidth = 0.5 * scale
      crosshatch.lineCapStyle = .round
      crosshatch.move(to: point(21, 24))
      crosshatch.line(to: point(27, 24))
      crosshatch.move(to: point(24, 21))
      crosshatch.line(to: point(24, 27))
      crosshatch.move(to: point(22, 22))
      crosshatch.line(to: point(26, 26))
      crosshatch.move(to: point(22, 26))
      crosshatch.line(to: point(26, 22))
      crosshatch.stroke()

      return true
    }

    image.isTemplate = Self.statusItemUsesTemplateRendering()
    return image
  }

  private func closePopover() {
    removePopoverDismissMonitors()
    popover.performClose(nil)
  }

  private func installPopoverDismissMonitors() {
    guard localPopoverDismissMonitor == nil, globalPopoverDismissMonitor == nil else {
      return
    }

    localPopoverDismissMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
    ) { [weak self] event in
      self?.handlePopoverDismissEvent(event)
      return event
    }

    globalPopoverDismissMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
    ) { [weak self] event in
      Task { @MainActor [weak self] in
        self?.handlePopoverDismissEvent(event)
      }
    }
  }

  private func removePopoverDismissMonitors() {
    if let localPopoverDismissMonitor {
      NSEvent.removeMonitor(localPopoverDismissMonitor)
      self.localPopoverDismissMonitor = nil
    }
    if let globalPopoverDismissMonitor {
      NSEvent.removeMonitor(globalPopoverDismissMonitor)
      self.globalPopoverDismissMonitor = nil
    }
  }

  private func handlePopoverDismissEvent(_ event: NSEvent) {
    let insidePopover = interactionIsInsidePopover(event)
    let onStatusItem = interactionIsOnStatusItem(event)
    guard
      Self.shouldDismissPopoverForOutsideInteraction(
        isPopoverShown: popover.isShown,
        interactionInsidePopover: insidePopover,
        interactionOnStatusItem: onStatusItem
      )
    else {
      return
    }

    closePopover()
  }

  private func interactionIsInsidePopover(_ event: NSEvent) -> Bool {
    guard let popoverWindow = popover.contentViewController?.view.window else {
      return false
    }

    if event.window === popoverWindow {
      return true
    }

    let screenPoint = screenPoint(for: event, in: popoverWindow)
    return popoverWindow.frame.contains(screenPoint)
  }

  private func interactionIsOnStatusItem(_ event: NSEvent) -> Bool {
    guard let button = statusItem?.button, let buttonWindow = button.window else {
      return false
    }

    if event.window === buttonWindow {
      let location = button.convert(event.locationInWindow, from: nil)
      return button.bounds.contains(location)
    }

    let buttonFrameInWindow = button.convert(button.bounds, to: nil)
    let buttonFrameOnScreen = buttonWindow.convertToScreen(buttonFrameInWindow)
    let screenPoint = screenPoint(for: event, in: buttonWindow)
    return buttonFrameOnScreen.contains(screenPoint)
  }

  private func screenPoint(for event: NSEvent, in fallbackWindow: NSWindow) -> CGPoint {
    if let eventWindow = event.window {
      return eventWindow.convertPoint(toScreen: event.locationInWindow)
    }
    return fallbackWindow.convertPoint(toScreen: event.locationInWindow)
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
    window.collectionBehavior.formUnion(Self.popoverCollectionBehavior())
    window.orderFrontRegardless()
  }

  func popoverDidClose(_ notification: Notification) {
    removePopoverDismissMonitors()
  }
}
