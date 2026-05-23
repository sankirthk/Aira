import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
  static let shared = SettingsWindowController()

  private init() {
    super.init(window: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func present(appState: AppState) {
    if window == nil {
      window = makeWindow(appState: appState)
    } else {
      refreshContent(appState: appState)
    }

    guard let window else {
      return
    }

    AppWindowCoordinator.markSettingsWindow(window)
    if window.isMiniaturized {
      window.deminiaturize(nil)
    }

    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
    }

    window.orderFrontRegardless()
    window.makeKeyAndOrderFront(nil)
  }

  func closeWindow() {
    window?.performClose(nil)
  }

  func windowWillClose(_ notification: Notification) {
    window = nil
  }

  private func makeWindow(appState: AppState) -> NSWindow {
    let window = NSWindow(
      contentRect: CGRect(x: 0, y: 0, width: 920, height: 780),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = "Preferences"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    configureWindowAppearance(window, appState: appState)
    window.minSize = CGSize(width: 760, height: 620)
    window.collectionBehavior.remove(.fullScreenPrimary)
    window.collectionBehavior.remove(.fullScreenAuxiliary)
    window.collectionBehavior.remove(.fullScreenAllowsTiling)
    window.standardWindowButton(.zoomButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isEnabled = false
    window.setFrameAutosaveName("AiraSettingsWindow")
    window.isReleasedWhenClosed = false
    window.delegate = self
    AppWindowCoordinator.markSettingsWindow(window)
    window.contentView = NSHostingView(rootView: AnyView(rootView(appState: appState)))
    window.center()
    return window
  }

  private func refreshContent(appState: AppState) {
    if let window {
      configureWindowAppearance(window, appState: appState)
    }

    guard let hostingView = window?.contentView as? NSHostingView<AnyView> else {
      window?.contentView = NSHostingView(rootView: AnyView(rootView(appState: appState)))
      return
    }

    hostingView.rootView = AnyView(rootView(appState: appState))
  }

  private func configureWindowAppearance(_ window: NSWindow, appState: AppState) {
    if appState.settings.managerInterfaceStyle == .liquidGlass {
      if window.isOpaque { window.isOpaque = false }
      if window.backgroundColor != .clear { window.backgroundColor = .clear }
      if window.titlebarAppearsTransparent { window.titlebarAppearsTransparent = false }
      if window.titleVisibility != .hidden { window.titleVisibility = .hidden }
    } else {
      if !window.isOpaque { window.isOpaque = true }
      if window.backgroundColor != .windowBackgroundColor {
        window.backgroundColor = .windowBackgroundColor
      }
    }
  }

  private func rootView(appState: AppState) -> some View {
    SettingsView(onClose: { [weak self] in
      self?.closeWindow()
    })
    .environmentObject(appState)
  }
}
