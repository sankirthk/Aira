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

struct CountdownView: View {
    let duration: Int
    let appearance: OverlayAppearance
    let onComplete: () -> Void

    @State private var current: Int = 0
    @State private var visible: Bool = true

    var body: some View {
        Group {
            if visible {
                ZStack {
                    Color(hex: appearance.backgroundColor)
                        .opacity(appearance.opacity)

                    Text("\(current)")
                        .font(.custom("Manrope-Bold", size: 48))
                        .foregroundStyle(Color(hex: appearance.textColor))
                        .transition(.opacity)
                        .id(current)
                }
            }
        }
        .task {
            await runCountdown()
        }
    }

    private func runCountdown() async {
        await CountdownRunner.run(
            duration: duration,
            onTick: { value in
                withAnimation(.easeInOut(duration: 0.2)) {
                    current = value
                }
            },
            onComplete: {
                withAnimation {
                    visible = false
                }
                onComplete()
            }
        )
    }
}
