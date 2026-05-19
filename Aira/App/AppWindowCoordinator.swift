import AppKit

enum AppWindowCoordinator {
  static let managerWindowIdentifier = NSUserInterfaceItemIdentifier("aira.manager.window")
  static let settingsWindowIdentifier = NSUserInterfaceItemIdentifier("aira.settings.window")
  static let transientMenuBarWindowIdentifier = NSUserInterfaceItemIdentifier(
    "aira.menu-bar.window")
  static let managerDefaultFrameSize = CGSize(width: 1200, height: 800)

  @MainActor
  static func markManagerWindow(_ window: NSWindow?) {
    guard let window else {
      return
    }

    window.identifier = managerWindowIdentifier
    sanitizeManagerWindowFrame(window)
    configureManagerWindowChrome(window)
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
    guard Self.shouldHideTransientTitlebar(styleMask: window.styleMask) else {
      return
    }

    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.toolbar = nil
  }

  nonisolated static func shouldHideTransientTitlebar(styleMask: NSWindow.StyleMask) -> Bool {
    styleMask.contains(.titled)
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
    prepareForSession(in: application)
  }

  @MainActor
  static func prepareForSession(in application: NSApplication? = nil) {
    let application = application ?? .shared
    closeAllTransientMenuBarWindows(in: application)
    let window = managerWindow(in: application)

    guard !shouldPreserveManagerWindowForSession(styleMask: window?.styleMask ?? []) else {
      AiraLogger.shared.info(
        "prepareForSession: manager fullscreen, preserving regular app/window", category: "window")
      return
    }

    window?.orderOut(nil)
    application.setActivationPolicy(.accessory)
    // Activate Finder asynchronously so the cross-process activation
    // does not block the main thread while overlay windows are being created.
    DispatchQueue.main.async {
      if let finder = NSWorkspace.shared.runningApplications
        .first(where: { $0.bundleIdentifier == "com.apple.finder" })
      {
        if #available(macOS 14.0, *) {
          finder.activate()
        } else {
          finder.activate(options: .activateIgnoringOtherApps)
        }
      }
    }
  }

  @MainActor
  static func restoreManagerWindow(
    in application: NSApplication? = nil,
    fallbackWindow: NSWindow? = nil
  ) {
    restoreFromSession(in: application, fallbackWindow: fallbackWindow)
  }

  @MainActor
  static func restoreFromSession(
    in application: NSApplication? = nil,
    fallbackWindow: NSWindow? = nil
  ) {
    let application = application ?? .shared
    if application.activationPolicy() != .regular {
      application.setActivationPolicy(.regular)
    }

    let identified = managerWindow(in: application)
    let fallback = validManagerFallbackWindow(fallbackWindow)
    let window = identified ?? fallback

    AiraLogger.shared.info(
      "restoreManagerWindow: identified=\(identified != nil) fallback=\(fallback != nil) totalWindows=\(application.windows.count) styleMask=\(window?.styleMask.rawValue ?? 0) isVisible=\(window?.isVisible ?? false) frame=\(window?.frame ?? .zero)",
      category: "window"
    )

    guard let window else {
      AiraLogger.shared.info(
        "restoreManagerWindow: no window found, activating app only", category: "window")
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

    configureManagerWindowChrome(window)

    if !window.styleMask.contains(.fullScreen) {
      window.orderFrontRegardless()
      window.makeKeyAndOrderFront(nil)
    }

    activateApp(application)

    // Force the hosting view to re-layout after the orderOut/orderFront
    // round-trip.  Deferred to the next run-loop tick so the window is
    // fully visible before SwiftUI runs its layout pass.  A single
    // deferred invalidation avoids the reentrant-layout crash that
    // occurred when two immediate + async invalidations competed.
    DispatchQueue.main.async {
      configureManagerWindowChrome(window)
      window.contentView?.needsLayout = true
      window.contentView?.needsDisplay = true
    }
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

  static func isTransientMenuBarWindowIdentifier(_ identifier: NSUserInterfaceItemIdentifier?)
    -> Bool
  {
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

  static func shouldPreserveManagerWindowForSession(styleMask: NSWindow.StyleMask) -> Bool {
    styleMask.contains(.fullScreen)
  }

  static func managerWindowFrameNeedsClamp(_ frame: CGRect, visibleFrame: CGRect) -> Bool {
    frame.width <= 0
      || frame.height <= 0
      || frame.width > visibleFrame.width
      || frame.height > visibleFrame.height
      || visibleFrame.intersection(frame).width < min(frame.width, visibleFrame.width) * 0.45
      || visibleFrame.intersection(frame).height < min(frame.height, visibleFrame.height) * 0.45
  }

  static func clampedManagerWindowFrame(_ frame: CGRect, visibleFrame: CGRect) -> CGRect {
    guard managerWindowFrameNeedsClamp(frame, visibleFrame: visibleFrame) else {
      return frame
    }

    let width = min(max(managerDefaultFrameSize.width, 900), visibleFrame.width)
    let height = min(max(managerDefaultFrameSize.height, 600), visibleFrame.height)
    return CGRect(
      x: visibleFrame.midX - width / 2,
      y: visibleFrame.midY - height / 2,
      width: width,
      height: height
    ).integral
  }

  static func managerChromeNeedsConfiguration(
    styleMask: NSWindow.StyleMask,
    titleVisibility: NSWindow.TitleVisibility,
    titlebarAppearsTransparent: Bool,
    hasTitlebarSeparator: Bool,
    hasToolbar: Bool,
    isMovableByWindowBackground: Bool
  ) -> Bool {
    !styleMask.contains(.fullSizeContentView)
      || titleVisibility != .hidden
      || titlebarAppearsTransparent == false
      || hasTitlebarSeparator
      || hasToolbar
      || isMovableByWindowBackground == false
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
  private static func sanitizeManagerWindowFrame(_ window: NSWindow) {
    guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else {
      return
    }

    let clampedFrame = clampedManagerWindowFrame(window.frame, visibleFrame: screen.visibleFrame)
    guard clampedFrame != window.frame else {
      return
    }

    window.setFrame(clampedFrame, display: false)
  }

  @MainActor
  private static func configureManagerWindowChrome(_ window: NSWindow) {
    guard
      managerChromeNeedsConfiguration(
        styleMask: window.styleMask,
        titleVisibility: window.titleVisibility,
        titlebarAppearsTransparent: window.titlebarAppearsTransparent,
        hasTitlebarSeparator: window.titlebarSeparatorStyle != .none,
        hasToolbar: window.toolbar != nil,
        isMovableByWindowBackground: window.isMovableByWindowBackground
      )
    else {
      return
    }

    if !window.styleMask.contains(.fullSizeContentView) {
      window.styleMask.insert(.fullSizeContentView)
    }
    if window.titleVisibility != .hidden {
      window.titleVisibility = .hidden
    }
    if window.titlebarAppearsTransparent == false {
      window.titlebarAppearsTransparent = true
    }
    if window.titlebarSeparatorStyle != .none {
      window.titlebarSeparatorStyle = .none
    }
    if window.toolbar != nil {
      window.toolbar = nil
    }
    if window.isMovableByWindowBackground == false {
      window.isMovableByWindowBackground = true
    }
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

}
