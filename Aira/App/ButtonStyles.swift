import SwiftUI

// MARK: - Manager App Buttons

struct AiraPrimaryButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.custom("Manrope-Bold", size: 14 * managerFontScale))
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(Color("colorPrimary").opacity(configuration.isPressed ? 0.8 : 1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

struct AiraSecondaryButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.custom("Manrope-Bold", size: 14 * managerFontScale))
      .foregroundStyle(Color("colorSecondary"))
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(Color("colorBackground").opacity(configuration.isPressed ? 0.8 : 1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color("colorSecondary"), lineWidth: 1)
      )
  }
}

struct AiraWobblyToolbarButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale

  enum Variant {
    case secondary
    case tertiary
  }

  let variant: Variant

  func makeBody(configuration: Configuration) -> some View {
    let fillColor: Color
    let foregroundColor: Color
    let borderColor: Color

    switch variant {
    case .secondary:
      fillColor = Color("colorSecondary")
      foregroundColor = .white
      borderColor = Color.white.opacity(0.8)
    case .tertiary:
      fillColor = Color("colorBackground")
      foregroundColor = Color("colorText")
      borderColor = Color("colorText")
    }

    return configuration.label
      .font(.custom("IndieFlower", size: 15 * managerFontScale))
      .foregroundStyle(foregroundColor)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(fillColor.opacity(configuration.isPressed ? 0.82 : 1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .inset(by: 2)
          .stroke(
            borderColor,
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [2, 1])
          )
      )
      .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

struct AiraCueButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.custom("Inter-Regular", size: 13 * managerFontScale))
      .foregroundStyle(Color("colorSecondary"))
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(Color("colorBackground").opacity(configuration.isPressed ? 0.8 : 1))
      .clipShape(RoundedRectangle(cornerRadius: 24))
      .overlay(
        RoundedRectangle(cornerRadius: 24)
          .stroke(Color("colorSecondary"), lineWidth: 1)
      )
  }
}

struct AiraCueTileButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.custom("IndieFlower", size: 14 * managerFontScale))
      .foregroundStyle(Color(hex: "#F5F2EC"))
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 12)
      .padding(.vertical, 14)
      .background(Color("colorSecondary").opacity(configuration.isPressed ? 0.82 : 1))
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(Color("colorText"), lineWidth: 2)
      )
      .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

// MARK: - Sidebar Buttons

/// Organic wobbly-border button matching SidebarButton.tsx.
/// SVG path source space: 200 × 46. Stroke: cream/white at 25 % opacity.
struct AiraSidebarActionButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0))
      .overlay(
        OrganicButtonBorder()
          .stroke(
            Color.white.opacity(configuration.isPressed ? 0.6 : 0.25),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
          )
      )
  }
}

/// Matches SidebarButton.tsx path:
/// M 4,12 Q 3,7 9,5 L 190,6 Q 196,7 195,13 L 194,35 Q 195,40 189,41 L 9,40 Q 3,39 4,33 Z
/// Source view-box: 200 × 46
private struct OrganicButtonBorder: Shape {
  func path(in rect: CGRect) -> Path {
    let sx = rect.width / 200.0
    let sy = rect.height / 46.0
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
    var p = Path()
    p.move(to: pt(4, 12))
    p.addQuadCurve(to: pt(9, 5), control: pt(3, 7))
    p.addLine(to: pt(190, 6))
    p.addQuadCurve(to: pt(195, 13), control: pt(196, 7))
    p.addLine(to: pt(194, 35))
    p.addQuadCurve(to: pt(189, 41), control: pt(195, 40))
    p.addLine(to: pt(9, 40))
    p.addQuadCurve(to: pt(4, 33), control: pt(3, 39))
    p.closeSubpath()
    return p
  }
}

// MARK: - Script Card Buttons

/// Sage-green fill, expands to fill available width — Edit button
struct AiraCardEditButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.custom("Manrope-Bold", size: 14 * managerFontScale))
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(Color("colorPrimary").opacity(configuration.isPressed ? 0.75 : 1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

/// Terracotta fill — Cast button
struct AiraCardCastButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.custom("Manrope-Bold", size: 14 * managerFontScale))
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(Color("colorSecondary").opacity(configuration.isPressed ? 0.75 : 1))
      .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

// MARK: - Overlay Chrome

struct OverlayChromeIconButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    OverlayChromeIconButton(configuration: configuration)
  }
}

