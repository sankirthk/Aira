import SwiftUI

struct VisualBeamView: View {
  let level: Float  // 0.0–1.0 from AudioLevelMonitor
  let barColor: Color

  private let barCount = 8

  init(level: Float, barColor: Color = Color("colorPrimary")) {
    self.level = level
    self.barColor = barColor
  }

  var body: some View {
    HStack(spacing: 3) {
      ForEach(0..<barCount, id: \.self) { i in
        RoundedRectangle(cornerRadius: 2)
          .fill(barColor)
          .frame(width: 3, height: barHeight(for: i))
          .animation(.easeInOut(duration: 0.08), value: level)
      }
    }
    .frame(height: 24)
  }

  private func barHeight(for index: Int) -> CGFloat {
    let base: CGFloat = 4
    let max: CGFloat = 20
    // Each bar gets a slightly different multiplier for organic look
    let multipliers: [Float] = [0.6, 0.9, 1.0, 0.8, 1.0, 0.7, 0.9, 0.5]
    let m = multipliers[index % multipliers.count]
    return base + CGFloat(level * m) * (max - base)
  }
}
