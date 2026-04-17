import AppKit

final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
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
