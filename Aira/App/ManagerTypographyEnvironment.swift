import SwiftUI

private struct ManagerFontScaleKey: EnvironmentKey {
  static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
  var managerFontScale: CGFloat {
    get { self[ManagerFontScaleKey.self] }
    set { self[ManagerFontScaleKey.self] = newValue }
  }
}

enum ManagerSurfaceTreatment: Equatable {
  case classic
  case nativeGlass
  case materialFallback
}

enum ManagerThemePolicy {
  static func surfaceTreatment(
    for style: ManagerInterfaceStyle,
    operatingSystemMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
  ) -> ManagerSurfaceTreatment {
    switch style {
    case .classic:
      return .classic
    case .liquidGlass:
      return operatingSystemMajorVersion >= 26 ? .nativeGlass : .materialFallback
    }
  }
}

struct ManagerTheme: Equatable {
  let interfaceStyle: ManagerInterfaceStyle
  let colorPalette: ManagerColorPalette
  let accentColorHex: String
  let surfaceTreatment: ManagerSurfaceTreatment

  init(
    interfaceStyle: ManagerInterfaceStyle,
    colorPalette: ManagerColorPalette = .aira,
    accentColorHex: String = ManagerColorPalette.defaultNeutralAccentHex,
    operatingSystemMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
  ) {
    self.interfaceStyle = interfaceStyle
    self.colorPalette = colorPalette
    self.accentColorHex = accentColorHex
    self.surfaceTreatment = ManagerThemePolicy.surfaceTreatment(
      for: interfaceStyle,
      operatingSystemMajorVersion: operatingSystemMajorVersion
    )
  }

  var usesLiquidGlassMode: Bool {
    interfaceStyle == .liquidGlass
  }

  func primaryAccent(for colorScheme: ColorScheme) -> Color {
    colorPalette.primaryAccent(for: colorScheme, accentColorHex: accentColorHex)
  }

  func secondaryAccent(for colorScheme: ColorScheme) -> Color {
    colorPalette.secondaryAccent(for: colorScheme, accentColorHex: accentColorHex)
  }

  func secondaryTextAccent(for colorScheme: ColorScheme) -> Color {
    colorPalette.secondaryTextAccent(for: colorScheme, accentColorHex: accentColorHex)
  }

  func actionAccent(for colorScheme: ColorScheme) -> Color {
    colorPalette == .aira
      ? secondaryAccent(for: colorScheme)
      : primaryAccent(for: colorScheme)
  }

  func classicSelectedActionFill(for colorScheme: ColorScheme, isPressed: Bool = false) -> Color {
    let accent = actionAccent(for: colorScheme)
    if colorPalette == .aira {
      return accent.opacity(isPressed ? 0.82 : (colorScheme == .dark ? 0.74 : 0.92))
    }
    return accent.opacity(isPressed ? 0.82 : 1)
  }

  func sidebarFill(for colorScheme: ColorScheme) -> Color {
    colorPalette.sidebarFill(for: colorScheme)
  }

  func windowSubstrate(for colorScheme: ColorScheme) -> Color {
    colorPalette.windowSubstrate(for: colorScheme)
  }

  func contentBackground(for colorScheme: ColorScheme) -> Color {
    colorPalette.contentBackground(for: colorScheme)
  }

  func surfaceFill(for colorScheme: ColorScheme) -> Color {
    colorPalette.surfaceFill(for: colorScheme)
  }

  func controlFill(for colorScheme: ColorScheme) -> Color {
    colorPalette.controlFill(for: colorScheme)
  }

  func readableAccentForeground(for colorScheme: ColorScheme, accent: Color) -> Color {
    colorPalette == .aira || colorPalette == .blue || colorScheme == .dark
      ? .white : accent.readableTextColor
  }
}

enum ManagerClassicAccentPalette {
  static func primary(for colorScheme: ColorScheme, palette: ManagerColorPalette = .aira) -> Color {
    palette.primaryAccent(for: colorScheme)
  }

  static func secondary(for colorScheme: ColorScheme, palette: ManagerColorPalette = .aira) -> Color
  {
    palette.secondaryAccent(for: colorScheme)
  }

  static func secondaryText(for colorScheme: ColorScheme, palette: ManagerColorPalette = .aira)
    -> Color
  {
    palette.secondaryTextAccent(for: colorScheme)
  }
}

