import SwiftUI

// MARK: - Manager App Buttons

struct AiraPrimaryButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  @ViewBuilder
  func makeBody(configuration: Configuration) -> some View {
    let usesGlass = managerTheme.usesLiquidGlassMode
    let isDark = colorScheme == .dark
    let pressed = configuration.isPressed
    let classicPrimary = ManagerClassicAccentPalette.primary(for: colorScheme)
    let label = configuration.label
      .font(
        usesGlass
          ? .system(size: 14 * managerFontScale, weight: .medium)
          : .custom("CrimsonText-Regular", size: 14 * managerFontScale)
      )
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)

    if usesGlass {
      let tintOpacity =
        isDark
        ? (pressed ? 0.58 : 0.45)
        : (pressed ? 0.60 : 0.48)
      label
        .background {
          ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(
              Color("colorPrimary").opacity(tintOpacity))
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color("colorPrimary").opacity(isDark ? 0.40 : 0.50), lineWidth: 0.5)
        )
    } else {
      label
        .background(classicPrimary.opacity(pressed ? 0.8 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct AiraSecondaryButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  @ViewBuilder
  func makeBody(configuration: Configuration) -> some View {
    let usesGlass = managerTheme.usesLiquidGlassMode
    let isDark = colorScheme == .dark
    let pressed = configuration.isPressed
    let classicSecondaryText = ManagerClassicAccentPalette.secondaryText(for: colorScheme)
    let label = configuration.label
      .font(
        usesGlass
          ? .system(size: 14 * managerFontScale, weight: .medium)
          : .custom("CrimsonText-Regular", size: 14 * managerFontScale)
      )
      .foregroundStyle(usesGlass ? .primary : classicSecondaryText)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)

    if usesGlass {
      let tintOpacity =
        isDark
        ? (pressed ? 0.18 : 0.10)
        : (pressed ? 0.45 : 0.30)
      label
        .background {
          ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(
              Color.white.opacity(tintOpacity))
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(
              isDark ? Color.white.opacity(0.18) : Color.primary.opacity(0.12),
              lineWidth: 0.5
            )
        )
    } else {
      label
        .background(Color("colorBackground").opacity(pressed ? 0.8 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(classicSecondaryText, lineWidth: 1)
        )
    }
  }
}

struct AiraLibraryHeaderPrimaryButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  @ViewBuilder
  func makeBody(configuration: Configuration) -> some View {
    let usesGlass = managerTheme.usesLiquidGlassMode
    let isDark = colorScheme == .dark
    let pressed = configuration.isPressed
    let classicPrimary = ManagerClassicAccentPalette.primary(for: colorScheme)
    let label = configuration.label
      .font(
        usesGlass
          ? .system(size: 14 * managerFontScale, weight: .medium)
          : .custom("CrimsonText-Regular", size: 14 * managerFontScale)
      )
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)

    if usesGlass {
      label
        .background {
          TerracottaGlassBackground(
            isPressed: pressed,
            isDark: isDark,
            shape: RoundedRectangle(cornerRadius: 8, style: .continuous)
          )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color("colorSecondary").opacity(isDark ? 0.45 : 0.55), lineWidth: 0.5)
        )
    } else {
      label
        .background(classicPrimary.opacity(pressed ? 0.8 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }
}

struct AiraLibraryHeaderSecondaryButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  @ViewBuilder
  func makeBody(configuration: Configuration) -> some View {
    let usesGlass = managerTheme.usesLiquidGlassMode
    let isDark = colorScheme == .dark
    let pressed = configuration.isPressed
    let classicSecondaryText = ManagerClassicAccentPalette.secondaryText(for: colorScheme)
    let label = configuration.label
      .font(
        usesGlass
          ? .system(size: 14 * managerFontScale, weight: .medium)
          : .custom("CrimsonText-Regular", size: 14 * managerFontScale)
      )
      .foregroundStyle(usesGlass ? .primary : classicSecondaryText)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)

    if usesGlass {
      let tintOpacity =
        isDark
        ? (pressed ? 0.18 : 0.10)
        : (pressed ? 0.45 : 0.30)
      label
        .background {
          ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(
              Color.white.opacity(tintOpacity))
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(
              isDark ? Color.white.opacity(0.18) : Color.primary.opacity(0.12),
              lineWidth: 0.5
            )
        )
    } else {
      label
        .background(Color("colorBackground").opacity(pressed ? 0.8 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(classicSecondaryText, lineWidth: 1)
        )
    }
  }
}

struct AiraWobblyToolbarButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  enum Variant {
    case secondary
    case tertiary
  }

  let variant: Variant

  private var usesGlass: Bool { managerTheme.usesLiquidGlassMode }
  private var isDark: Bool { colorScheme == .dark }

  func makeBody(configuration: Configuration) -> some View {
    let pressed = configuration.isPressed
    let toolbarShape = RoundedRectangle(
      cornerRadius: ManagerLayoutParity.toolbarButtonCornerRadius,
      style: .continuous
    )

    if usesGlass {
      let isTertiaryLight = variant == .tertiary && !isDark

      let textColor: Color = isTertiaryLight ? Color("colorPrimary") : .white
      let strokeColor: Color
      let strokeOpacity: Double

      switch variant {
      case .secondary:
        strokeColor = Color("colorSecondary")
        strokeOpacity = isDark ? 0.45 : 0.55
      case .tertiary:
        strokeColor = isTertiaryLight ? Color("colorPrimary") : Color.white
        strokeOpacity = isTertiaryLight ? 0.25 : (isDark ? 0.25 : 0.0)
      }

      return AnyView(
        configuration.label
          .font(.system(size: 15 * managerFontScale, weight: .medium))
          .foregroundStyle(textColor)
          .padding(.horizontal, 16)
          .frame(height: ManagerLayoutParity.toolbarButtonHeight)
          .background {
            if variant == .secondary {
              TerracottaGlassBackground(
                isPressed: pressed,
                isDark: isDark,
                shape: toolbarShape
              )
            } else {
              let tertiaryTintOpacity = isDark ? (pressed ? 0.55 : 0.38) : (pressed ? 0.45 : 0.30)
              let tertiaryTint = isDark ? Color("colorPrimary") : Color.white
              ZStack {
                toolbarShape.fill(.ultraThinMaterial)
                toolbarShape
                  .fill(tertiaryTint.opacity(tertiaryTintOpacity))
              }
            }
          }
          .clipShape(toolbarShape)
          .overlay {
            toolbarShape.strokeBorder(strokeColor.opacity(strokeOpacity), lineWidth: 0.5)
          }
          .scaleEffect(pressed ? 0.96 : 1)
          .animation(.easeOut(duration: 0.15), value: pressed)
      )
    } else {
      let fillColor: Color =
        variant == .secondary
        ? ManagerClassicAccentPalette.secondary(for: colorScheme)
        : Color("colorBackground")
      let foregroundColor: Color = variant == .secondary ? .white : Color("colorText")
      let borderColor: Color = variant == .secondary ? Color.white.opacity(0.8) : Color("colorText")

      return AnyView(
        configuration.label
          .font(.custom("IndieFlower", size: 15 * managerFontScale))
          .foregroundStyle(foregroundColor)
          .padding(.horizontal, 16)
          .frame(height: ManagerLayoutParity.toolbarButtonHeight)
          .background(fillColor.opacity(pressed ? 0.82 : 1))
          .clipShape(toolbarShape)
          .overlay(
            toolbarShape
              .inset(by: 2)
              .stroke(
                borderColor,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [2, 1]))
          )
          .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
          .scaleEffect(pressed ? 0.96 : 1)
          .animation(.easeOut(duration: 0.15), value: pressed)
      )
    }
  }
}