private struct OverlayChromeIconButton: View {
  let configuration: ButtonStyle.Configuration
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    configuration.label
      .frame(width: 26, height: 26)
      .foregroundStyle(Color.white.opacity(isEnabled ? 0.96 : 0.42))
      .background(
        Color.black.opacity(
          isEnabled
            ? (configuration.isPressed ? 0.34 : 0.24)
            : 0.12)
      )
      .clipShape(Circle())
      .overlay(
        Circle()
          .stroke(Color.white.opacity(isEnabled ? 0.18 : 0.08), lineWidth: 1)
      )
      .shadow(color: .black.opacity(isEnabled ? 0.16 : 0.06), radius: 6, y: 2)
      .scaleEffect(isEnabled && configuration.isPressed ? 0.94 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
      .opacity(isEnabled ? 1 : 0.72)
  }
}

struct OverlayPauseIcon: View {
  var body: some View {
    HStack(spacing: 3) {
      RoundedRectangle(cornerRadius: 1.3)
        .fill(Color.white.opacity(0.92))
        .frame(width: 3, height: 10)
      RoundedRectangle(cornerRadius: 1.3)
        .fill(Color.white.opacity(0.92))
        .frame(width: 3, height: 10)
    }
    .frame(width: 14, height: 14)
  }
}

