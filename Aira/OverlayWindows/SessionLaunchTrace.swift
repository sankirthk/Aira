import Foundation

struct SessionLaunchTraceMark: Equatable {
  let name: String
  let elapsedMilliseconds: Double
}

@MainActor
final class SessionLaunchTrace {
  private let label: String
  private let clock = ContinuousClock()
  private let start: ContinuousClock.Instant
  private var marks: [SessionLaunchTraceMark] = []

  init(label: String) {
    self.label = label
    self.start = clock.now
  }

  func mark(_ name: String) {
    let elapsed = start.duration(to: clock.now)
    let components = elapsed.components
    let milliseconds =
      Double(components.seconds * 1_000)
      + Double(components.attoseconds) / 1_000_000_000_000_000
    marks.append(SessionLaunchTraceMark(name: name, elapsedMilliseconds: milliseconds))
    AiraLogger.shared.info(
      "launchTrace[\(label)] \(name) \(String(format: "%.2f", milliseconds))ms",
      category: "session"
    )
  }

  func snapshot() -> [SessionLaunchTraceMark] {
    marks
  }
}
