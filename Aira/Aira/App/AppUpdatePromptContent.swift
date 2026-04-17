import Foundation

struct AppUpdatePromptContent: Equatable, Sendable {
  let title: String
  let message: String
  let versionLabel: String
  let primaryActionTitle: String
  let secondaryActionTitle: String

  static func updateFound(version: String) -> AppUpdatePromptContent {
    AppUpdatePromptContent(
      title: "Update ready",
      message: "A newer version of Aira is available and ready to download.",
      versionLabel: "Version \(version)",
      primaryActionTitle: "Update Now",
      secondaryActionTitle: "Cancel"
    )
  }

  static func readyToInstall(version: String) -> AppUpdatePromptContent {
    AppUpdatePromptContent(
      title: "Ready to install",
      message: "The latest Aira update has finished downloading and can be installed now.",
      versionLabel: "Version \(version)",
      primaryActionTitle: "Install & Relaunch",
      secondaryActionTitle: "Cancel"
    )
  }
}