struct AiraCueButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.colorScheme) private var colorScheme

  func makeBody(configuration: Configuration) -> some View {
    let secondary = ManagerClassicAccentPalette.secondaryText(for: colorScheme)
    configuration.label
      .font(.custom("CrimsonText-Regular", size: 13 * managerFontScale))
      .foregroundStyle(secondary)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(Color("colorBackground").opacity(configuration.isPressed ? 0.8 : 1))
      .clipShape(RoundedRectangle(cornerRadius: 24))
      .overlay(
        RoundedRectangle(cornerRadius: 24)
          .stroke(secondary, lineWidth: 1)
      )
  }
}

struct AiraCueTileButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.isEnabled) private var isEnabled

  private var usesGlass: Bool { managerTheme.usesLiquidGlassMode }

  @ViewBuilder
  func makeBody(configuration: Configuration) -> some View {
    let cornerRadius: CGFloat = usesGlass ? 8 : 10
    let label = configuration.label
      .font(
        usesGlass
          ? .system(size: 12 * managerFontScale, weight: .medium)
          : .custom("IndieFlower", size: 14 * managerFontScale)
      )
      .foregroundStyle(Color(hex: "#F5F2EC"))
      .frame(maxWidth: .infinity)
      .padding(.horizontal, usesGlass ? 6 : 12)
      .padding(.vertical, usesGlass ? 7 : 14)

    if usesGlass {
      let isDark = colorScheme == .dark
      let pressed = configuration.isPressed
      let opacity: Double =
        isDark
        ? (pressed ? 0.62 : 0.48)
        : (pressed ? 0.82 : 0.76)
      label
        .background {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color("colorSecondary").opacity(opacity))
            .background(
              .ultraThinMaterial,
              in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color("colorSecondary").opacity(isDark ? 0.45 : 0.60), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isEnabled ? 0.06 : 0.02), radius: 2, y: 1)
        .scaleEffect(pressed ? 0.97 : 1)
        .animation(.easeOut(duration: 0.15), value: pressed)
        .opacity(isEnabled ? 1 : 0.58)
    } else {
      label
        .background(
          ManagerClassicAccentPalette.secondary(for: colorScheme)
            .opacity(configuration.isPressed ? 0.82 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(Color("colorText"), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .scaleEffect(configuration.isPressed ? 0.97 : 1)
        .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
  }

}

// MARK: - Sidebar Buttons

/// Organic wobbly-border button matching SidebarButton.tsx.
/// SVG path source space: 200 × 46. Stroke: cream/white at 25 % opacity.
struct AiraSidebarActionButtonStyle: ButtonStyle {
  @Environment(\.managerTheme) private var managerTheme

  @ViewBuilder
  func makeBody(configuration: Configuration) -> some View {
    let label = configuration.label
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

    if managerTheme.usesLiquidGlassMode {
      label
        .padding(.vertical, 2)
        .background(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(configuration.isPressed ? 0.24 : 0.16))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(
              Color("colorSecondary").opacity(configuration.isPressed ? 0.72 : 0.56), lineWidth: 1.4
            )
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .inset(by: 1.5)
            .strokeBorder(
              Color("colorBackground").opacity(configuration.isPressed ? 0.42 : 0.32),
              lineWidth: 0.8)
        )
        .overlay(alignment: .trailing) {
          Circle()
            .fill(Color("colorSecondary"))
            .frame(width: 10, height: 10)
            .shadow(color: Color("colorSecondary").opacity(0.45), radius: 8)
            .padding(.trailing, 12)
        }
        .shadow(color: Color.black.opacity(configuration.isPressed ? 0.08 : 0.16), radius: 8, y: 3)
        .contentShape(Rectangle())
    } else {
      label
        .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0))
        .overlay(
          OrganicButtonBorder()
            .stroke(
              Color.white.opacity(configuration.isPressed ? 0.6 : 0.25),
              style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        )
        .contentShape(Rectangle())
    }
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

/// Sage-green frosted glass — Edit button
struct AiraCardEditButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  @ViewBuilder
  func makeBody(configuration: Configuration) -> some View {
    let usesGlass = managerTheme.usesLiquidGlassMode
    let isDark = colorScheme == .dark
    let shape = RoundedRectangle(
      cornerRadius: ScriptCardActionButtonAffordances.cornerRadius, style: .continuous)

    configuration.label
      .font(
        usesGlass
          ? .system(size: 14 * managerFontScale, weight: .medium)
          : .custom("CrimsonText-Regular", size: 14 * managerFontScale)
      )
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      .background {
        if usesGlass {
          let tintOpacity: Double =
            isDark
            ? (configuration.isPressed ? 0.55 : 0.40)
            : (configuration.isPressed ? 0.65 : 0.52)
          ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(Color("colorPrimary").opacity(tintOpacity))
          }
        } else {
          shape
            .fill(
              ManagerClassicAccentPalette.primary(for: colorScheme)
                .opacity(configuration.isPressed ? 0.75 : 1)
            )
        }
      }
      .clipShape(shape)
      .overlay {
        if usesGlass {
          shape
            .strokeBorder(
              isDark ? Color.white.opacity(0.22) : Color("colorPrimary").opacity(0.35),
              lineWidth: 0.5
            )
        } else {
          shape
            .inset(by: 2)
            .stroke(
              Color.white.opacity(0.8),
              style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [2, 1])
            )
        }
      }
  }
}

