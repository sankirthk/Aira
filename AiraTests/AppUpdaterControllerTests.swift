import Combine
import Foundation
import Testing

@testable import Aira

@MainActor
struct AppUpdaterControllerTests {
  @Test func directBuildShowsCheckForUpdatesWhenFactorySupportsIt() {
    let controller = AppUpdaterController(
      bundle: .main,
      distributionChannel: .direct,
      updaterFactory: { _, _, _ in
        StubAppUpdater(supportsCheckForUpdatesCommand: true, canCheckForUpdates: true)
      }
    )

    #expect(controller.showsCheckForUpdates)
    #expect(controller.canCheckForUpdates)
  }

  @Test func appStoreBuildHidesCheckForUpdatesEvenIfFactoryCouldProvideIt() {
    let controller = AppUpdaterController(
      bundle: .main,
      distributionChannel: .appStore,
      updaterFactory: { _, _, _ in
        StubAppUpdater(supportsCheckForUpdatesCommand: false, canCheckForUpdates: false)
      }
    )

    #expect(controller.showsCheckForUpdates == false)
    #expect(controller.canCheckForUpdates == false)
  }
}

@MainActor
private final class StubAppUpdater: AppUpdating {
  let supportsCheckForUpdatesCommand: Bool
  let canCheckForUpdates: Bool
  let canCheckForUpdatesPublisher: AnyPublisher<Bool, Never>

  init(supportsCheckForUpdatesCommand: Bool, canCheckForUpdates: Bool) {
    self.supportsCheckForUpdatesCommand = supportsCheckForUpdatesCommand
    self.canCheckForUpdates = canCheckForUpdates
    self.canCheckForUpdatesPublisher = Just(canCheckForUpdates).eraseToAnyPublisher()
  }

  func checkForUpdates() {}
}
