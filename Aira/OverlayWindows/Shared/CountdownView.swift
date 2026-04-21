import SwiftUI

enum CountdownRunner {
  static func run(
    duration: Int,
    sleep: @escaping @Sendable () async -> Void = {
      try? await Task.sleep(for: .seconds(1))
    },
    onTick: @escaping @MainActor (Int) -> Void,
    onComplete: @escaping @MainActor () -> Void
  ) async {
    guard duration > 0 else {
      await MainActor.run {
        onComplete()
      }
      return
    }

    for value in stride(from: duration, through: 1, by: -1) {
      await MainActor.run {
        onTick(value)
      }
      await sleep()
    }

    await MainActor.run {
      onComplete()
    }
  }
}

struct CountdownDisplayState: Equatable {
  let current: Int
  let overlayOpacity: Double
  let isVisible: Bool
}

enum CountdownTransitionPlanner {
  static let completionFadeDuration: Duration = .milliseconds(180)

  static func completionSequence(for current: Int) -> [CountdownDisplayState] {
    [
      CountdownDisplayState(current: current, overlayOpacity: 0, isVisible: true),
      CountdownDisplayState(current: current, overlayOpacity: 0, isVisible: false),
    ]
  }
}

struct CountdownView: View {
  let duration: Int
  let appearance: OverlayAppearance
  let onComplete: () -> Void

  @State private var current: Int = 0
  @State private var overlayOpacity: Double = 1
  @State private var visible: Bool = true

  var body: some View {
    Group {
      if visible && duration > 0 {
        ZStack {
          Color(hex: appearance.backgroundColor)
            .opacity(appearance.opacity)

          Text("\(current)")
            .font(.custom("Manrope-Bold", size: 48))
            .foregroundStyle(Color(hex: appearance.textColor))
            .contentTransition(.opacity)
        }
        .opacity(overlayOpacity)
      }
    }
    .animation(.easeInOut(duration: 0.2), value: current)
    .onAppear {
      if duration <= 0 {
        visible = false
        onComplete()
      }
    }
    .task {
      guard duration > 0 else { return }
      await runCountdown()
    }
  }

  private func runCountdown() async {
    current = duration
    overlayOpacity = 1
    visible = true

    await CountdownRunner.run(
      duration: duration,
      onTick: { value in
        withAnimation(.easeInOut(duration: 0.2)) {
          current = value
        }
      },
      onComplete: {}
    )

    await dismissCountdown()
  }

  @MainActor
  private func dismissCountdown() async {
    let completionSequence = CountdownTransitionPlanner.completionSequence(for: current)
    guard completionSequence.count == 2 else {
      visible = false
      onComplete()
      return
    }

    let fadingState = completionSequence[0]
    let hiddenState = completionSequence[1]

    withAnimation(.easeOut(duration: 0.18)) {
      overlayOpacity = fadingState.overlayOpacity
    }
    try? await Task.sleep(for: CountdownTransitionPlanner.completionFadeDuration)

    current = hiddenState.current
    visible = hiddenState.isVisible
    onComplete()
  }
}
