import SwiftUI

extension Notification.Name {
  static let airaNewScript = Notification.Name("aira.newScript")
  static let airaImportScript = Notification.Name("aira.importScript")
  static let airaCloseCurrent = Notification.Name("aira.closeCurrent")
  static let airaToggleNotchShortcut = Notification.Name("aira.toggleNotchShortcut")
  static let airaTogglePillShortcut = Notification.Name("aira.togglePillShortcut")
}

@main
struct AiraApp: App {
  @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
  @StateObject private var appState = AppState()
  @StateObject private var appUpdaterController = AppUpdaterController()
  @State private var overlayController = OverlayWindowController()
  @State private var menuBarController = MenuBarStatusItemController()

  init() {
    AiraLogger.shared.logAppLaunch()
  }

  var body: some Scene {
    WindowGroup {
      ManagerWindowView(overlayController: overlayController)
        .environmentObject(appState)
        .environment(\.managerFontScale, CGFloat(appState.settings.managerTypography.scaleFactor))
        .preferredColorScheme(preferredColorScheme)
        .task(id: appState.settings.appearanceMode) {
          applyAppAppearance()
          installMenuBarController()
        }
        .task(id: appState.settings.screenCaptureExclusionEnabled) {
          overlayController.updateScreenCaptureExclusion(
            enabled: appState.settings.screenCaptureExclusionEnabled)
        }
        .task {
          installMenuBarController()
        }
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentMinSize)
    .commands {
      if appUpdaterController.showsCheckForUpdates {
        CommandGroup(after: .appInfo) {
          Button("Check for Updates…") {
            appUpdaterController.checkForUpdates()
          }
          .disabled(appUpdaterController.canCheckForUpdates == false)

          Divider()
        }
      }

      CommandGroup(replacing: .newItem) {
        Button("New Script") {
          NotificationCenter.default.post(name: .airaNewScript, object: nil)
        }
        .keyboardShortcut("n", modifiers: [.command])

        Button("Import Script…") {
          NotificationCenter.default.post(name: .airaImportScript, object: nil)
        }
        .keyboardShortcut("o", modifiers: [.command])
      }

      CommandGroup(after: .newItem) {
        Divider()
        Button("Close") {
          NotificationCenter.default.post(name: .airaCloseCurrent, object: nil)
        }
        .keyboardShortcut("w", modifiers: [.command])
      }

      CommandGroup(after: .help) {
        Button("Export Debug Log…") {
          AiraLogger.shared.exportInteractively()
        }
      }
    }
  }

  private var preferredColorScheme: ColorScheme? {
    switch appState.settings.appearanceMode {
    case .light:
      return .light
    case .dark:
      return .dark
    case .system:
      return nil
    }
  }

  private func applyAppAppearance() {
    switch appState.settings.appearanceMode {
    case .light:
      NSApp.appearance = NSAppearance(named: .aqua)
    case .dark:
      NSApp.appearance = NSAppearance(named: .darkAqua)
    case .system:
      NSApp.appearance = nil
    }
  }

  private func installMenuBarController() {
    menuBarController.install(
      appState: appState,
      overlayController: overlayController,
      preferredColorScheme: { preferredColorScheme }
    )
  }

}