struct OverlayResumeIcon: View {
  var body: some View {
    ZStack {
      Path { path in
        path.move(to: CGPoint(x: 4.1, y: 2.9))
        path.addCurve(
          to: CGPoint(x: 4.0, y: 6.4),
          control1: CGPoint(x: 4.2, y: 3.3),
          control2: CGPoint(x: 4.2, y: 4.8)
        )
        path.addCurve(
          to: CGPoint(x: 4.0, y: 9.3),
          control1: CGPoint(x: 4.0, y: 7.2),
          control2: CGPoint(x: 4.0, y: 8.3)
        )
        path.addCurve(
          to: CGPoint(x: 4.1, y: 12.1),
          control1: CGPoint(x: 4.0, y: 10.3),
          control2: CGPoint(x: 4.0, y: 11.0)
        )
      }
      .stroke(Color.white.opacity(0.94), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

      Path { path in
        path.move(to: CGPoint(x: 4.1, y: 3.4))
        path.addCurve(
          to: CGPoint(x: 8.8, y: 3.2),
          control1: CGPoint(x: 5.0, y: 3.1),
          control2: CGPoint(x: 6.9, y: 3.0)
        )
        path.addCurve(
          to: CGPoint(x: 11.6, y: 4.9),
          control1: CGPoint(x: 9.9, y: 3.7),
          control2: CGPoint(x: 10.9, y: 4.4)
        )
      }
      .stroke(Color.white.opacity(0.94), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

      Path { path in
        path.move(to: CGPoint(x: 4.1, y: 11.6))
        path.addCurve(
          to: CGPoint(x: 8.8, y: 11.8),
          control1: CGPoint(x: 5.0, y: 11.9),
          control2: CGPoint(x: 6.9, y: 12.0)
        )
        path.addCurve(
          to: CGPoint(x: 11.6, y: 10.1),
          control1: CGPoint(x: 9.9, y: 11.3),
          control2: CGPoint(x: 10.9, y: 10.6)
        )
      }
      .stroke(Color.white.opacity(0.94), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

      Path { path in
        path.move(to: CGPoint(x: 11.5, y: 6.6))
        path.addCurve(
          to: CGPoint(x: 11.6, y: 8.4),
          control1: CGPoint(x: 11.6, y: 7.0),
          control2: CGPoint(x: 11.6, y: 8.0)
        )
      }
      .stroke(Color.white.opacity(0.94), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }
    .frame(width: 14, height: 14)
  }
}

struct OverlayCloseIcon: View {
  var body: some View {
    ZStack {
      Path { path in
        path.move(to: CGPoint(x: 7.0, y: 1.5))
        path.addCurve(
          to: CGPoint(x: 1.8, y: 7.2),
          control1: CGPoint(x: 4.4, y: 1.4),
          control2: CGPoint(x: 2.3, y: 3.5)
        )
        path.addCurve(
          to: CGPoint(x: 7.5, y: 12.4),
          control1: CGPoint(x: 1.4, y: 9.8),
          control2: CGPoint(x: 4.0, y: 12.3)
        )
        path.addCurve(
          to: CGPoint(x: 13.0, y: 7.8),
          control1: CGPoint(x: 10.4, y: 12.5),
          control2: CGPoint(x: 12.8, y: 10.4)
        )
        path.addCurve(
          to: CGPoint(x: 7.0, y: 1.5),
          control1: CGPoint(x: 13.2, y: 4.8),
          control2: CGPoint(x: 10.4, y: 1.9)
        )
      }
      .stroke(Color.white.opacity(0.9), lineWidth: 1.1)

      Path { path in
        path.move(to: CGPoint(x: 4.4, y: 4.3))
        path.addCurve(
          to: CGPoint(x: 9.8, y: 9.6),
          control1: CGPoint(x: 5.4, y: 5.3),
          control2: CGPoint(x: 8.7, y: 8.6)
        )
      }
      .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))

      Path { path in
        path.move(to: CGPoint(x: 9.9, y: 4.3))
        path.addCurve(
          to: CGPoint(x: 4.3, y: 9.9),
          control1: CGPoint(x: 8.8, y: 5.4),
          control2: CGPoint(x: 5.5, y: 8.7)
        )
      }
      .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
    }
    .frame(width: 14, height: 14)
  }
}

struct OverlayDockArrowIcon: View {
  let pointsDown: Bool

  var body: some View {
    ZStack {
      Path { path in
        if pointsDown {
          path.move(to: CGPoint(x: 7.1, y: 1.0))
          path.addCurve(
            to: CGPoint(x: 7.0, y: 11.7),
            control1: CGPoint(x: 6.9, y: 3.0),
            control2: CGPoint(x: 6.9, y: 9.2)
          )
        } else {
          path.move(to: CGPoint(x: 6.9, y: 13.0))
          path.addCurve(
            to: CGPoint(x: 7.0, y: 2.3),
            control1: CGPoint(x: 7.1, y: 11.0),
            control2: CGPoint(x: 7.1, y: 4.8)
          )
        }
      }
      .stroke(Color.white.opacity(0.94), style: StrokeStyle(lineWidth: 2, lineCap: .round))

      Path { path in
        if pointsDown {
          path.move(to: CGPoint(x: 2.3, y: 8.0))
          path.addCurve(
            to: CGPoint(x: 7.0, y: 12.0),
            control1: CGPoint(x: 3.7, y: 8.7),
            control2: CGPoint(x: 5.6, y: 10.4)
          )
        } else {
          path.move(to: CGPoint(x: 2.3, y: 6.0))
          path.addCurve(
            to: CGPoint(x: 7.0, y: 2.0),
            control1: CGPoint(x: 3.7, y: 5.3),
            control2: CGPoint(x: 5.6, y: 3.6)
          )
        }
      }
      .stroke(Color.white.opacity(0.94), style: StrokeStyle(lineWidth: 2, lineCap: .round))

      Path { path in
        if pointsDown {
          path.move(to: CGPoint(x: 11.7, y: 8.0))
          path.addCurve(
            to: CGPoint(x: 7.0, y: 12.0),
            control1: CGPoint(x: 10.3, y: 8.7),
            control2: CGPoint(x: 8.4, y: 10.4)
          )
        } else {
          path.move(to: CGPoint(x: 11.7, y: 6.0))
          path.addCurve(
            to: CGPoint(x: 7.0, y: 2.0),
            control1: CGPoint(x: 10.3, y: 5.3),
            control2: CGPoint(x: 8.4, y: 3.6)
          )
        }
      }
      .stroke(Color.white.opacity(0.94), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
    .frame(width: 14, height: 14)
  }
}

struct OverlayFullscreenIcon: View {
  var body: some View {
    ZStack {
      Path { path in
        path.move(to: CGPoint(x: 2.8, y: 3.0))
        path.addCurve(
          to: CGPoint(x: 4.9, y: 2.8),
          control1: CGPoint(x: 3.0, y: 2.9),
          control2: CGPoint(x: 3.5, y: 2.8)
        )
        path.addCurve(
          to: CGPoint(x: 6.5, y: 2.8),
          control1: CGPoint(x: 5.4, y: 2.8),
          control2: CGPoint(x: 6.0, y: 2.8)
        )
        path.addCurve(
          to: CGPoint(x: 8.5, y: 2.8),
          control1: CGPoint(x: 7.8, y: 2.8),
          control2: CGPoint(x: 8.1, y: 2.8)
        )
        path.addCurve(
          to: CGPoint(x: 10.4, y: 2.9),
          control1: CGPoint(x: 8.9, y: 2.8),
          control2: CGPoint(x: 9.4, y: 2.8)
        )
        path.addCurve(
          to: CGPoint(x: 11.6, y: 4.0),
          control1: CGPoint(x: 10.9, y: 3.0),
          control2: CGPoint(x: 11.3, y: 3.3)
        )
        path.addCurve(
          to: CGPoint(x: 12.0, y: 5.7),
          control1: CGPoint(x: 11.8, y: 4.4),
          control2: CGPoint(x: 12.0, y: 4.9)
        )
        path.addCurve(
          to: CGPoint(x: 12.0, y: 8.2),
          control1: CGPoint(x: 12.0, y: 6.3),
          control2: CGPoint(x: 12.0, y: 7.4)
        )
        path.addCurve(
          to: CGPoint(x: 11.9, y: 10.0),
          control1: CGPoint(x: 12.0, y: 9.3),
          control2: CGPoint(x: 12.0, y: 9.7)
        )
        path.addCurve(
          to: CGPoint(x: 11.6, y: 11.3),
          control1: CGPoint(x: 11.9, y: 10.4),
          control2: CGPoint(x: 11.8, y: 10.9)
        )
        path.addCurve(
          to: CGPoint(x: 10.1, y: 12.0),
          control1: CGPoint(x: 11.4, y: 11.6),
          control2: CGPoint(x: 10.9, y: 11.8)
        )
        path.addCurve(
          to: CGPoint(x: 8.8, y: 12.1),
          control1: CGPoint(x: 9.6, y: 12.0),
          control2: CGPoint(x: 9.2, y: 12.1)
        )
        path.addCurve(
          to: CGPoint(x: 5.8, y: 12.1),
          control1: CGPoint(x: 7.3, y: 12.1),
          control2: CGPoint(x: 6.3, y: 12.1)
        )
        path.addCurve(
          to: CGPoint(x: 4.3, y: 12.0),
          control1: CGPoint(x: 5.0, y: 12.1),
          control2: CGPoint(x: 4.6, y: 12.1)
        )
        path.addCurve(
          to: CGPoint(x: 3.1, y: 11.6),
          control1: CGPoint(x: 3.8, y: 11.9),
          control2: CGPoint(x: 3.4, y: 11.8)
        )
        path.addCurve(
          to: CGPoint(x: 2.4, y: 10.2),
          control1: CGPoint(x: 2.8, y: 11.4),
          control2: CGPoint(x: 2.6, y: 11.0)
        )
        path.addCurve(
          to: CGPoint(x: 2.3, y: 8.6),
          control1: CGPoint(x: 2.3, y: 9.7),
          control2: CGPoint(x: 2.3, y: 9.3)
        )
        path.addCurve(
          to: CGPoint(x: 2.3, y: 6.1),
          control1: CGPoint(x: 2.3, y: 7.9),
          control2: CGPoint(x: 2.3, y: 6.8)
        )
        path.addCurve(
          to: CGPoint(x: 2.4, y: 4.4),
          control1: CGPoint(x: 2.3, y: 5.5),
          control2: CGPoint(x: 2.3, y: 5.0)
        )
        path.addCurve(
          to: CGPoint(x: 2.8, y: 3.0),
          control1: CGPoint(x: 2.4, y: 3.9),
          control2: CGPoint(x: 2.5, y: 3.3)
        )
      }
      .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

      Path { path in
        path.move(to: CGPoint(x: 5.1, y: 5.1))
        path.addLine(to: CGPoint(x: 3.8, y: 3.8))
        path.move(to: CGPoint(x: 3.8, y: 3.8))
        path.addLine(to: CGPoint(x: 4.3, y: 4.8))
        path.move(to: CGPoint(x: 3.8, y: 3.8))
        path.addLine(to: CGPoint(x: 4.8, y: 4.3))
      }
      .stroke(
        Color.white.opacity(0.96),
        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
      )

      Path { path in
        path.move(to: CGPoint(x: 8.7, y: 5.1))
        path.addLine(to: CGPoint(x: 10.0, y: 3.8))
        path.move(to: CGPoint(x: 10.0, y: 3.8))
        path.addLine(to: CGPoint(x: 9.0, y: 4.3))
        path.move(to: CGPoint(x: 10.0, y: 3.8))
        path.addLine(to: CGPoint(x: 9.5, y: 4.8))
      }
      .stroke(
        Color.white.opacity(0.96),
        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
      )

      Path { path in
        path.move(to: CGPoint(x: 5.1, y: 8.9))
        path.addLine(to: CGPoint(x: 3.8, y: 10.2))
        path.move(to: CGPoint(x: 3.8, y: 10.2))
        path.addLine(to: CGPoint(x: 4.8, y: 9.7))
        path.move(to: CGPoint(x: 3.8, y: 10.2))
        path.addLine(to: CGPoint(x: 4.3, y: 9.2))
      }
      .stroke(
        Color.white.opacity(0.96),
        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
      )

      Path { path in
        path.move(to: CGPoint(x: 8.7, y: 8.9))
        path.addLine(to: CGPoint(x: 10.0, y: 10.2))
        path.move(to: CGPoint(x: 10.0, y: 10.2))
        path.addLine(to: CGPoint(x: 9.0, y: 9.7))
        path.move(to: CGPoint(x: 10.0, y: 10.2))
        path.addLine(to: CGPoint(x: 9.5, y: 9.2))
      }
      .stroke(
        Color.white.opacity(0.96),
        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
      )
    }
    .frame(width: 14, height: 14)
  }
}

struct OverlaySwapIcon: View {
  var body: some View {
    ZStack {
      Path { path in
        path.move(to: CGPoint(x: 1.8, y: 4.8))
        path.addCurve(
          to: CGPoint(x: 10.3, y: 5.2),
          control1: CGPoint(x: 3.0, y: 4.6),
          control2: CGPoint(x: 7.9, y: 4.9)
        )
      }
      .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))

      Path { path in
        path.move(to: CGPoint(x: 7.9, y: 2.7))
        path.addCurve(
          to: CGPoint(x: 11.5, y: 5.0),
          control1: CGPoint(x: 9.1, y: 3.3),
          control2: CGPoint(x: 10.9, y: 4.6)
        )
        path.move(to: CGPoint(x: 7.9, y: 7.3))
        path.addCurve(
          to: CGPoint(x: 11.5, y: 5.0),
          control1: CGPoint(x: 9.1, y: 6.7),
          control2: CGPoint(x: 10.9, y: 5.4)
        )
      }
      .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))

      Path { path in
        path.move(to: CGPoint(x: 12.2, y: 9.2))
        path.addCurve(
          to: CGPoint(x: 3.7, y: 8.8),
          control1: CGPoint(x: 11.0, y: 9.4),
          control2: CGPoint(x: 6.1, y: 9.1)
        )
      }
      .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))

      Path { path in
        path.move(to: CGPoint(x: 6.1, y: 11.3))
        path.addCurve(
          to: CGPoint(x: 2.5, y: 9.0),
          control1: CGPoint(x: 4.9, y: 10.7),
          control2: CGPoint(x: 3.1, y: 9.4)
        )
        path.move(to: CGPoint(x: 6.1, y: 6.7))
        path.addCurve(
          to: CGPoint(x: 2.5, y: 9.0),
          control1: CGPoint(x: 4.9, y: 7.3),
          control2: CGPoint(x: 3.1, y: 8.6)
        )
      }
      .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
    }
    .frame(width: 14, height: 14)
  }
}