extension ManagerColorPalette {
  func primaryAccent(
    for colorScheme: ColorScheme,
    accentColorHex: String = ManagerColorPalette.defaultNeutralAccentHex
  ) -> Color {
    switch self {
    case .aira:
      return colorScheme == .dark ? Color(hex: "#7A9278") : Color("colorPrimary")
    case .blue:
      return Color(hex: "#0A84FF")
    case .violet:
      return Color(hex: ManagerColorPalette.violetAccentHex)
    }
  }

  func secondaryAccent(
    for colorScheme: ColorScheme,
    accentColorHex: String = ManagerColorPalette.defaultNeutralAccentHex
  ) -> Color {
    switch self {
    case .aira:
      return colorScheme == .dark ? Color(hex: "#DE917F") : Color("colorSecondary")
    case .blue:
      return Color(hex: "#0A84FF")
    case .violet:
      return Color(hex: ManagerColorPalette.violetAccentHex)
    }
  }

  func secondaryTextAccent(
    for colorScheme: ColorScheme,
    accentColorHex: String = ManagerColorPalette.defaultNeutralAccentHex
  ) -> Color {
    switch self {
    case .aira:
      return colorScheme == .dark ? Color(hex: "#F0AA9A") : Color("colorSecondary")
    case .blue:
      return Color(hex: "#0A84FF")
    case .violet:
      return Color(hex: ManagerColorPalette.violetAccentHex)
    }
  }

  func sidebarFill(for colorScheme: ColorScheme) -> Color {
    switch self {
    case .aira:
      return colorScheme == .dark ? Color(hex: "#26372D") : Color("colorPrimary")
    case .blue, .violet:
      return colorScheme == .dark ? Color(hex: "#2B2B2B") : Color.white
    }
  }

  func windowSubstrate(for colorScheme: ColorScheme) -> Color {
    switch self {
    case .aira:
      return colorScheme == .dark ? Color(hex: "#223126") : Color(hex: "#849688")
    case .blue, .violet:
      return colorScheme == .dark ? Color(hex: "#242424") : Color.white
    }
  }

  func contentBackground(for colorScheme: ColorScheme) -> Color {
    switch self {
    case .aira:
      return colorScheme == .dark ? Color(hex: "#26382C") : Color("colorBackground")
    case .blue, .violet:
      return colorScheme == .dark ? Color(hex: "#2A2A2A") : Color.white
    }
  }

  func surfaceFill(for colorScheme: ColorScheme) -> Color {
    switch self {
    case .aira:
      return colorScheme == .dark ? Color(hex: "#2B3E32") : Color("colorSurface")
    case .blue, .violet:
      return colorScheme == .dark ? Color(hex: "#303030") : Color.white
    }
  }

  func controlFill(for colorScheme: ColorScheme) -> Color {
    switch self {
    case .aira:
      return colorScheme == .dark ? Color(hex: "#31463A") : Color("colorBackground")
    case .blue, .violet:
      return colorScheme == .dark ? Color(hex: "#363636") : Color(hex: "#F6F7F9")
    }
  }

  var classicContentSurface: Color {
    switch self {
    case .aira:
      return Color("colorBackground")
    case .blue, .violet:
      return Color.white
    }
  }
}

enum ManagerLayoutParity {
  static let contentAreaCornerRadius: CGFloat = 28
  static let documentLibraryOuterPadding: CGFloat = 20
  static let documentLibraryHeaderHeight: CGFloat = 44
  static let documentLibraryGridPadding: CGFloat = 20
  static let scriptEditorRootCornerRadius: CGFloat = 18
  static let scriptEditorPanelCornerRadius: CGFloat = 12
  static let scriptEditorPanelPadding: CGFloat = 32
  static let scriptEditorHeaderPadding: CGFloat = 16
  static let toolbarButtonCornerRadius: CGFloat = 10
  static let toolbarButtonHeight: CGFloat = 38
}

private struct ManagerThemeKey: EnvironmentKey {
  static let defaultValue = ManagerTheme(interfaceStyle: .classic)
}

extension EnvironmentValues {
  var managerTheme: ManagerTheme {
    get { self[ManagerThemeKey.self] }
    set { self[ManagerThemeKey.self] = newValue }
  }
}

struct ManagerSurfaceModifier: ViewModifier {
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme
  let cornerRadius: CGFloat
  let classicFill: Color
  let strokeOpacity: Double

  private var isDark: Bool { colorScheme == .dark }
  private var usesAiraDarkGlass: Bool {
    isDark && managerTheme.colorPalette == .aira && managerTheme.usesLiquidGlassMode
  }

