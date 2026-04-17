import Combine
import Foundation

/// Shared session playhead state.
///
/// This is introduced as a passive coordinator in the first refactor step so the
/// session has a single place to mirror normalized progress, velocity, and pause state
/// without changing visible scroll behavior yet.
@MainActor
final class SessionPlayheadCoordinator: ObservableObject {
  @Published private(set) var progress: Double = 0
  @Published private(set) var velocity: Double = 0
  @Published private(set) var isPaused: Bool = false

  func beginSession() {
    progress = 0
    velocity = 0
    isPaused = false
  }

  func endSession() {
    progress = 0
    velocity = 0
    isPaused = false
  }

  func updateProgress(_ progress: Double) {
    self.progress = min(max(progress, 0), 1)
  }

  func nudgeProgress(by delta: Double) {
    updateProgress(progress + delta)
  }

  func updateVelocity(_ velocity: Double) {
    self.velocity = velocity
  }

  func setPaused(_ isPaused: Bool) {
    self.isPaused = isPaused
  }
}
