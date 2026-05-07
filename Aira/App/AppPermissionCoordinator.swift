import AVFoundation
import AppKit
import ApplicationServices

@MainActor
final class AppPermissionCoordinator {
  enum PermissionState: Equatable {
    case undetermined
    case denied
    case granted
  }

  static let shared = AppPermissionCoordinator()

  private var didRequestLaunchPermissions = false
  private let settingsStore: SettingsStore
  private let microphonePermissionState: () -> PermissionState
  private let requestMicrophonePermission: (@escaping @Sendable (Bool) -> Void) -> Void
  private let isAccessibilityTrusted: () -> Bool
  private let promptForAccessibilityTrust: () -> Void

  init(
    settingsStore: SettingsStore? = nil,
    microphonePermissionState: @escaping () -> PermissionState = {
      switch AVAudioApplication.shared.recordPermission {
      case .granted:
        return .granted
      case .undetermined:
        return .undetermined
      case .denied:
        return .denied
      @unknown default:
        return .denied
      }
    },
    requestMicrophonePermission: @escaping (@escaping @Sendable (Bool) -> Void) -> Void = {
      AVAudioApplication.requestRecordPermission(completionHandler: $0)
    },
    isAccessibilityTrusted: @escaping () -> Bool = {
      AXIsProcessTrusted()
    },
    promptForAccessibilityTrust: @escaping () -> Void = {
      let options =
        [
          kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
      AXIsProcessTrustedWithOptions(options)
    }
  ) {
    self.settingsStore = settingsStore ?? SettingsStore()
    self.microphonePermissionState = microphonePermissionState
    self.requestMicrophonePermission = requestMicrophonePermission
    self.isAccessibilityTrusted = isAccessibilityTrusted
    self.promptForAccessibilityTrust = promptForAccessibilityTrust
  }

  func requestLaunchPermissionsIfNeeded() {
    guard !didRequestLaunchPermissions else {
      return
    }

    didRequestLaunchPermissions = true
    var settings = loadSettings()
    let isFirstLaunchPermissionPass = !settings.hasCompletedInitialPermissionPrompt
    if isFirstLaunchPermissionPass {
      settings.hasCompletedInitialPermissionPrompt = true
      saveSettings(settings)
    }

    if !isAccessibilityTrusted() {
      promptForAccessibilityTrust()
    }

    if microphonePermissionState() == .undetermined {
      requestMicrophonePermission { _ in }
    }
  }

  func promptForAccessibilityIfNeeded() {
    // If already trusted, nothing to do.
    // If not trusted, show the System Settings prompt on every launch until
    // the user grants it — AXIsProcessTrusted() is the correct stop condition.
    guard !isAccessibilityTrusted() else { return }
    promptForAccessibilityTrust()
  }

  private func loadSettings() -> AppSettings {
    do {
      return try settingsStore.load()
    } catch {
      AiraLogger.shared.error(
        error, category: "permissions", context: "Failed to load permission-onboarding state")
      return AppSettings()
    }
  }

  private func saveSettings(_ settings: AppSettings) {
    do {
      try settingsStore.save(settings)
    } catch {
      AiraLogger.shared.error(
        error, category: "permissions", context: "Failed to persist permission-onboarding state")
    }
  }
}