  @ViewBuilder
  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    let resolvedClassicFill =
      managerTheme.colorPalette == .aira ? classicFill : managerTheme.surfaceFill(for: colorScheme)
    let resolvedClassicStroke =
      managerTheme.colorPalette == .aira
      ? Color("colorText").opacity(strokeOpacity)
      : Color("colorText").opacity(isDark ? max(strokeOpacity, 0.18) : strokeOpacity)

    switch managerTheme.surfaceTreatment {
    case .classic:
      content
        .background(resolvedClassicFill)
        .clipShape(shape)
        .overlay(shape.stroke(resolvedClassicStroke, lineWidth: isDark ? 1.25 : 1.5))
    case .materialFallback:
      content
        .background {
          ZStack {
            if usesAiraDarkGlass {
              shape.fill(managerTheme.surfaceFill(for: colorScheme))
            } else {
              shape.fill(.regularMaterial)
              shape.fill(managerTheme.surfaceFill(for: colorScheme).opacity(isDark ? 0.82 : 0.0))
            }
          }
        }
        .clipShape(shape)
        .overlay(shape.stroke(Color("colorText").opacity(max(strokeOpacity, 0.14)), lineWidth: 1))
    case .nativeGlass:
      content
        .background {
          ZStack {
            if !usesAiraDarkGlass {
              shape.fill(.ultraThinMaterial)
            }
            shape.fill(
              usesAiraDarkGlass
                ? managerTheme.surfaceFill(for: colorScheme)
                : isDark
                  ? managerTheme.surfaceFill(for: colorScheme).opacity(0.86)
                  : Color.white.opacity(0.55))
          }
        }
        .clipShape(shape)
        .overlay(
          shape.strokeBorder(
            isDark ? Color.white.opacity(0.18) : Color.white.opacity(0.45),
            lineWidth: 0.5
          )
        )
    }
  }
}

extension View {
  func managerSurface(
    cornerRadius: CGFloat = 20,
    classicFill: Color = Color("colorSurface").opacity(0.82),
    strokeOpacity: Double = 0.10
  ) -> some View {
    modifier(
      ManagerSurfaceModifier(
        cornerRadius: cornerRadius,
        classicFill: classicFill,
        strokeOpacity: strokeOpacity
      )
    )
  }
}

struct ManagerNativeGlassButtonModifier: ViewModifier {
  @Environment(\.managerTheme) private var managerTheme
  let isProminent: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if managerTheme.surfaceTreatment == .nativeGlass, #available(macOS 26.0, *) {
      if isProminent {
        content.buttonStyle(.glassProminent)
      } else {
        content.buttonStyle(.glass)
      }
    } else {
      content.buttonStyle(.plain)
    }
  }
}

extension View {
  func managerNativeGlassButtonStyle(isProminent: Bool = false) -> some View {
    modifier(ManagerNativeGlassButtonModifier(isProminent: isProminent))
  }
}

struct ManagerTopBarGlassModifier: ViewModifier {
  @Environment(\.managerTheme) private var managerTheme

  @ViewBuilder
  func body(content: Content) -> some View {
    switch managerTheme.surfaceTreatment {
    case .classic:
      content
    case .materialFallback:
      content.background(.bar)
    case .nativeGlass:
      if #available(macOS 26.0, *) {
        GlassEffectContainer {
          content.glassEffect(.regular, in: Rectangle())
        }
      } else {
        content.background(.bar)
      }
    }
  }
}

struct ManagerSidebarBackgroundModifier: ViewModifier {
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  private var isDark: Bool { colorScheme == .dark }
  private var classicSidebarFill: Color {
    managerTheme.sidebarFill(for: colorScheme)
  }

