import AppKit

enum OverlayStealthConfiguration {
  static func configuredSharingType(screenCaptureExclusionEnabled: Bool) -> NSWindow.SharingType {
    screenCaptureExclusionEnabled ? .none : .readOnly
  }

  static func treatsConfiguredStateAsStealthSatisfied(screenCaptureExclusionEnabled: Bool) -> Bool {
    !screenCaptureExclusionEnabled
  }
}
