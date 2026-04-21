import Combine
import Foundation

@MainActor
final class NoOpAppUpdater: AppUpdating {
  let supportsCheckForUpdatesCommand: Bool
  let canCheckForUpdates = false
  let canCheckForUpdatesPublisher = Empty<Bool, Never>(completeImmediately: false)
    .eraseToAnyPublisher()

  init(supportsCheckForUpdatesCommand: Bool = false) {
    self.supportsCheckForUpdatesCommand = supportsCheckForUpdatesCommand
  }

  func checkForUpdates() {}
}
