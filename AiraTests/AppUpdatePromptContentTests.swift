import Foundation
import Testing

@testable import Aira

struct AppUpdatePromptContentTests {
  @Test func updateFoundPromptUsesCompactBrandedCopy() {
    let content = AppUpdatePromptContent.updateFound(version: "1.0.0-beta.1")

    #expect(content.title == "Update ready")
    #expect(content.versionLabel == "Version 1.0.0-beta.1")
    #expect(content.primaryActionTitle == "Update Now")
    #expect(content.secondaryActionTitle == "Cancel")
  }

  @Test func readyToInstallPromptUsesInstallSpecificAction() {
    let content = AppUpdatePromptContent.readyToInstall(version: "1.0.0-beta.1")

    #expect(content.title == "Ready to install")
    #expect(content.versionLabel == "Version 1.0.0-beta.1")
    #expect(content.primaryActionTitle == "Install & Relaunch")
    #expect(content.secondaryActionTitle == "Cancel")
  }
}
