import AVFoundation
import AppKit
import ApplicationServices
import Speech

@MainActor
final class AppPermissionCoordinator {
  static let shared = AppPermissionCoordinator()

  private var didRequestLaunchPermissions = false

  private init() {}

  func requestLaunchPermissionsIfNeeded() {
    guard !didRequestLaunchPermissions else {
      return
    }

    didRequestLaunchPermissions = true
    promptForAccessibilityIfNeeded()
    requestSpeechRecognition()
    requestMicrophone()
  }

  func promptForAccessibilityIfNeeded() {
    // If already trusted, nothing to do.
    // If not trusted, show the System Settings prompt on every launch until
    // the user grants it — AXIsProcessTrusted() is the correct stop condition.
    guard !AXIsProcessTrusted() else { return }

    let options =
      [
        kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
      ] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
  }

  private func requestSpeechRecognition() {
    SFSpeechRecognizer.requestAuthorization { _ in }
  }

  private func requestMicrophone() {
    AVAudioApplication.requestRecordPermission { _ in }
  }
}
