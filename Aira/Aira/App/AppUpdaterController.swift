import Combine
import Foundation

@MainActor
final class AppUpdaterController: ObservableObject {
  typealias UpdaterFactory =
    @MainActor (AppDistributionChannel, AppUpdaterConfiguration, Bundle)
    -> any AppUpdating

  @Published private(set) var showsCheckForUpdates = false
  @Published private(set) var canCheckForUpdates = false

  let configuration: AppUpdaterConfiguration
  let distributionChannel: AppDistributionChannel

  private let updater: any AppUpdating
  private var canCheckObservation: AnyCancellable?

  init(
    bundle: Bundle = .main,
    distributionChannel: AppDistributionChannel? = nil,
    updaterFactory: UpdaterFactory? = nil
  ) {
    let configuration = AppUpdaterConfiguration.from(bundle: bundle)
    let resolvedDistributionChannel =
      distributionChannel ?? AppDistributionChannel.from(bundle: bundle)
    self.configuration = configuration
    self.distributionChannel = resolvedDistributionChannel
    self.updater = (updaterFactory ?? Self.makeUpdater)(
      resolvedDistributionChannel,
      configuration,
      bundle
    )

    showsCheckForUpdates = updater.supportsCheckForUpdatesCommand
    canCheckForUpdates = updater.canCheckForUpdates
    canCheckObservation = updater.canCheckForUpdatesPublisher
      .sink { [weak self] canCheckForUpdates in
        self?.canCheckForUpdates = canCheckForUpdates
      }
  }

  func checkForUpdates() {
    updater.checkForUpdates()
  }

  private static func makeUpdater(
    distributionChannel: AppDistributionChannel,
    configuration: AppUpdaterConfiguration,
    bundle: Bundle
  ) -> any AppUpdating {
    switch distributionChannel {
    case .appStore:
      return NoOpAppUpdater()
    case .direct:
      guard configuration.isConfigured else {
        return NoOpAppUpdater()
      }

      #if canImport(Sparkle)
        do {
          return try SparkleAppUpdater(bundle: bundle)
        } catch {
          NSLog("Sparkle updater failed to start: %@", error.localizedDescription)
          return NoOpAppUpdater()
        }
      #else
        return NoOpAppUpdater()
      #endif
    }
  }
}
