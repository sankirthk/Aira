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
  let surfaceTreatment: ManagerSurfaceTreatment

  init(
    interfaceStyle: ManagerInterfaceStyle,
    operatingSystemMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
  ) {
    self.interfaceStyle = interfaceStyle
    self.surfaceTreatment = ManagerThemePolicy.surfaceTreatment(
      for: interfaceStyle,
      operatingSystemMajorVersion: operatingSystemMajorVersion
    )
  }

  var usesLiquidGlassMode: Bool {
    interfaceStyle == .liquidGlass
  }
}

enum ManagerClassicAccentPalette {
  static func primary(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color(hex: "#5F755F") : Color("colorPrimary")
  }

  static func secondary(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color(hex: "#A96A60") : Color("colorSecondary")
  }

  static func secondaryText(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color(hex: "#D99B90") : Color("colorSecondary")
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

  @ViewBuilder
  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

    switch managerTheme.surfaceTreatment {
    case .classic:
      content
        .background(classicFill)
        .clipShape(shape)
        .overlay(shape.stroke(Color("colorText").opacity(strokeOpacity), lineWidth: 1.5))
    case .materialFallback:
      content
        .background(.regularMaterial, in: shape)
        .overlay(shape.stroke(Color("colorText").opacity(max(strokeOpacity, 0.14)), lineWidth: 1))
    case .nativeGlass:
      content
        .background {
          ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(isDark ? Color.black.opacity(0.18) : Color.white.opacity(0.55))
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
    isDark ? Color(hex: "#374A3D") : ManagerClassicAccentPalette.primary(for: colorScheme)
  }

  @ViewBuilder
  func body(content: Content) -> some View {
    switch managerTheme.surfaceTreatment {
    case .classic:
      content.background {
        ZStack {
          classicSidebarFill
          Color.black.opacity(0.08)
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
      Color("colorPrimary")
      Color.black.opacity(0.08)
    }
  }

  @ViewBuilder
  private var darkLiquidSidebarGlass: some View {
    if #available(macOS 26.0, *) {
      ZStack {
        sidebarBrandGradient
        Rectangle()
          .fill(Color("colorPrimary").opacity(0.06))
          .glassEffect(
            .regular.tint(Color("colorPrimary").opacity(0.18)),
            in: Rectangle()
          )
      }
    } else {
      sidebarMaterialBackground
    }
  }

  private var sidebarBrandGradient: some View {
    ZStack {
      Color.black.opacity(isDark ? 0.38 : 0.22)
      LinearGradient(
        colors: isDark
          ? [
            Color("colorPrimary").opacity(0.72),
            Color("colorPrimary").opacity(0.55),
            Color("colorSecondary").opacity(0.20),
          ]
          : [
            Color("colorPrimary").opacity(0.65),
            Color("colorPrimary").opacity(0.55),
            Color("colorSecondary").opacity(0.22),
          ],
        startPoint: .top,
        endPoint: .bottom
      )
    }
  }

  private var sidebarMaterialBackground: some View {
    Rectangle()
      .fill(Color("colorPrimary").opacity(0.44))
      .background(.ultraThinMaterial)
      .overlay {
        Rectangle()
          .fill(
            LinearGradient(
              colors: [
                Color("colorPrimary").opacity(0.18),
                Color(hex: "#758573").opacity(0.24),
                Color(hex: "#56634F").opacity(0.30),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }
  }
}
