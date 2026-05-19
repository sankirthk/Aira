import AppKit

extension Notification.Name {
  static let airaApplicationDidFinishLaunching = Notification.Name(
    "aira.applicationDidFinishLaunching")
}

final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
  static private(set) var hasFinishedLaunching = false

  func applicationWillFinishLaunching(_ notification: Notification) {
    Self.removeStaleManagerWindowDefaults(from: .standard)
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    Self.hasFinishedLaunching = true
    NotificationCenter.default.post(name: .airaApplicationDidFinishLaunching, object: nil)

    Task { @MainActor in
      AppPermissionCoordinator.shared.requestLaunchPermissionsIfNeeded()
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    let isManagerWindowMiniaturized =
      sender.windows
      .first(where: { $0.identifier == AppWindowCoordinator.managerWindowIdentifier })?
      .isMiniaturized ?? false

    guard
      Self.shouldRestoreManagerWindowOnReopen(
        hasVisibleWindows: flag,
        isManagerWindowMiniaturized: isManagerWindowMiniaturized
      )
    else {
      return false
    }

    Task { @MainActor in
      AppWindowCoordinator.restoreManagerWindow(in: sender)
    }
    return true
  }

  static func shouldRestoreManagerWindowOnReopen(
    hasVisibleWindows: Bool,
    isManagerWindowMiniaturized: Bool
  ) -> Bool {
    !hasVisibleWindows || isManagerWindowMiniaturized
  }

  static func shouldRemoveStaleManagerWindowDefaultKey(_ key: String) -> Bool {
    key.hasPrefix("NSWindow Frame SwiftUI.")
      || key.hasPrefix("NSSplitView Subview Frames SwiftUI.")
  }

  static func removeStaleManagerWindowDefaults(from defaults: UserDefaults) {
    for key in defaults.dictionaryRepresentation().keys
    where shouldRemoveStaleManagerWindowDefaultKey(key) {
      defaults.removeObject(forKey: key)
    }
  }
}
