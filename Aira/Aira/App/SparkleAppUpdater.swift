#if canImport(Sparkle)
  import Combine
  import Foundation
  import Sparkle

  @MainActor
  final class SparkleAppUpdater: NSObject, AppUpdating {
    let supportsCheckForUpdatesCommand = true

    var canCheckForUpdates: Bool {
      updater.canCheckForUpdates
    }

    var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> {
      updater.publisher(for: \.canCheckForUpdates)
        .receive(on: RunLoop.main)
        .eraseToAnyPublisher()
    }

    private let updater: SPUUpdater
    private let userDriver: AiraSparkleUserDriver

    init(bundle: Bundle = .main) throws {
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

      try updater.start()
    }

    func checkForUpdates() {
      updater.checkForUpdates()
    }
  }
#endif
