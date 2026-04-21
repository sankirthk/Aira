import AppKit

extension Notification.Name {
  static let airaApplicationDidFinishLaunching = Notification.Name(
    "aira.applicationDidFinishLaunching")
}

final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
  static private(set) var hasFinishedLaunching = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    Self.hasFinishedLaunching = true
    NotificationCenter.default.post(name: .airaApplicationDidFinishLaunching, object: nil)

    Task { @MainActor in
      AppPermissionCoordinator.shared.requestLaunchPermissionsIfNeeded()
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    guard !flag else {
      return false
    }

    Task { @MainActor in
      AppWindowCoordinator.restoreManagerWindow(in: sender)
    }
    return true
  }
}
