import Foundation

class SettingsStore {
  enum StoreError: LocalizedError {
    case corruptData
    case encodingFailed

    var errorDescription: String? {
      switch self {
      case .corruptData:
        return "Saved settings are unreadable."
      case .encodingFailed:
        return "Aira could not encode the current settings."
      }
    }
  }

  private let defaults: UserDefaults
  private let key: String

  init(defaults: UserDefaults = .standard, key: String = "aira.appSettings") {
    self.defaults = defaults
    self.key = key
  }

  func load() throws -> AppSettings {
    guard let data = defaults.data(forKey: key) else {
      return AppSettings()
    }

    do {
      return try JSONDecoder().decode(AppSettings.self, from: data)
    } catch {
      throw StoreError.corruptData
    }
  }

  func save(_ settings: AppSettings) throws {
    guard let data = try? JSONEncoder().encode(settings) else {
      throw StoreError.encodingFailed
    }
    defaults.set(data, forKey: key)
  }
}
