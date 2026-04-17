import Foundation

struct AppUpdaterConfiguration: Equatable, Sendable {
  static let feedURLInfoKey = "SUFeedURL"
  static let publicEDKeyInfoKey = "SUPublicEDKey"

  let feedURLString: String
  let publicEDKey: String

  init(feedURLString: String, publicEDKey: String) {
    self.feedURLString = feedURLString
    self.publicEDKey = publicEDKey
  }

  var feedURL: URL? {
    let trimmedValue = feedURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      trimmedValue.isEmpty == false,
      let url = URL(string: trimmedValue),
      url.scheme?.isEmpty == false
    else {
      return nil
    }
    return url
  }

  var trimmedPublicEDKey: String {
    publicEDKey.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var isConfigured: Bool {
    feedURL != nil && trimmedPublicEDKey.isEmpty == false
  }

  static func from(bundle: Bundle = .main) -> AppUpdaterConfiguration {
    AppUpdaterConfiguration(
      feedURLString: bundle.object(forInfoDictionaryKey: feedURLInfoKey) as? String ?? "",
      publicEDKey: bundle.object(forInfoDictionaryKey: publicEDKeyInfoKey) as? String ?? ""
    )
  }
}
