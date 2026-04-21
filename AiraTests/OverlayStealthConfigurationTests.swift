import AppKit
import Testing

@testable import Aira

struct OverlayStealthConfigurationTests {

  @Test func screenCaptureExclusionEnabledUsesStealthSharingType() {
    #expect(
      OverlayStealthConfiguration.configuredSharingType(screenCaptureExclusionEnabled: true)
        == .none)
    #expect(
      OverlayStealthConfiguration.treatsConfiguredStateAsStealthSatisfied(
        screenCaptureExclusionEnabled: true) == false)
  }

  @Test func screenCaptureExclusionDisabledLeavesWindowsShareableWithoutWarning() {
    #expect(
      OverlayStealthConfiguration.configuredSharingType(screenCaptureExclusionEnabled: false)
        == .readOnly)
    #expect(
      OverlayStealthConfiguration.treatsConfiguredStateAsStealthSatisfied(
        screenCaptureExclusionEnabled: false) == true)
  }
}