  @ViewBuilder
  func body(content: Content) -> some View {
    switch managerTheme.surfaceTreatment {
    case .classic:
      content.background {
        ZStack {
          classicSidebarFill
          if managerTheme.colorPalette == .aira {
            Color.black.opacity(0.08)
          } else if isDark {
            Color.white.opacity(0.01)
          }
        }
      }
    case .materialFallback:
      content
        .background {
          Group {
            if isDark {
              sidebarMaterialBackground
            } else {
              lightLiquidSidebarFill
            }
          }
          .allowsHitTesting(false)
        }
    case .nativeGlass:
      if #available(macOS 26.0, *) {
        content
          .background {
            Group {
              if isDark {
                darkLiquidSidebarGlass
              } else {
                lightLiquidSidebarFill
              }
            }
            .allowsHitTesting(false)
          }
      } else {
        content
          .background {
            Group {
              if isDark {
                sidebarMaterialBackground
              } else {
                lightLiquidSidebarFill
              }
            }
            .allowsHitTesting(false)
          }
      }
    }
  }

  private var lightLiquidSidebarFill: some View {
    ZStack {
      if managerTheme.colorPalette == .aira {
        managerTheme.sidebarFill(for: colorScheme)
        Color.black.opacity(0.08)
      } else {
        Rectangle()
          .fill(.ultraThinMaterial)
        Color.white.opacity(0.64)
        LinearGradient(
          colors: [
            Color.white.opacity(0.60),
            managerTheme.primaryAccent(for: colorScheme).opacity(0.035),
            Color.white.opacity(0.50),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        RadialGradient(
          colors: [
            managerTheme.primaryAccent(for: colorScheme).opacity(0.080),
            managerTheme.secondaryAccent(for: colorScheme).opacity(0.035),
            .clear,
          ],
          center: .topLeading,
          startRadius: 8,
          endRadius: 260
        )
      }
    }
  }

  @ViewBuilder
  private var darkLiquidSidebarGlass: some View {
    if #available(macOS 26.0, *) {
      ZStack {
        if managerTheme.colorPalette == .aira {
          sidebarBrandGradient
        } else {
          neutralLiquidSidebarGlass
        }
        Rectangle()
          .fill(
            managerTheme.primaryAccent(for: colorScheme).opacity(
              managerTheme.colorPalette == .aira ? 0.018 : 0.010)
          )
          .glassEffect(
            .regular.tint(
              managerTheme.primaryAccent(for: colorScheme).opacity(
                managerTheme.colorPalette == .aira ? 0.045 : 0.0)),
            in: Rectangle()
          )
      }
    } else {
      sidebarMaterialBackground
    }
  }

  private var sidebarBrandGradient: some View {
    ZStack {
      Color.black.opacity(isDark ? (managerTheme.colorPalette == .aira ? 0.08 : 0.62) : 0.22)
      LinearGradient(
        colors: isDark
          ? [
            managerTheme.sidebarFill(for: colorScheme).opacity(
              managerTheme.colorPalette == .aira ? 0.98 : 0.50),
            managerTheme.primaryAccent(for: colorScheme).opacity(
              managerTheme.colorPalette == .aira ? 0.14 : 0.12),
            managerTheme.secondaryAccent(for: colorScheme).opacity(
              managerTheme.colorPalette == .aira ? 0.06 : 0.06),
          ]
          : [
            managerTheme.sidebarFill(for: colorScheme).opacity(0.95),
            managerTheme.primaryAccent(for: colorScheme).opacity(0.18),
            managerTheme.secondaryAccent(for: colorScheme).opacity(0.14),
          ],
        startPoint: .top,
        endPoint: .bottom
      )
    }
  }

  private var neutralLiquidSidebarGlass: some View {
    ZStack {
      Color(hex: "#2B2B2B").opacity(0.70)
      Rectangle()
        .fill(.ultraThinMaterial)
      LinearGradient(
        colors: [
          Color.white.opacity(0.050),
          Color.black.opacity(0.10),
          Color.white.opacity(0.030),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      RadialGradient(
        colors: [
          managerTheme.primaryAccent(for: colorScheme).opacity(0.035),
          managerTheme.secondaryAccent(for: colorScheme).opacity(0.018),
          .clear,
        ],
        center: .topLeading,
        startRadius: 12,
        endRadius: 280
      )
    }
  }

  private var sidebarMaterialBackground: some View {
    Rectangle()
      .fill(
        managerTheme.sidebarFill(for: colorScheme).opacity(
          managerTheme.colorPalette == .aira ? (isDark ? 0.94 : 0.74) : (isDark ? 0.58 : 0.46))
      )
      .background(.ultraThinMaterial)
      .overlay {
        Rectangle()
          .fill(
            LinearGradient(
              colors: [
                managerTheme.primaryAccent(for: colorScheme).opacity(
                  managerTheme.colorPalette == .aira ? (isDark ? 0.06 : 0.18) : 0.055),
                managerTheme.sidebarFill(for: colorScheme).opacity(0.28),
                managerTheme.secondaryAccent(for: colorScheme).opacity(
                  managerTheme.colorPalette == .aira ? (isDark ? 0.04 : 0.16) : 0.035),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }
  }
}
