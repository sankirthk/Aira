import Combine
import Foundation

enum AppDistributionChannel: String, Equatable, Sendable {
  static let infoDictionaryKey = "AiraDistributionChannel"

  case direct
  case appStore = "app-store"

  static func from(bundle: Bundle = .main) -> AppDistributionChannel {
    guard
      let value = bundle.object(forInfoDictionaryKey: infoDictionaryKey) as? String,
      let channel = AppDistributionChannel(rawValue: value)
    else {
      return .direct
    }

    return channel
  }
}

@MainActor
protocol AppUpdating: AnyObject {
  var supportsCheckForUpdatesCommand: Bool { get }
  var canCheckForUpdates: Bool { get }
  var canCheckForUpdatesPublisher: AnyPublisher<Bool, Never> { get }

  func checkForUpdates()
}