/// Terracotta frosted glass — Cast button
struct AiraCardCastButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  func makeBody(configuration: Configuration) -> some View {
    let usesGlass = managerTheme.usesLiquidGlassMode
    let isDark = colorScheme == .dark
    let shape = RoundedRectangle(
      cornerRadius: ScriptCardActionButtonAffordances.cornerRadius, style: .continuous)

    configuration.label
      .font(
        usesGlass
          ? .system(size: 14 * managerFontScale, weight: .regular)
          : .custom("CrimsonText-Regular", size: 14 * managerFontScale)
      )
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background {
        if usesGlass {
          TerracottaGlassBackground(
            isPressed: configuration.isPressed,
            isDark: isDark,
            shape: shape
          )
        } else {
          shape
            .fill(
              ManagerClassicAccentPalette.secondary(for: colorScheme)
                .opacity(configuration.isPressed ? 0.75 : 1)
            )
        }
      }
      .clipShape(shape)
      .overlay {
        if usesGlass {
          shape
            .strokeBorder(Color("colorSecondary").opacity(isDark ? 0.45 : 0.55), lineWidth: 0.5)
        } else {
          shape
            .inset(by: 2)
            .stroke(
              Color.white.opacity(0.8),
              style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [2, 1])
            )
        }
      }
  }
}

enum ScriptCardActionButtonAffordances {
  static let cornerRadius: CGFloat = 8
  static let editUsesRoundedRectangle = true
  static let castUsesRoundedRectangle = true
}

// MARK: - Shared Terracotta Glass Background

/// Fixed-base terracotta frosted glass background used by all terracotta buttons.
/// Uses a consistent warm base color instead of `.ultraThinMaterial` so buttons
/// look identical regardless of what container they sit on.
struct TerracottaGlassBackground<S: Shape>: View {
  let isPressed: Bool
  let isDark: Bool
  let shape: S

  private var baseColor: Color {
    isDark ? Color(hex: "#2A2A2A") : Color(hex: "#F0EDE7")
  }

  private var tintOpacity: Double {
    isDark
      ? (isPressed ? 0.62 : 0.48)
      : (isPressed ? 0.72 : 0.58)
  }

  var body: some View {
    ZStack {
      shape.fill(baseColor)
      shape.fill(Color("colorSecondary").opacity(tintOpacity))
    }
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
