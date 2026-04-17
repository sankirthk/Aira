import SwiftUI

/// Hand-drawn wavy rule — exact translation of WavySeparator.tsx.
/// SVG source: viewBox="0 0 200 2", path uses Q + T (smooth quadratic bezier) commands.
struct WavySeparator: View {
  var color: Color = .white
  var opacity: Double = 0.3
  var lineHeight: CGFloat = 4
  var amplitudeScale: CGFloat = 0.25
  var verticalPadding: CGFloat = 6

  var body: some View {
    WavyLine(amplitudeScale: amplitudeScale)
      .stroke(
        color.opacity(opacity),
        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
      )
      .frame(height: lineHeight)
      .blur(radius: 0.3)
      .padding(.vertical, verticalPadding)
  }
}

/// Matches SVG path:
/// M 0,1 Q 10,0.5 20,1 T 40,1 T 60,1 T 80,1 T 100,1 T 120,1 T 140,1 T 160,1 T 180,1 T 200,1
/// viewBox 200×2 → midY=1, amplitude=0.5 (25% of height each side of center)
private struct WavyLine: Shape {
  let amplitudeScale: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let midY = rect.midY
    let segW = rect.width / 10.0  // 10 segments (20 units each in 200-unit space)
    let amp = rect.height * amplitudeScale

    // M 0,1
    path.move(to: CGPoint(x: 0, y: midY))

    // Q 10,0.5 20,1 → first curve, control above center (i=0 → above)
    // T 40,1 … T 200,1 → reflected, alternates below/above
    for i in 0..<10 {
      let cpY = i % 2 == 0 ? midY - amp : midY + amp
      let cpX = CGFloat(i) * segW + segW * 0.5
      let endX = CGFloat(i + 1) * segW
      path.addQuadCurve(
        to: CGPoint(x: endX, y: midY),
        control: CGPoint(x: cpX, y: cpY))
    }
    return path
  }
}
