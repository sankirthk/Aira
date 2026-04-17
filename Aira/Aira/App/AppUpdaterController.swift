import Combine
import Foundation
import Sparkle

@MainActor
final class AppUpdaterController: NSObject, ObservableObject {
  @Published private(set) var canCheckForUpdates = false

  let configuration: AppUpdaterConfiguration

  private let updater: SPUUpdater?
  private let userDriver: AiraSparkleUserDriver?
  private var canCheckObservation: AnyCancellable?

  init(bundle: Bundle = .main) {
    let configuration = AppUpdaterConfiguration.from(bundle: bundle)
    self.configuration = configuration

    let isTestRun = ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil
    guard configuration.isConfigured && !isTestRun else {
      self.updater = nil
      self.userDriver = nil
      super.init()
      return
    }

    let userDriver = AiraSparkleUserDriver(hostBundle: bundle)
    let updater = SPUUpdater(
      hostBundle: bundle,
      applicationBundle: bundle,
      userDriver: userDriver,
      delegate: nil
    )

    self.updater = updater
    self.userDriver = userDriver
    super.init()

    do {
      try updater.start()
    } catch {
      NSLog("Sparkle updater failed to start: %@", error.localizedDescription)
      return
    }

    canCheckForUpdates = updater.canCheckForUpdates
    canCheckObservation = updater.publisher(for: \.canCheckForUpdates)
      .receive(on: RunLoop.main)
      .sink { [weak self] canCheckForUpdates in
        self?.canCheckForUpdates = canCheckForUpdates
      }
  }

  func checkForUpdates() {
    updater?.checkForUpdates()
  }
}
