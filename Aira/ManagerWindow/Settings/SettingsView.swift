import AppKit
import SwiftUI

// MARK: - Tab

private enum SettingsTab: CaseIterable, Hashable {
  case appearance, notch, satellite, shortcuts, system

  var label: String {
    switch self {
    case .appearance: return "Appearance"
    case .notch: return "The Notch"
    case .satellite: return "Pill Windows"
    case .shortcuts: return "Shortcuts"
    case .system: return "Session"
    }
  }
}

enum SettingsColorSwatchControlKind: Equatable {
  case appKitColorWell
  case appKitPanelButton
}

struct SettingsControlAffordance: Equatable {
  let usesFullVisibleHitTarget: Bool
  let usesPointingHandCursor: Bool
  let fillsVisibleTile: Bool
  let colorSwatchControlKind: SettingsColorSwatchControlKind?
}

enum SettingsControlAffordances {
  static let resetButton = SettingsControlAffordance(
    usesFullVisibleHitTarget: true,
    usesPointingHandCursor: true,
    fillsVisibleTile: false,
    colorSwatchControlKind: nil
  )
  static let customColorSwatch = SettingsControlAffordance(
    usesFullVisibleHitTarget: true,
    usesPointingHandCursor: true,
    fillsVisibleTile: true,
    colorSwatchControlKind: .appKitPanelButton
  )
}

enum SettingsSelectionAffordances {
  static let managerInterfaceStyleUsesNativeProminentGlass = false
  static let managerInterfaceStyleOuterSpacing: CGFloat = 0
  static let managerInterfaceStyleSelectedTextUsesWhite = true
}

enum SettingsFrostedGlassToggleTypography {
  static let titleUsesOverlayControlLabelTypography = true
  static let titleRequestedSize: CGFloat = 22
}

enum SettingsFrostedGlassTogglePlacement {
  static let appearsAfterOverlayFeelSliders = true
}

private enum SettingsFontRole {
  case display
  case body
  case bodyBold
  case compact

  func font(size: CGFloat, usesGlass: Bool) -> Font {
    guard usesGlass else {
      let size = classicSize(for: size)
      switch self {
      case .display:
        return .custom("IndieFlower", size: size)
      case .body, .compact:
        return .custom("CrimsonText-Regular", size: size)
      case .bodyBold:
        return .custom("Manrope-Bold", size: size)
      }
    }

    let size = glassSize(for: size)
    switch self {
    case .display:
      return .system(size: size, weight: .medium, design: .default)
    case .body:
      return .system(size: size, weight: .light, design: .default)
    case .bodyBold:
      return .system(size: size, weight: .medium, design: .default)
    case .compact:
      return .system(size: size, weight: .regular, design: .default)
    }
  }

  private func classicSize(for requestedSize: CGFloat) -> CGFloat {
    switch self {
    case .display:
      if requestedSize >= 28 { return 28 }
      if requestedSize >= 20 { return 22 }
      return 14
    case .body:
      if requestedSize >= 17 { return 18 }
      if requestedSize >= 15 { return 16 }
      return 14
    case .bodyBold:
      if requestedSize >= 17 { return 18 }
      if requestedSize >= 15 { return 16 }
      return 14
    case .compact:
      return 11
    }
  }

  private func glassSize(for requestedSize: CGFloat) -> CGFloat {
    switch self {
    case .display:
      if requestedSize >= 28 { return 24 }
      if requestedSize >= 20 { return 20 }
      return 12
    case .body:
      if requestedSize >= 17 { return 16 }
      if requestedSize >= 15 { return 15 }
      return 13
    case .bodyBold:
      if requestedSize >= 17 { return 16 }
      if requestedSize >= 15 { return 15 }
      return 13
    case .compact:
      return 12
    }
  }
}

private struct SettingsFontModifier: ViewModifier {
  @Environment(\.managerTheme) private var managerTheme
  let role: SettingsFontRole
  let size: CGFloat

  func body(content: Content) -> some View {
    content.font(role.font(size: size, usesGlass: managerTheme.usesLiquidGlassMode))
  }
}

extension View {
  fileprivate func settingsFont(_ role: SettingsFontRole, size: CGFloat) -> some View {
    modifier(SettingsFontModifier(role: role, size: size))
  }
}

enum SettingsChromePalette {
  static let classicDarkSurfaceHex = "#465649"
  static let liquidGlassDarkSurfaceHex = "#253D2E"
  static let liquidGlassLightSurfaceHex = "#849688"
  static let liquidGlassParentSurfaceOpacity = 0.08
  static let liquidGlassTitlebarSurfaceOpacity = 0.34
  static let liquidGlassPanelTintOpacity = 0.16

  static func classicSurface(appearanceMode: AppearanceMode) -> Color {
    classicSurface(appearanceMode: appearanceMode, palette: .aira)
  }

  static func classicSurface(
    appearanceMode: AppearanceMode,
    palette: ManagerColorPalette
  ) -> Color {
    classicSurface(
      appearanceMode: appearanceMode,
      palette: palette,
      colorScheme: appearanceMode == .dark ? .dark : .light
    )
  }

  static func classicSurface(
    appearanceMode: AppearanceMode,
    palette: ManagerColorPalette,
    colorScheme: ColorScheme
  ) -> Color {
    colorScheme == .dark ? palette.windowSubstrate(for: .dark) : palette.classicContentSurface
  }

  static func liquidGlassSubstrate(
    appearanceMode: AppearanceMode,
    palette: ManagerColorPalette,
    colorScheme: ColorScheme
  ) -> Color {
    colorScheme == .dark
      ? palette.windowSubstrate(for: .dark) : palette.windowSubstrate(for: .light)
  }
}

enum SettingsLayoutParity {
  static let sectionSpacing: CGFloat = 16
  static let panelPadding: CGFloat = 20
  static let panelCornerRadius: CGFloat = 20
  static let sectionTitleHeight: CGFloat = 34
  static let sectionDescriptionHeight: CGFloat = 40
  static let appearanceThemeCardHeight: CGFloat = 160
  static let paletteCardHeight: CGFloat = 58
  static let managerInterfaceCardHeight: CGFloat = 92
  static let typographyControlHeight: CGFloat = 46
}

private struct SettingsPointingHandCursorModifier: ViewModifier {
  @State private var isHovering = false

  func body(content: Content) -> some View {
    content
      .onHover { hovering in
        guard hovering != isHovering else { return }
        if hovering {
          NSCursor.pointingHand.push()
          isHovering = true
        } else {
          NSCursor.pop()
          isHovering = false
        }
      }
      .onDisappear {
        guard isHovering else { return }
        NSCursor.pop()
        isHovering = false
      }
  }
}

extension View {
  fileprivate func settingsPointingHandCursor() -> some View {
    modifier(SettingsPointingHandCursorModifier())
  }
}

private struct SettingsColorPanelButtonBridge: NSViewRepresentable {
  @Binding var selection: Color

  func makeCoordinator() -> Coordinator {
    Coordinator(selection: $selection)
  }

  func makeNSView(context: Context) -> NSButton {
    let button = NSButton()
    button.translatesAutoresizingMaskIntoConstraints = false
    button.title = ""
    button.isBordered = false
    button.bezelStyle = .regularSquare
    button.target = context.coordinator
    button.action = #selector(Coordinator.openColorPanel(_:))
    return button
  }

  func updateNSView(_ nsView: NSButton, context: Context) {
    context.coordinator.updateSelectionBinding($selection)
  }

  final class Coordinator: NSObject {
    private var selection: Binding<Color>

    init(selection: Binding<Color>) {
      self.selection = selection
    }

    func updateSelectionBinding(_ selection: Binding<Color>) {
      self.selection = selection
    }

    @objc func openColorPanel(_ sender: NSButton) {
      let panel = NSColorPanel.shared
      panel.showsAlpha = false
      panel.isContinuous = true
      panel.setTarget(self)
      panel.setAction(#selector(colorPanelDidChange(_:)))
      panel.color = nsColor(from: selection.wrappedValue)
      panel.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    }

    @objc func colorPanelDidChange(_ sender: NSColorPanel) {
      selection.wrappedValue = Color(sender.color)
    }

    func nsColor(from color: Color) -> NSColor {
      NSColor(color).usingColorSpace(.sRGB) ?? .white
    }
  }
}

// MARK: - Root

struct SettingsView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.dismiss) var dismiss
  @Environment(\.colorScheme) private var colorScheme
  @State private var activeTab: SettingsTab = .appearance
  var availableSize: CGSize? = nil
  var onClose: (() -> Void)? = nil

  private static let idealSize = CGSize(width: 860, height: 760)
  private let sidebarWidth: CGFloat = 214
  private let contentMaxWidth: CGFloat = 780

  private var resolvedSize: CGSize {
    let availableWidth = availableSize?.width ?? Self.idealSize.width
    let availableHeight = availableSize?.height ?? Self.idealSize.height
    return CGSize(
      width: min(Self.idealSize.width, availableWidth),
      height: min(Self.idealSize.height, availableHeight)
    )
  }

  private var usesLiquidGlassMode: Bool {
    appState.settings.managerInterfaceStyle == .liquidGlass
  }

  private var resolvedManagerColorScheme: ColorScheme {
    switch appState.settings.appearanceMode {
    case .light:
      return .light
    case .dark:
      return .dark
    case .system:
      return colorScheme
    }
  }

  private var activeManagerTheme: ManagerTheme {
    ManagerTheme(
      interfaceStyle: appState.settings.managerInterfaceStyle,
      colorPalette: appState.settings.managerColorPalette,
      accentColorHex: appState.settings.managerAccentColorHex
    )
  }

  private var topChromeColor: Color {
    if usesLiquidGlassMode {
      return settingsLiquidGlassSubstrateColor
    }

    return SettingsChromePalette.classicSurface(
      appearanceMode: appState.settings.appearanceMode,
      palette: appState.settings.managerColorPalette,
      colorScheme: resolvedManagerColorScheme
    )
  }

  private var settingsLiquidGlassSubstrateColor: Color {
    SettingsChromePalette.liquidGlassSubstrate(
      appearanceMode: appState.settings.appearanceMode,
      palette: appState.settings.managerColorPalette,
      colorScheme: resolvedManagerColorScheme
    )
  }

  private var settingsContentBackgroundColor: Color {
    usesLiquidGlassMode
      ? settingsLiquidGlassSubstrateColor
      : SettingsChromePalette.classicSurface(
        appearanceMode: appState.settings.appearanceMode,
        palette: appState.settings.managerColorPalette,
        colorScheme: resolvedManagerColorScheme
      )
  }

  var body: some View {
    rootContent
      .frame(
        maxWidth: availableSize == nil ? .infinity : nil,
        maxHeight: availableSize == nil ? .infinity : nil
      )
      .frame(
        width: availableSize == nil ? nil : resolvedSize.width,
        height: availableSize == nil ? nil : resolvedSize.height
      )
      .environment(
        \.managerTheme,
        activeManagerTheme
      )
      .modifier(
        SettingsChromeModifier(
          isStandaloneWindow: availableSize == nil,
          backgroundColor: settingsContentBackgroundColor,
          usesLiquidGlassMode: usesLiquidGlassMode
        )
      )
      .background(SettingsWindowAppearanceAccessor(usesLiquidGlassMode: usesLiquidGlassMode))
  }

  private var rootContent: some View {
    VStack(spacing: 0) {
      windowHeader
      contentArea
    }
  }

  // MARK: Header / Sidebar

  private var windowHeader: some View {
    HStack(alignment: .center, spacing: 12) {
      Text("Preferences")
        .settingsFont(.display, size: 30)
        .foregroundStyle(Color("colorText"))
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 24)
    .padding(.top, 20)
    .padding(.bottom, 18)
    .modifier(
      SettingsParentSurfaceModifier(
        fillColor: topChromeColor,
        usesLiquidGlassMode: usesLiquidGlassMode,
        isTitlebarSurface: true
      )
    )
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color("colorText").opacity(0.12))
        .frame(height: 1)
    }
  }

  private func sidebarTabButton(_ tab: SettingsTab) -> some View {
    let isActive = activeTab == tab
    return Button {
      withAnimation(.easeInOut(duration: 0.15)) { activeTab = tab }
    } label: {
      HStack(spacing: 10) {
        Text(tab.label)
          .settingsFont(.display, size: 23)
          .foregroundStyle(
            appState.settings.appearanceMode == .dark
              ? Color.white
              : (isActive
                ? activeManagerTheme.readableAccentForeground(
                  for: colorScheme,
                  accent: activeManagerTheme.primaryAccent(for: colorScheme)
                )
                : Color("colorText").opacity(0.82))
          )
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 14)
      .background(isActive ? activeManagerTheme.primaryAccent(for: colorScheme) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .shadow(color: Color("colorText").opacity(isActive ? 0.15 : 0), radius: 8, y: 8)
    }
    .buttonStyle(.plain)
  }

  // MARK: Content Area (cream)

  private var contentArea: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        ForEach(SettingsTab.allCases, id: \.self) { tab in
          sidebarTabButton(tab)
        }
        Spacer(minLength: 0)
      }
      .padding(16)
      .frame(width: sidebarWidth)
      .frame(maxHeight: .infinity, alignment: .top)
      .modifier(
        SettingsParentSurfaceModifier(
          fillColor: topChromeColor, usesLiquidGlassMode: usesLiquidGlassMode))

      Rectangle()
        .fill(Color("colorText").opacity(0.12))
        .frame(width: 1)

      Group {
        switch activeTab {
        case .appearance:
          settingsScrollContainer {
            AppearanceTabContent()
          }
        case .notch:
          settingsStaticContainer {
            NotchTabContent()
          }
        case .satellite:
          settingsScrollContainer {
            SatelliteTabContent()
          }
        case .shortcuts:
          settingsScrollContainer {
            ShortcutsTabContent()
          }
        case .system:
          settingsScrollContainer {
            SystemTabContent()
          }
        }
      }
      .modifier(
        SettingsParentSurfaceModifier(
          fillColor: settingsContentBackgroundColor,
          usesLiquidGlassMode: usesLiquidGlassMode
        )
      )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func settingsScrollContainer<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    ScrollView {
      content()
        .frame(maxWidth: contentMaxWidth, alignment: .leading)
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .top)
    }
    .scrollIndicators(.never)
  }

  private func settingsStaticContainer<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    content()
      .frame(maxWidth: contentMaxWidth, alignment: .leading)
      .padding(28)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}

private struct SettingsChromeModifier: ViewModifier {
  let isStandaloneWindow: Bool
  let backgroundColor: Color
  let usesLiquidGlassMode: Bool

  func body(content: Content) -> some View {
    if isStandaloneWindow {
      content
        .modifier(
          SettingsParentSurfaceModifier(
            fillColor: backgroundColor,
            usesLiquidGlassMode: usesLiquidGlassMode
          )
        )
    } else {
      content
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
          RoundedRectangle(cornerRadius: 28)
            .stroke(Color("colorText").opacity(0.15), lineWidth: 3)
        )
    }
  }
}

private struct SettingsParentSurfaceModifier: ViewModifier {
  let fillColor: Color
  let usesLiquidGlassMode: Bool
  var isTitlebarSurface = false
  @Environment(\.colorScheme) private var colorScheme

  private var isDark: Bool { colorScheme == .dark }

  func body(content: Content) -> some View {
    content
      .background {
        if usesLiquidGlassMode {
          ZStack {
            if isTitlebarSurface {
              Rectangle().fill(.regularMaterial)
              fillColor.opacity(SettingsChromePalette.liquidGlassTitlebarSurfaceOpacity)
            } else {
              Rectangle().fill(.ultraThinMaterial)
              fillColor.opacity(SettingsChromePalette.liquidGlassParentSurfaceOpacity)
            }
          }
        } else {
          fillColor
        }
      }
  }
}

private struct SettingsWindowAppearanceAccessor: NSViewRepresentable {
  let usesLiquidGlassMode: Bool

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    Task { @MainActor in
      context.coordinator.configureIfNeeded(
        view.window, usesLiquidGlassMode: usesLiquidGlassMode)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    Task { @MainActor in
      context.coordinator.configureIfNeeded(
        nsView.window, usesLiquidGlassMode: usesLiquidGlassMode)
    }
  }

  @MainActor
  final class Coordinator {
    private weak var lastWindow: NSWindow?
    private var lastMode: Bool?

    func configureIfNeeded(_ window: NSWindow?, usesLiquidGlassMode: Bool) {
      guard let window else { return }
      // Only reconfigure when the window or mode actually changed.
      guard window !== lastWindow || usesLiquidGlassMode != lastMode else { return }
      lastWindow = window
      lastMode = usesLiquidGlassMode

      if usesLiquidGlassMode {
        if window.isOpaque { window.isOpaque = false }
        if window.backgroundColor != .clear { window.backgroundColor = .clear }
        if window.titlebarAppearsTransparent { window.titlebarAppearsTransparent = false }
        if window.titleVisibility != .hidden { window.titleVisibility = .hidden }
      } else {
        if !window.isOpaque { window.isOpaque = true }
        if window.backgroundColor != .windowBackgroundColor {
          window.backgroundColor = .windowBackgroundColor
        }
      }
    }
  }
}

// MARK: - Shared Helpers

private struct SettingsPanel<Content: View>: View {
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme
  @ViewBuilder let content: () -> Content

  var body: some View {
    let shape = RoundedRectangle(
      cornerRadius: SettingsLayoutParity.panelCornerRadius,
      style: .continuous
    )
    let usesGlass = managerTheme.usesLiquidGlassMode

    VStack(alignment: .leading, spacing: 0) { content() }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(SettingsLayoutParity.panelPadding)
      .background {
        if usesGlass {
          ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(
              managerTheme.colorPalette == .aira
                ? (colorScheme == .dark
                  ? Color.black.opacity(SettingsChromePalette.liquidGlassPanelTintOpacity)
                  : Color.white.opacity(SettingsChromePalette.liquidGlassPanelTintOpacity))
                : managerTheme.surfaceFill(for: colorScheme).opacity(
                  colorScheme == .dark ? 0.62 : 0.82)
            )
          }
        } else {
          shape.fill(managerTheme.surfaceFill(for: colorScheme).opacity(0.92))
        }
      }
      .clipShape(shape)
      .overlay {
        shape.stroke(
          Color("colorText").opacity(usesGlass ? 0.08 : 0.10),
          lineWidth: usesGlass ? 1 : 1.5
        )
      }
  }
}

private struct SectionTitle: View {
  let text: String
  var body: some View {
    Text(text)
      .settingsFont(.display, size: 28)
      .foregroundStyle(Color("colorText"))
      .frame(height: SettingsLayoutParity.sectionTitleHeight, alignment: .leading)
  }
}

private struct FieldLabel: View {
  let text: String
  var body: some View {
    Text(text)
      .settingsFont(.display, size: 14)
      .foregroundStyle(Color("colorText").opacity(0.66))
  }
}

private struct FrostedGlassToggleRow: View {
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  let title: String
  var description: String? = nil
  @Binding var isOn: Bool

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .settingsFont(
            .display,
            size: SettingsFrostedGlassToggleTypography.titleRequestedSize
          )
          .foregroundStyle(Color("colorText"))
        if let description {
          Text(description)
            .settingsFont(.body, size: 14)
            .foregroundStyle(Color("colorText").opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer()
      Toggle("", isOn: $isOn)
        .toggleStyle(.switch)
        .tint(managerTheme.primaryAccent(for: colorScheme))
        .labelsHidden()
    }
  }
}

// MARK: - Shortcut keycap display + recorder

/// Displays a keyboard shortcut as styled keycaps.
/// Tap to enter recording mode; press the new combo to save; press Escape or click away to cancel.
private struct ShortcutKeyCapsField: View {
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  @Binding var shortcut: String
  @State private var isRecording = false
  @State private var keyMonitor: Any?

  var body: some View {
    Group {
      if isRecording {
        Text("Type shortcut…")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(managerTheme.primaryAccent(for: colorScheme))
          .padding(.horizontal, 14)
          .padding(.vertical, 9)
          .background(managerTheme.controlFill(for: colorScheme))
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(managerTheme.primaryAccent(for: colorScheme), lineWidth: 2))
      } else {
        ShortcutKeyCapsView(shortcut: shortcut)
          .onTapGesture { startRecording() }
      }
    }
    .onDisappear { stopRecording() }
  }

  private func startRecording() {
    isRecording = true
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [
      .keyDown, .leftMouseDown, .rightMouseDown,
    ]) { event in
      if event.type == .keyDown {
        // Escape cancels without saving
        if KeyboardShortcutDisplay.matches(event: event, shortcut: "Escape") {
          stopRecording()
          return nil
        }
        if let displayString = KeyboardShortcutDisplay.string(
          keyCode: event.keyCode,
          modifierFlags: event.modifierFlags,
          charactersIgnoringModifiers: event.charactersIgnoringModifiers
        ) {
          shortcut = displayString
          stopRecording()
        } else {
          NSSound.beep()
        }
        return nil
      } else {
        // Click anywhere cancels recording
        stopRecording()
        return event
      }
    }
  }

  private func stopRecording() {
    isRecording = false
    if let m = keyMonitor {
      NSEvent.removeMonitor(m)
      keyMonitor = nil
    }
  }
}

/// Tokenises a shortcut string and renders each token as a physical keycap.
private struct ShortcutKeyCapsView: View {
  let shortcut: String

  var body: some View {
    HStack(spacing: 4) {
      ForEach(tokens, id: \.self) { token in
        KeyCapView(label: token)
      }
    }
  }

  private var tokens: [String] {
    let modifiers: Set<Character> = ["⌘", "⌃", "⌥", "⇧"]
    var result: [String] = []
    var rest = shortcut
    while let c = rest.first, modifiers.contains(c) {
      result.append(String(c))
      rest = String(rest.dropFirst())
    }
    if !rest.isEmpty { result.append(rest) }
    return result
  }
}

private struct KeyCapView: View {
  let label: String

  private var fontSize: CGFloat {
    switch label {
    case "⌘", "⌃", "⌥", "⇧": return 16
    case "Space", "Escape", "Return", "Delete", "Tab": return 11
    default: return 13
    }
  }

  private var minWidth: CGFloat {
    switch label {
    case "Space": return 54
    case "Escape", "Return", "Delete": return 46
    case "Tab": return 36
    default: return 28
    }
  }

  var body: some View {
    Text(label)
      .font(.system(size: fontSize, weight: .semibold, design: .rounded))
      .foregroundStyle(Color("colorText"))
      .padding(.horizontal, 7)
      .padding(.vertical, 6)
      .frame(minWidth: minWidth)
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(Color("colorTertiary"))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(Color("colorText").opacity(0.18), lineWidth: 1)
      )
  }
}

// MARK: - System Font Picker

private struct SystemFontPicker: View {
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  @Binding var selectedFont: String
  @State private var isExpanded = false

  private static let families: [String] = NSFontManager.shared.availableFontFamilies.sorted {
    $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button {
        isExpanded.toggle()
      } label: {
        HStack(spacing: 10) {
          Text(selectedFont)
            .font(.custom(selectedFont, size: 16))
            .foregroundStyle(Color("colorText"))
            .lineLimit(1)
          Spacer()
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color("colorText").opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(managerTheme.controlFill(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
          RoundedRectangle(cornerRadius: 14)
            .stroke(Color("colorText").opacity(0.12), lineWidth: 1.5)
        )
      }
      .buttonStyle(.plain)
      .frame(maxWidth: .infinity, alignment: .leading)

      if isExpanded {
        ScrollView {
          LazyVStack(spacing: 6) {
            ForEach(Self.families, id: \.self) { family in
              Button {
                selectedFont = family
                isExpanded = false
              } label: {
                HStack(spacing: 12) {
                  Text(family)
                    .font(.custom(family, size: 15))
                    .foregroundStyle(Color("colorText"))
                    .lineLimit(1)
                  Spacer()
                  if selectedFont == family {
                    Image(systemName: "checkmark")
                      .font(.system(size: 12, weight: .semibold))
                      .foregroundStyle(managerTheme.primaryAccent(for: colorScheme))
                  }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(managerTheme.controlFill(for: colorScheme).opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                  RoundedRectangle(cornerRadius: 12)
                    .stroke(
                      selectedFont == family
                        ? managerTheme.primaryAccent(for: colorScheme)
                        : Color("colorText").opacity(0.08),
                      lineWidth: selectedFont == family ? 2 : 1
                    )
                )
              }
              .buttonStyle(.plain)
            }
          }
          .padding(8)
        }
        .frame(maxHeight: 220)
        .background(managerTheme.surfaceFill(for: colorScheme).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(Color("colorText").opacity(0.1), lineWidth: 1)
        )
      }

      HStack {
        Text("Preview")
          .settingsFont(.body, size: 14)
          .foregroundStyle(Color("colorMuted"))
        Spacer()
        Text("The quick brown fox jumps over the lazy dog")
          .font(.custom(selectedFont, size: 18))
          .foregroundStyle(Color("colorText"))
          .lineLimit(1)
      }
      .padding(.horizontal, 14)
    }
  }
}

// MARK: - Appearance Tab

private struct AppearanceTabContent: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  private let sizes: [(String, ManagerTypography)] = [
    ("Small", .small), ("Medium", .medium), ("Large", .large),
  ]

  var body: some View {
    VStack(spacing: SettingsLayoutParity.sectionSpacing) {

      // App Theme
      SettingsPanel {
        SectionTitle(text: "Theme")
        Text("Choose the Manager App color mode.")
          .settingsFont(.body, size: 16)
          .foregroundStyle(Color("colorText").opacity(0.68))
          .fixedSize(horizontal: false, vertical: true)
          .frame(
            maxWidth: .infinity,
            minHeight: SettingsLayoutParity.sectionDescriptionHeight,
            maxHeight: SettingsLayoutParity.sectionDescriptionHeight,
            alignment: .topLeading
          )
          .padding(.top, 4)

        HStack(spacing: 14) {
          themeCard(
            "Light",
            "Light background with dark text.",
            Color(hex: "#F5F2EC"), .light)
          themeCard(
            "Dark",
            "Dark background with light text.",
            Color(hex: "#2B2B2B"), .dark)
        }
        .padding(.top, 14)
      }

      SettingsPanel {
        SectionTitle(text: "Palette")
        Text("Choose Aira's signature palette, or a neutral app with blue or violet accents.")
          .settingsFont(.body, size: 16)
          .foregroundStyle(Color("colorText").opacity(0.68))
          .fixedSize(horizontal: false, vertical: true)
          .frame(
            maxWidth: .infinity,
            minHeight: SettingsLayoutParity.sectionDescriptionHeight,
            maxHeight: SettingsLayoutParity.sectionDescriptionHeight,
            alignment: .topLeading
          )
          .padding(.top, 4)

        HStack(spacing: 8) {
          ForEach(ManagerColorPalette.allCases, id: \.self) { palette in
            managerColorPaletteButton(palette)
          }
        }
        .padding(.top, 10)
      }

      SettingsPanel {
        SectionTitle(text: "Manager UI")
        Text(
          "Choose how the Manager App chrome is drawn. Overlay windows keep their current presentation."
        )
        .settingsFont(.body, size: 16)
        .foregroundStyle(Color("colorText").opacity(0.68))
        .fixedSize(horizontal: false, vertical: true)
        .frame(
          maxWidth: .infinity,
          minHeight: SettingsLayoutParity.sectionDescriptionHeight,
          maxHeight: SettingsLayoutParity.sectionDescriptionHeight,
          alignment: .topLeading
        )
        .padding(.top, 4)

        HStack(spacing: 10) {
          managerInterfaceStyleButton(.classic)
          managerInterfaceStyleButton(.liquidGlass)
        }
        .padding(.top, 14)
      }

      // Typography
      SettingsPanel {
        SectionTitle(text: "Typography")
        VStack(alignment: .leading, spacing: 14) {
          // Size buttons
          VStack(alignment: .leading, spacing: 8) {
            Text("Base Size")
              .settingsFont(.body, size: 14)
              .foregroundStyle(Color("colorText").opacity(0.66))
              .frame(height: 18, alignment: .leading)
            HStack(spacing: 8) {
              ForEach(sizes, id: \.0) { label, size in
                let isActive = appState.settings.managerTypography == size
                Button {
                  appState.settings.managerTypography = size
                } label: {
                  Text(label)
                    .settingsFont(.body, size: 18)
                    .foregroundStyle(Color("colorText"))
                    .frame(maxWidth: .infinity)
                    .frame(height: SettingsLayoutParity.typographyControlHeight)
                    .background(
                      isActive
                        ? managerTheme.primaryAccent(for: colorScheme).opacity(0.1)
                        : managerTheme.controlFill(for: colorScheme).opacity(0.75)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                      RoundedRectangle(cornerRadius: 14)
                        .stroke(
                          isActive
                            ? managerTheme.primaryAccent(for: colorScheme)
                            : Color("colorText").opacity(0.14),
                          lineWidth: isActive ? 3 : 2))
                }
                .buttonStyle(.plain)
              }
            }
          }
        }
        .padding(.top, 14)
      }
    }
  }

  private func themeCard(_ label: String, _ tone: String, _ swatch: Color, _ mode: AppearanceMode)
    -> some View
  {
    let isActive = appState.settings.appearanceMode == mode
    return Button {
      appState.settings.appearanceMode = mode
    } label: {
      VStack(alignment: .leading, spacing: 0) {
        HStack {
          Spacer(minLength: 0)
          swatch
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(Color("colorText").opacity(0.14), lineWidth: 2))
          Spacer(minLength: 0)
        }
        Text(label)
          .settingsFont(.display, size: 24)
          .foregroundStyle(Color("colorText"))
          .padding(.top, 10)
        Text(tone)
          .settingsFont(.body, size: 14)
          .foregroundStyle(Color("colorText").opacity(0.64))
          .lineSpacing(2)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 4)
      }
      .padding(14)
      .frame(height: SettingsLayoutParity.appearanceThemeCardHeight, alignment: .topLeading)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        isActive
          ? managerTheme.primaryAccent(for: colorScheme).opacity(0.1)
          : managerTheme.surfaceFill(for: colorScheme).opacity(0.82)
      )
      .clipShape(RoundedRectangle(cornerRadius: 18))
      .overlay(
        RoundedRectangle(cornerRadius: 18)
          .stroke(
            isActive
              ? managerTheme.primaryAccent(for: colorScheme)
              : Color("colorText").opacity(0.16),
            lineWidth: isActive ? 3 : 2))
    }
    .buttonStyle(.plain)
  }

  private func managerColorPaletteButton(_ palette: ManagerColorPalette) -> some View {
    let isActive = appState.settings.managerColorPalette == palette
    let previewPrimary = palette.primaryAccent(for: colorScheme)
    let selectedFill =
      colorScheme == .dark ? Color.white.opacity(0.08) : Color("colorText").opacity(0.045)
    let idleFill =
      colorScheme == .dark
      ? Color.white.opacity(0.035) : palette.controlFill(for: colorScheme).opacity(0.54)
    return Button {
      appState.settings.managerColorPalette = palette
    } label: {
      HStack(spacing: 10) {
        HStack(spacing: -4) {
          ForEach(palette.lightPreviewColors, id: \.self) { hex in
            Circle()
              .fill(Color(hex: hex))
              .frame(width: 22, height: 22)
              .overlay(Circle().stroke(Color("colorText").opacity(0.18), lineWidth: 1))
          }
        }
        Text(palette.settingsTitle)
          .settingsFont(.body, size: 18)
          .foregroundStyle(Color("colorText"))
          .lineLimit(1)
        Spacer(minLength: 0)
        if isActive {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(previewPrimary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .frame(height: SettingsLayoutParity.paletteCardHeight, alignment: .center)
      .background(
        isActive ? selectedFill : idleFill
      )
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(
            isActive ? previewPrimary : Color("colorText").opacity(0.14),
            lineWidth: isActive ? 2 : 1
          )
      )
      .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func managerInterfaceStyleButton(_ style: ManagerInterfaceStyle) -> some View {
    let isActive = appState.settings.managerInterfaceStyle == style
    let activeForeground = managerTheme.readableAccentForeground(
      for: colorScheme,
      accent: managerTheme.primaryAccent(for: colorScheme)
    )
    return Button {
      appState.settings.managerInterfaceStyle = style
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        Text(style.settingsTitle)
          .settingsFont(.body, size: 18)
          .foregroundStyle(isActive ? activeForeground : Color("colorText"))
        Text(style.settingsDescription)
          .settingsFont(.body, size: 13)
          .foregroundStyle(
            isActive ? activeForeground.opacity(0.82) : Color("colorText").opacity(0.64)
          )
          .lineSpacing(2)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .frame(height: SettingsLayoutParity.managerInterfaceCardHeight, alignment: .topLeading)
      .background(
        isActive
          ? managerTheme.primaryAccent(for: colorScheme)
          : managerTheme.controlFill(for: colorScheme).opacity(0.72)
      )
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(
            Color("colorText").opacity(isActive ? 0.08 : 0.14),
            lineWidth: isActive ? 2 : 1.5
          )
      )
      .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Notch Tab

private struct NotchTabContent: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme
  private let swatchRowMaxWidth: CGFloat = 700
  private let swatchSpacing: CGFloat = 10

  private let colorPresets: [(String, String)] = [
    ("Sage", "#849688"),
    ("Clay", "#C98B7A"),
    ("Ink", "#2B2B2B"),
    ("Slate", "#6B8E99"),
    ("Warm Tan", "#D4A574"),
  ]
  private let textColorPresets: [(String, String)] = [
    ("Cream", "#F5F2EC"),
    ("White", "#FFFFFF"),
    ("Charcoal", "#2B2B2B"),
    ("Warm Tan", "#D4A574"),
  ]
  private var previewNotchSize: CGSize {
    NotchWindowController.notchSize(for: NotchWindowController.preferredBuiltInScreen())
  }
  private var previewHasPhysicalNotch: Bool { previewNotchSize != .zero }
  private var previewLayout: NotchPreviewLayout.ResolvedLayout {
    NotchPreviewLayout.resolve(
      text: previewSampleText,
      preferredWidth: appState.settings.notchWindowWidth,
      preferredHeight: appState.settings.notchWindowHeight,
      notchSize: previewNotchSize,
      appearance: appState.settings.defaultOverlayAppearance
    )
  }
  private let previewSampleText = NotchPreviewLayout.defaultSampleText
  private var previewPanelHeight: CGFloat {
    max(156, previewLayout.height + 28)
  }
  private var lineSpacingBinding: Binding<CGFloat> {
    Binding(
      get: {
        OverlayLineSpacingConfiguration.clamped(
          appState.settings.defaultOverlayAppearance.lineSpacing)
      },
      set: {
        appState.settings.defaultOverlayAppearance.lineSpacing =
          OverlayLineSpacingConfiguration.clamped($0)
      }
    )
  }

  private var letterSpacingBinding: Binding<CGFloat> {
    Binding(
      get: {
        OverlayLetterSpacingConfiguration.clamped(
          appState.settings.defaultOverlayAppearance.letterSpacing)
      },
      set: {
        appState.settings.defaultOverlayAppearance.letterSpacing =
          OverlayLetterSpacingConfiguration.clamped($0)
      }
    )
  }

  private var wordSpacingBinding: Binding<CGFloat> {
    Binding(
      get: {
        OverlayWordSpacingConfiguration.clamped(
          appState.settings.defaultOverlayAppearance.wordSpacing)
      },
      set: {
        appState.settings.defaultOverlayAppearance.wordSpacing =
          OverlayWordSpacingConfiguration.clamped($0)
      }
    )
  }

  private var textShadowBinding: Binding<CGFloat> {
    Binding(
      get: {
        OverlayTextShadowConfiguration.clamped(
          appState.settings.defaultOverlayAppearance.textShadow)
      },
      set: {
        appState.settings.defaultOverlayAppearance.textShadow =
          OverlayTextShadowConfiguration.clamped($0)
      }
    )
  }

  private var contentPaddingBinding: Binding<CGFloat> {
    Binding(
      get: {
        OverlayContentPaddingConfiguration.clamped(
          appState.settings.defaultOverlayAppearance.contentPadding)
      },
      set: {
        appState.settings.defaultOverlayAppearance.contentPadding =
          OverlayContentPaddingConfiguration.clamped($0)
      }
    )
  }

  // Binding that bridges Color ↔ hex string in appState
  private var overlayColorBinding: Binding<Color> {
    Binding(
      get: { Color(hex: appState.settings.defaultOverlayAppearance.backgroundColor) },
      set: { newColor in
        let fallbackColor =
          NSColor(Color(hex: appState.settings.defaultOverlayAppearance.backgroundColor))
          .usingColorSpace(.sRGB) ?? .white
        let ns = NSColor(newColor).usingColorSpace(.sRGB) ?? fallbackColor
        let hex = String(
          format: "#%02X%02X%02X",
          Int((ns.redComponent * 255).rounded()),
          Int((ns.greenComponent * 255).rounded()),
          Int((ns.blueComponent * 255).rounded()))
        appState.settings.defaultOverlayAppearance.backgroundColor = hex
      }
    )
  }

  private var overlayTextColorBinding: Binding<Color> {
    Binding(
      get: { Color(hex: appState.settings.defaultOverlayAppearance.textColor) },
      set: { newColor in
        let fallbackColor =
          NSColor(Color(hex: appState.settings.defaultOverlayAppearance.textColor))
          .usingColorSpace(.sRGB) ?? .black
        let ns = NSColor(newColor).usingColorSpace(.sRGB) ?? fallbackColor
        let hex = String(
          format: "#%02X%02X%02X",
          Int((ns.redComponent * 255).rounded()),
          Int((ns.greenComponent * 255).rounded()),
          Int((ns.blueComponent * 255).rounded()))
        appState.settings.defaultOverlayAppearance.textColor = hex
      }
    )
  }

  var body: some View {
    VStack(spacing: 16) {
      notchPreviewPanel

      ScrollView {
        VStack(spacing: 16) {
          // ── Overlay Color ────────────────────────────────────────
          SettingsPanel {
            SectionTitle(text: "Overlay Color")

            // Background color row
            FieldLabel(text: "Background Color")
            LazyVGrid(
              columns: Array(repeating: GridItem(.flexible(), spacing: swatchSpacing), count: 6),
              spacing: swatchSpacing
            ) {
              ForEach(colorPresets, id: \.0) { name, hex in
                let isActive = appState.settings.defaultOverlayAppearance.backgroundColor == hex
                Button {
                  appState.settings.defaultOverlayAppearance.backgroundColor = hex
                } label: {
                  swatchTile(
                    name: name,
                    isActive: isActive
                  ) {
                    RoundedRectangle(cornerRadius: 10)
                      .fill(Color(hex: hex))
                      .aspectRatio(1, contentMode: .fit)
                  }
                }
                .buttonStyle(.plain)
              }

              swatchTile(name: "Custom", isActive: false) {
                customColorSwatch(selection: overlayColorBinding)
              }
            }
            .padding(.top, 8)
            .frame(maxWidth: swatchRowMaxWidth)
            .frame(maxWidth: .infinity)

            Divider().padding(.vertical, 8)

            // Text color row
            FieldLabel(text: "Text Color")
            LazyVGrid(
              columns: Array(repeating: GridItem(.flexible(), spacing: swatchSpacing), count: 5),
              spacing: swatchSpacing
            ) {
              ForEach(textColorPresets, id: \.0) { name, hex in
                let isActive = appState.settings.defaultOverlayAppearance.textColor == hex
                Button {
                  appState.settings.defaultOverlayAppearance.textColor = hex
                } label: {
                  swatchTile(
                    name: name,
                    isActive: isActive
                  ) {
                    RoundedRectangle(cornerRadius: 10)
                      .fill(Color(hex: hex))
                      .aspectRatio(1, contentMode: .fit)
                      .overlay(
                        RoundedRectangle(cornerRadius: 10)
                          .stroke(Color("colorText").opacity(0.15), lineWidth: 1)
                      )
                  }
                }
                .buttonStyle(.plain)
              }

              swatchTile(name: "Custom", isActive: false) {
                customColorSwatch(selection: overlayTextColorBinding)
              }
            }
            .padding(.top, 8)
            .frame(maxWidth: swatchRowMaxWidth)
            .frame(maxWidth: .infinity)
          }

          controlsContent
        }
        .padding(.bottom, 4)
      }
      .scrollIndicators(.never)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private var notchPreviewPanel: some View {
    SettingsPanel {
      SectionTitle(text: "Preview")

      ZStack {
        Color(hex: "#434343")

        ZStack(alignment: .top) {
          if appState.settings.notchFrostedGlassEnabled {
            OverlayFrostedGlassBackground(appearance: appState.settings.defaultOverlayAppearance)
          } else {
            Color(hex: appState.settings.defaultOverlayAppearance.backgroundColor)
              .opacity(appState.settings.defaultOverlayAppearance.opacity)
          }
          OverlayAppearancePreviewText(
            text: previewSampleText,
            appearance: appState.settings.defaultOverlayAppearance,
            width: previewLayout.width,
            topPadding: previewLayout.topPadding
          )
        }
        .frame(width: previewLayout.width, height: previewLayout.height)
        .clipShape(
          NotchWrapShape(
            hasNotch: previewHasPhysicalNotch,
            notchSize: previewLayout.notchSize
          )
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
      }
      .frame(maxWidth: .infinity)
      .frame(height: previewPanelHeight)
      .clipShape(RoundedRectangle(cornerRadius: 24))
      .padding(.top, 8)
    }
  }

  private var controlsContent: some View {
    VStack(spacing: 16) {
      SettingsPanel {
        SectionTitle(text: "Overlay Feel")
        VStack(spacing: 16) {
          sliderRow(
            "Width",
            "\(Int(appState.settings.notchWindowWidth))pt",
            $appState.settings.notchWindowWidth,
            NotchWidthConfiguration.minimumWidth...NotchWidthConfiguration.maximumWidth)
          sliderRow(
            "Height",
            "\(Int(appState.settings.notchWindowHeight))pt",
            $appState.settings.notchWindowHeight,
            NotchHeightConfiguration.minimumHeight...NotchHeightConfiguration.maximumHeight)
          sliderRow(
            "Opacity",
            "\(Int(appState.settings.defaultOverlayAppearance.opacity * 100))%",
            $appState.settings.defaultOverlayAppearance.opacity,
            0.2...1.0)
          sliderRow(
            "Font Size",
            "\(Int(appState.settings.defaultOverlayAppearance.fontSize))pt",
            $appState.settings.defaultOverlayAppearance.fontSize,
            OverlayFontSizeConfiguration.minimum...OverlayFontSizeConfiguration.maximum)
          FrostedGlassToggleRow(
            title: "Frosted Glass",
            isOn: $appState.settings.notchFrostedGlassEnabled
          )

          HStack {
            Spacer()
            Button {
              resetOverlayFeelToDefaults()
            } label: {
              Text("Reset to Defaults")
                .settingsFont(.body, size: 16)
                .foregroundStyle(Color.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(managerTheme.primaryAccent(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .settingsPointingHandCursor()
          }
        }
        .padding(.top, 14)
      }

      SettingsPanel {
        SectionTitle(text: "Overlay Font")
        Text("Use this as the single place to choose the overlay typeface, including OpenDyslexic.")
          .settingsFont(.body, size: 14)
          .foregroundStyle(Color("colorText").opacity(0.6))
          .padding(.top, 2)
        SystemFontPicker(selectedFont: $appState.settings.defaultOverlayAppearance.fontName)
          .padding(.top, 10)
      }

      SettingsPanel {
        SectionTitle(text: "Accessibility")
        Text("Use layout-focused readability controls here without duplicating font choice.")
          .settingsFont(.body, size: 14)
          .foregroundStyle(Color("colorText").opacity(0.6))
          .padding(.top, 2)

        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: "Text Alignment")
            HStack(spacing: 8) {
              alignmentOptionButton(.left, label: "Left")
              alignmentOptionButton(.center, label: "Center")
              alignmentOptionButton(.justified, label: "Justified")
            }
          }

          readabilitySlider(
            label: "Line Spacing",
            valueText: "\(Int(lineSpacingBinding.wrappedValue.rounded()))pt",
            value: lineSpacingBinding,
            range: OverlayLineSpacingConfiguration
              .minimum...OverlayLineSpacingConfiguration.maximum,
            step: 1,
            minimumText: "\(Int(OverlayLineSpacingConfiguration.minimum))pt",
            maximumText: "\(Int(OverlayLineSpacingConfiguration.maximum))pt"
          )

          readabilitySlider(
            label: "Letter Spacing",
            valueText: String(format: "%.1fpt", letterSpacingBinding.wrappedValue),
            value: letterSpacingBinding,
            range: OverlayLetterSpacingConfiguration
              .minimum...OverlayLetterSpacingConfiguration.maximum,
            step: 0.1,
            minimumText: String(format: "%.1fpt", OverlayLetterSpacingConfiguration.minimum),
            maximumText: String(format: "%.1fpt", OverlayLetterSpacingConfiguration.maximum)
          )

          readabilitySlider(
            label: "Word Spacing",
            valueText: String(format: "%.1fpt", wordSpacingBinding.wrappedValue),
            value: wordSpacingBinding,
            range: OverlayWordSpacingConfiguration
              .minimum...OverlayWordSpacingConfiguration.maximum,
            step: 0.5,
            minimumText: "\(Int(OverlayWordSpacingConfiguration.minimum))pt",
            maximumText: "\(Int(OverlayWordSpacingConfiguration.maximum))pt"
          )

          readabilitySlider(
            label: "Text Shadow",
            valueText: String(format: "%.1f", textShadowBinding.wrappedValue),
            value: textShadowBinding,
            range: OverlayTextShadowConfiguration.minimum...OverlayTextShadowConfiguration.maximum,
            step: 0.5,
            minimumText: "Off",
            maximumText: String(format: "%.1f", OverlayTextShadowConfiguration.maximum)
          )

          readabilitySlider(
            label: "Text Padding",
            valueText: "\(Int(contentPaddingBinding.wrappedValue.rounded()))pt",
            value: contentPaddingBinding,
            range: OverlayContentPaddingConfiguration
              .minimum...OverlayContentPaddingConfiguration.maximum,
            step: 1,
            minimumText: "\(Int(OverlayContentPaddingConfiguration.minimum))pt",
            maximumText: "\(Int(OverlayContentPaddingConfiguration.maximum))pt"
          )
        }
        .padding(.top, 12)
      }
    }
  }

  private var previewNotchWidth: CGFloat {
    previewLayout.width
  }

  private var previewNotchHeight: CGFloat {
    previewLayout.height
  }

  private func sliderRow(
    _ label: String, _ valueText: String,
    _ value: Binding<Double>, _ range: ClosedRange<Double>
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(label).settingsFont(.display, size: 22).foregroundStyle(Color("colorText"))
        Spacer()
        Text(valueText).settingsFont(.display, size: 20).foregroundStyle(
          managerTheme.primaryAccent(for: colorScheme))
      }
      Slider(value: value, in: range).tint(managerTheme.primaryAccent(for: colorScheme))
    }
  }

  private func sliderRow(
    _ label: String, _ valueText: String,
    _ value: Binding<CGFloat>, _ range: ClosedRange<CGFloat>
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(label).settingsFont(.display, size: 22).foregroundStyle(Color("colorText"))
        Spacer()
        Text(valueText).settingsFont(.display, size: 20).foregroundStyle(
          managerTheme.primaryAccent(for: colorScheme))
      }
      Slider(value: value, in: range).tint(managerTheme.primaryAccent(for: colorScheme))
    }
  }

  private func swatchTile<Swatch: View>(
    name: String,
    isActive: Bool,
    @ViewBuilder swatch: () -> Swatch
  ) -> some View {
    VStack(spacing: 6) {
      swatch()
      Text(name)
        .settingsFont(.display, size: 12)
        .foregroundStyle(Color("colorText"))
        .lineLimit(1)
    }
    .padding(8)
    .frame(maxWidth: .infinity)
    .background(
      isActive
        ? managerTheme.primaryAccent(for: colorScheme).opacity(0.12)
        : managerTheme.controlFill(for: colorScheme).opacity(0.7)
    )
    .clipShape(RoundedRectangle(cornerRadius: 13))
    .overlay(
      RoundedRectangle(cornerRadius: 13)
        .stroke(
          isActive ? managerTheme.primaryAccent(for: colorScheme) : Color("colorText").opacity(0.1),
          lineWidth: isActive ? 2.5 : 1.5
        )
    )
  }

  private func customColorSwatch(selection: Binding<Color>) -> some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(hex: "#D98C7B"),
          Color(hex: "#D8B36A"),
          Color(hex: "#A8C28A"),
          Color(hex: "#7FAEB5"),
          Color(hex: "#A890C8"),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .saturation(0.72)
      .brightness(0.03)
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .fill(Color.white.opacity(0.18))
          .blur(radius: 10)
          .padding(8)
      )

      SettingsColorPanelButtonBridge(selection: selection)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .aspectRatio(1, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .contentShape(RoundedRectangle(cornerRadius: 10))
    .settingsPointingHandCursor()
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color("colorText").opacity(0.12), lineWidth: 1)
    )
  }

  private func resetOverlayFeelToDefaults() {
    appState.settings.notchWindowWidth = NotchWidthConfiguration.defaultWidth
    appState.settings.notchWindowHeight = NotchHeightConfiguration.defaultHeight
    appState.settings.defaultOverlayAppearance = .default
  }

  @ViewBuilder
  private func alignmentOptionButton(_ alignment: OverlayTextAlignment, label: String) -> some View
  {
    let isSelected = appState.settings.defaultOverlayAppearance.textAlignment == alignment

    Button {
      appState.settings.defaultOverlayAppearance.textAlignment = alignment
    } label: {
      Text(label)
        .settingsFont(.body, size: 17)
        .foregroundStyle(isSelected ? Color.white : Color("colorText"))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
          isSelected
            ? managerTheme.primaryAccent(for: colorScheme)
            : managerTheme.controlFill(for: colorScheme)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(
              isSelected
                ? managerTheme.primaryAccent(for: colorScheme) : Color("colorText").opacity(0.14),
              lineWidth: isSelected ? 2.5 : 1.5
            )
        )
    }
    .buttonStyle(.plain)
  }

  private func readabilitySlider(
    label: String,
    valueText: String,
    value: Binding<CGFloat>,
    range: ClosedRange<CGFloat>,
    step: CGFloat,
    minimumText: String,
    maximumText: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        FieldLabel(text: label)
        Spacer()
        Text(valueText)
          .settingsFont(.body, size: 16)
          .foregroundStyle(managerTheme.primaryAccent(for: colorScheme))
      }

      Slider(
        value: value,
        in: range,
        step: step
      )
      .tint(managerTheme.primaryAccent(for: colorScheme))

      HStack {
        Text(minimumText)
        Spacer()
        Text(maximumText)
      }
      .settingsFont(.body, size: 14)
      .foregroundStyle(Color("colorText").opacity(0.55))
    }
  }

}

// MARK: - Pill Windows Tab

private struct SatelliteTabContent: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme
  @State private var selectedSatelliteSlot = 1
  private let swatchRowMaxWidth: CGFloat = 700
  private let swatchSpacing: CGFloat = 10

  private let colorPresets: [(String, String)] = [
    ("Sage", "#849688"),
    ("Clay", "#C98B7A"),
    ("Ink", "#2B2B2B"),
    ("Slate", "#6B8E99"),
    ("Warm Tan", "#D4A574"),
  ]
  private let textColorPresets: [(String, String)] = [
    ("Cream", "#F5F2EC"),
    ("White", "#FFFFFF"),
    ("Charcoal", "#2B2B2B"),
    ("Warm Tan", "#D4A574"),
  ]
  private let previewSampleText =
    "Pill Window preview uses the selected slot's readability defaults."

  private var selectedSlotOverride: OverlayAppearance? {
    appState.settings.satelliteAppearanceOverride(forSlot: selectedSatelliteSlot)
  }

  private var selectedSlotAppearance: OverlayAppearance {
    appState.settings.effectiveSatelliteAppearance(forSlot: selectedSatelliteSlot)
  }

  private var selectedSlotIsInherited: Bool {
    selectedSlotOverride == nil
  }

  private var lineSpacingBinding: Binding<CGFloat> {
    appearanceMetricBinding(
      getValue: \.lineSpacing,
      clamp: OverlayLineSpacingConfiguration.clamped,
      setValue: { appearance, value in
        appearance.lineSpacing = value
      }
    )
  }

  private var letterSpacingBinding: Binding<CGFloat> {
    appearanceMetricBinding(
      getValue: \.letterSpacing,
      clamp: OverlayLetterSpacingConfiguration.clamped,
      setValue: { appearance, value in
        appearance.letterSpacing = value
      }
    )
  }

  private var wordSpacingBinding: Binding<CGFloat> {
    appearanceMetricBinding(
      getValue: \.wordSpacing,
      clamp: OverlayWordSpacingConfiguration.clamped,
      setValue: { appearance, value in
        appearance.wordSpacing = value
      }
    )
  }

  private var textShadowBinding: Binding<CGFloat> {
    appearanceMetricBinding(
      getValue: \.textShadow,
      clamp: OverlayTextShadowConfiguration.clamped,
      setValue: { appearance, value in
        appearance.textShadow = value
      }
    )
  }

  private var contentPaddingBinding: Binding<CGFloat> {
    appearanceMetricBinding(
      getValue: \.contentPadding,
      clamp: OverlayContentPaddingConfiguration.clamped,
      setValue: { appearance, value in
        appearance.contentPadding = value
      }
    )
  }

  private var opacityBinding: Binding<Double> {
    Binding(
      get: { selectedSlotAppearance.opacity },
      set: { newValue in
        updateSelectedSlotAppearance { appearance in
          appearance.opacity = newValue
        }
      }
    )
  }

  private var fontSizeBinding: Binding<CGFloat> {
    Binding(
      get: { selectedSlotAppearance.fontSize },
      set: { newValue in
        updateSelectedSlotAppearance { appearance in
          appearance.fontSize = newValue
        }
      }
    )
  }

  private var fontNameBinding: Binding<String> {
    Binding(
      get: { selectedSlotAppearance.fontName },
      set: { newValue in
        updateSelectedSlotAppearance { appearance in
          appearance.fontName = newValue
        }
      }
    )
  }

  private var overlayColorBinding: Binding<Color> {
    Binding(
      get: { Color(hex: selectedSlotAppearance.backgroundColor) },
      set: { newColor in
        let fallbackColor =
          NSColor(Color(hex: selectedSlotAppearance.backgroundColor)).usingColorSpace(.sRGB)
          ?? .white
        let ns = NSColor(newColor).usingColorSpace(.sRGB) ?? fallbackColor
        let hex = String(
          format: "#%02X%02X%02X",
          Int((ns.redComponent * 255).rounded()),
          Int((ns.greenComponent * 255).rounded()),
          Int((ns.blueComponent * 255).rounded()))
        updateSelectedSlotAppearance { appearance in
          appearance.backgroundColor = hex
        }
      }
    )
  }

  private var overlayTextColorBinding: Binding<Color> {
    Binding(
      get: { Color(hex: selectedSlotAppearance.textColor) },
      set: { newColor in
        let fallbackColor =
          NSColor(Color(hex: selectedSlotAppearance.textColor)).usingColorSpace(.sRGB) ?? .black
        let ns = NSColor(newColor).usingColorSpace(.sRGB) ?? fallbackColor
        let hex = String(
          format: "#%02X%02X%02X",
          Int((ns.redComponent * 255).rounded()),
          Int((ns.greenComponent * 255).rounded()),
          Int((ns.blueComponent * 255).rounded()))
        updateSelectedSlotAppearance { appearance in
          appearance.textColor = hex
        }
      }
    )
  }

  var body: some View {
    VStack(spacing: 16) {
      satellitePreviewPanel

      ScrollView {
        VStack(spacing: 16) {
          SettingsPanel {
            SectionTitle(text: "Pill Windows")
            Text(
              "Choose how many free-moving Pill Windows are available. Content is chosen when launching from the Script Editor."
            )
            .settingsFont(.body, size: 14)
            .foregroundStyle(Color("colorText").opacity(0.6))
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 16) {
              VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "Pill Window Count")
                HStack(spacing: 8) {
                  satelliteCountButton(count: 1)
                  satelliteCountButton(count: 2)
                }

                Text(
                  "Choose whether the explicit Pill Window launch flow offers one or two floating Pill Windows during a live session."
                )
                .settingsFont(.body, size: 14)
                .foregroundStyle(Color("colorText").opacity(0.62))
              }

              Divider().opacity(0.2)

              VStack(alignment: .leading, spacing: 10) {
                FieldLabel(text: "Configure Slot")
                HStack(spacing: 8) {
                  satelliteSlotButton(slot: 1)
                  satelliteSlotButton(slot: 2)
                }

                Text(
                  selectedSlotIsInherited
                    ? "Pill Window \(selectedSatelliteSlot) is currently inheriting The Notch defaults. Adjust any control below to create a slot-specific override."
                    : "Pill Window \(selectedSatelliteSlot) is using its own saved appearance and readability defaults."
                )
                .settingsFont(.body, size: 14)
                .foregroundStyle(Color("colorText").opacity(0.62))
              }
            }
            .padding(.top, 12)
          }

          SettingsPanel {
            SectionTitle(text: "Overlay Color")

            FieldLabel(text: "Background Color")
            LazyVGrid(
              columns: Array(repeating: GridItem(.flexible(), spacing: swatchSpacing), count: 6),
              spacing: swatchSpacing
            ) {
              ForEach(colorPresets, id: \.0) { name, hex in
                let isActive = selectedSlotAppearance.backgroundColor == hex
                Button {
                  updateSelectedSlotAppearance { appearance in
                    appearance.backgroundColor = hex
                  }
                } label: {
                  swatchTile(name: name, isActive: isActive) {
                    RoundedRectangle(cornerRadius: 10)
                      .fill(Color(hex: hex))
                      .aspectRatio(1, contentMode: .fit)
                  }
                }
                .buttonStyle(.plain)
              }

              swatchTile(name: "Custom", isActive: false) {
                customColorSwatch(selection: overlayColorBinding)
              }
            }
            .padding(.top, 8)
            .frame(maxWidth: swatchRowMaxWidth)
            .frame(maxWidth: .infinity)

            Divider().padding(.vertical, 8)

            FieldLabel(text: "Text Color")
            LazyVGrid(
              columns: Array(repeating: GridItem(.flexible(), spacing: swatchSpacing), count: 5),
              spacing: swatchSpacing
            ) {
              ForEach(textColorPresets, id: \.0) { name, hex in
                let isActive = selectedSlotAppearance.textColor == hex
                Button {
                  updateSelectedSlotAppearance { appearance in
                    appearance.textColor = hex
                  }
                } label: {
                  swatchTile(name: name, isActive: isActive) {
                    RoundedRectangle(cornerRadius: 10)
                      .fill(Color(hex: hex))
                      .aspectRatio(1, contentMode: .fit)
                      .overlay(
                        RoundedRectangle(cornerRadius: 10)
                          .stroke(Color("colorText").opacity(0.15), lineWidth: 1)
                      )
                  }
                }
                .buttonStyle(.plain)
              }

              swatchTile(name: "Custom", isActive: false) {
                customColorSwatch(selection: overlayTextColorBinding)
              }
            }
            .padding(.top, 8)
            .frame(maxWidth: swatchRowMaxWidth)
            .frame(maxWidth: .infinity)
          }

          SettingsPanel {
            SectionTitle(text: "Overlay Feel")
            VStack(spacing: 16) {
              sliderRow(
                "Opacity",
                "\(Int(selectedSlotAppearance.opacity * 100))%",
                opacityBinding,
                0.2...1.0
              )
              sliderRow(
                "Font Size",
                "\(Int(selectedSlotAppearance.fontSize))pt",
                fontSizeBinding,
                OverlayFontSizeConfiguration.minimum...OverlayFontSizeConfiguration.maximum
              )
              FrostedGlassToggleRow(
                title: "Frosted Glass",
                isOn: $appState.settings.pillFrostedGlassEnabled
              )

              HStack {
                Spacer()
                Button {
                  clearSelectedSlotOverride()
                } label: {
                  Text(selectedSlotIsInherited ? "Using Notch Defaults" : "Use Notch Defaults")
                    .settingsFont(.body, size: 16)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                      selectedSlotIsInherited
                        ? Color("colorText").opacity(0.35)
                        : managerTheme.primaryAccent(for: colorScheme)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .settingsPointingHandCursor()
                .disabled(selectedSlotIsInherited)
              }
            }
            .padding(.top, 14)
          }

          SettingsPanel {
            SectionTitle(text: "Overlay Font")
            Text("Choose a typeface for this Pill Window slot without affecting The Notch.")
              .settingsFont(.body, size: 14)
              .foregroundStyle(Color("colorText").opacity(0.6))
              .padding(.top, 2)
            SystemFontPicker(selectedFont: fontNameBinding)
              .padding(.top, 10)
          }

          SettingsPanel {
            SectionTitle(text: "Accessibility")
            Text(
              "These readability controls apply only to the selected Pill Window slot once you customize it."
            )
            .settingsFont(.body, size: 14)
            .foregroundStyle(Color("colorText").opacity(0.6))
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 16) {
              VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "Text Alignment")
                HStack(spacing: 8) {
                  alignmentOptionButton(.left, label: "Left")
                  alignmentOptionButton(.center, label: "Center")
                  alignmentOptionButton(.justified, label: "Justified")
                }
              }

              readabilitySlider(
                label: "Line Spacing",
                valueText: "\(Int(lineSpacingBinding.wrappedValue.rounded()))pt",
                value: lineSpacingBinding,
                range: OverlayLineSpacingConfiguration
                  .minimum...OverlayLineSpacingConfiguration.maximum,
                step: 1,
                minimumText: "\(Int(OverlayLineSpacingConfiguration.minimum))pt",
                maximumText: "\(Int(OverlayLineSpacingConfiguration.maximum))pt"
              )

              readabilitySlider(
                label: "Letter Spacing",
                valueText: String(format: "%.1fpt", letterSpacingBinding.wrappedValue),
                value: letterSpacingBinding,
                range: OverlayLetterSpacingConfiguration
                  .minimum...OverlayLetterSpacingConfiguration.maximum,
                step: 0.1,
                minimumText: String(format: "%.1fpt", OverlayLetterSpacingConfiguration.minimum),
                maximumText: String(format: "%.1fpt", OverlayLetterSpacingConfiguration.maximum)
              )

              readabilitySlider(
                label: "Word Spacing",
                valueText: String(format: "%.1fpt", wordSpacingBinding.wrappedValue),
                value: wordSpacingBinding,
                range: OverlayWordSpacingConfiguration
                  .minimum...OverlayWordSpacingConfiguration.maximum,
                step: 0.5,
                minimumText: "\(Int(OverlayWordSpacingConfiguration.minimum))pt",
                maximumText: "\(Int(OverlayWordSpacingConfiguration.maximum))pt"
              )

              readabilitySlider(
                label: "Text Shadow",
                valueText: String(format: "%.1f", textShadowBinding.wrappedValue),
                value: textShadowBinding,
                range: OverlayTextShadowConfiguration
                  .minimum...OverlayTextShadowConfiguration.maximum,
                step: 0.5,
                minimumText: "Off",
                maximumText: String(format: "%.1f", OverlayTextShadowConfiguration.maximum)
              )

              readabilitySlider(
                label: "Text Padding",
                valueText: "\(Int(contentPaddingBinding.wrappedValue.rounded()))pt",
                value: contentPaddingBinding,
                range: OverlayContentPaddingConfiguration
                  .minimum...OverlayContentPaddingConfiguration.maximum,
                step: 1,
                minimumText: "\(Int(OverlayContentPaddingConfiguration.minimum))pt",
                maximumText: "\(Int(OverlayContentPaddingConfiguration.maximum))pt"
              )
            }
            .padding(.top, 12)
          }
        }
        .padding(.bottom, 4)
      }
      .scrollIndicators(.never)
    }
  }

  private var satellitePreviewPanel: some View {
    SettingsPanel {
      SectionTitle(text: "Preview")

      ZStack {
        Color(hex: "#434343")

        ZStack {
          if appState.settings.pillFrostedGlassEnabled {
            OverlayFrostedGlassBackground(appearance: selectedSlotAppearance)
          } else {
            Color(hex: selectedSlotAppearance.backgroundColor)
              .opacity(selectedSlotAppearance.opacity)
          }
          OverlayAppearancePreviewText(
            text: previewSampleText,
            appearance: selectedSlotAppearance,
            width: 420,
            topPadding: 20
          )
        }
        .frame(width: 420, height: 144)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 196)
      .clipShape(RoundedRectangle(cornerRadius: 24))
      .padding(.top, 8)
    }
  }

  @ViewBuilder
  private func satelliteCountButton(count: Int) -> some View {
    let isActive = appState.settings.maxPillCount == count

    Button {
      appState.settings.maxPillCount = count
    } label: {
      Text("\(count)")
        .settingsFont(.body, size: 16)
        .foregroundStyle(isActive ? Color.white : Color("colorText").opacity(0.7))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
          isActive
            ? managerTheme.primaryAccent(for: colorScheme)
            : managerTheme.controlFill(for: colorScheme)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color("colorText").opacity(0.12), lineWidth: isActive ? 2 : 1.5)
        )
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func satelliteSlotButton(slot: Int) -> some View {
    let isActive = selectedSatelliteSlot == slot
    let usesOverride = appState.settings.satelliteAppearanceOverride(forSlot: slot) != nil

    Button {
      selectedSatelliteSlot = slot
    } label: {
      HStack(spacing: 8) {
        Text("Pill Window \(slot)")
          .settingsFont(.body, size: 16)
        Spacer()
        Text(usesOverride ? "Custom" : "Inherit")
          .settingsFont(.compact, size: 11)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            usesOverride
              ? managerTheme.secondaryAccent(for: colorScheme).opacity(isActive ? 0.28 : 0.14)
              : managerTheme.primaryAccent(for: colorScheme).opacity(isActive ? 0.28 : 0.14)
          )
          .clipShape(Capsule())
      }
      .foregroundStyle(isActive ? Color.white : Color("colorText"))
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity)
      .background(
        isActive
          ? managerTheme.primaryAccent(for: colorScheme)
          : managerTheme.controlFill(for: colorScheme)
      )
      .clipShape(RoundedRectangle(cornerRadius: 14))
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(Color("colorText").opacity(isActive ? 0.08 : 0.12), lineWidth: isActive ? 2 : 1.5)
      )
    }
    .buttonStyle(.plain)
  }

  private func clearSelectedSlotOverride() {
    appState.settings.setSatelliteAppearanceOverride(nil, forSlot: selectedSatelliteSlot)
  }

  private func updateSelectedSlotAppearance(_ mutate: (inout OverlayAppearance) -> Void) {
    var appearance = selectedSlotAppearance
    mutate(&appearance)
    appState.settings.setSatelliteAppearanceOverride(appearance, forSlot: selectedSatelliteSlot)
  }

  private func appearanceMetricBinding(
    getValue: @escaping (OverlayAppearance) -> CGFloat,
    clamp: @escaping @MainActor (CGFloat) -> CGFloat,
    setValue: @escaping (inout OverlayAppearance, CGFloat) -> Void
  ) -> Binding<CGFloat> {
    Binding(
      get: {
        clamp(getValue(selectedSlotAppearance))
      },
      set: { newValue in
        updateSelectedSlotAppearance { appearance in
          setValue(&appearance, clamp(newValue))
        }
      }
    )
  }

  private func sliderRow(
    _ label: String, _ valueText: String,
    _ value: Binding<Double>, _ range: ClosedRange<Double>
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(label).settingsFont(.display, size: 22).foregroundStyle(Color("colorText"))
        Spacer()
        Text(valueText).settingsFont(.display, size: 20).foregroundStyle(
          managerTheme.primaryAccent(for: colorScheme))
      }
      Slider(value: value, in: range).tint(managerTheme.primaryAccent(for: colorScheme))
    }
  }

  private func sliderRow(
    _ label: String, _ valueText: String,
    _ value: Binding<CGFloat>, _ range: ClosedRange<CGFloat>
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(label).settingsFont(.display, size: 22).foregroundStyle(Color("colorText"))
        Spacer()
        Text(valueText).settingsFont(.display, size: 20).foregroundStyle(
          managerTheme.primaryAccent(for: colorScheme))
      }
      Slider(value: value, in: range).tint(managerTheme.primaryAccent(for: colorScheme))
    }
  }

  private func swatchTile<Swatch: View>(
    name: String,
    isActive: Bool,
    @ViewBuilder swatch: () -> Swatch
  ) -> some View {
    VStack(spacing: 6) {
      swatch()
      Text(name)
        .settingsFont(.display, size: 12)
        .foregroundStyle(Color("colorText"))
        .lineLimit(1)
    }
    .padding(8)
    .frame(maxWidth: .infinity)
    .background(
      isActive
        ? managerTheme.primaryAccent(for: colorScheme).opacity(0.12)
        : managerTheme.controlFill(for: colorScheme).opacity(0.7)
    )
    .clipShape(RoundedRectangle(cornerRadius: 13))
    .overlay(
      RoundedRectangle(cornerRadius: 13)
        .stroke(
          isActive ? managerTheme.primaryAccent(for: colorScheme) : Color("colorText").opacity(0.1),
          lineWidth: isActive ? 2.5 : 1.5
        )
    )
  }

  private func customColorSwatch(selection: Binding<Color>) -> some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(hex: "#D98C7B"),
          Color(hex: "#D8B36A"),
          Color(hex: "#A8C28A"),
          Color(hex: "#7FAEB5"),
          Color(hex: "#A890C8"),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .saturation(0.72)
      .brightness(0.03)
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .fill(Color.white.opacity(0.18))
          .blur(radius: 10)
          .padding(8)
      )

      SettingsColorPanelButtonBridge(selection: selection)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .aspectRatio(1, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .contentShape(RoundedRectangle(cornerRadius: 10))
    .settingsPointingHandCursor()
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color("colorText").opacity(0.12), lineWidth: 1)
    )
  }

  @ViewBuilder
  private func alignmentOptionButton(_ alignment: OverlayTextAlignment, label: String) -> some View
  {
    let isSelected = selectedSlotAppearance.textAlignment == alignment

    Button {
      updateSelectedSlotAppearance { appearance in
        appearance.textAlignment = alignment
      }
    } label: {
      Text(label)
        .settingsFont(.body, size: 17)
        .foregroundStyle(isSelected ? Color.white : Color("colorText"))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
          isSelected
            ? managerTheme.primaryAccent(for: colorScheme)
            : managerTheme.controlFill(for: colorScheme)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(
              isSelected
                ? managerTheme.primaryAccent(for: colorScheme) : Color("colorText").opacity(0.14),
              lineWidth: isSelected ? 2.5 : 1.5
            )
        )
    }
    .buttonStyle(.plain)
  }

  private func readabilitySlider(
    label: String,
    valueText: String,
    value: Binding<CGFloat>,
    range: ClosedRange<CGFloat>,
    step: CGFloat,
    minimumText: String,
    maximumText: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        FieldLabel(text: label)
        Spacer()
        Text(valueText)
          .settingsFont(.body, size: 16)
          .foregroundStyle(managerTheme.primaryAccent(for: colorScheme))
      }

      Slider(
        value: value,
        in: range,
        step: step
      )
      .tint(managerTheme.primaryAccent(for: colorScheme))

      HStack {
        Text(minimumText)
        Spacer()
        Text(maximumText)
      }
      .settingsFont(.body, size: 14)
      .foregroundStyle(Color("colorText").opacity(0.55))
    }
  }
}

// MARK: - Notch Wrap Shape

/// Translates the clip-path from NotchPreview.tsx exactly.
/// Source coordinate space: 250 × 110
/// Notch cutout: x 65→185 (120 wide), y 0→30 (30 deep), centred at x=125
/// Outer corners: 5pt radius top, 10pt radius bottom
private struct NotchWrapShape: Shape {
  let hasNotch: Bool
  let notchSize: CGSize

  func path(in rect: CGRect) -> Path {
    guard hasNotch else {
      return NotchOverlayGeometry.fallbackPath(in: rect)
    }

    let topRadius = min(10, rect.height * 0.09)
    let bottomRadius = min(14, rect.height * 0.13)
    let cutoutWidth = min(notchSize.width, rect.width - (topRadius * 4))
    let cutoutDepth = min(notchSize.height, rect.height - (bottomRadius * 2) - 8)
    let innerRadius = min(12, cutoutDepth * 0.55)
    let leftCutoutEdge = rect.midX - cutoutWidth / 2
    let rightCutoutEdge = rect.midX + cutoutWidth / 2
    let top = rect.minY
    let bottom = rect.maxY
    let left = rect.minX
    let right = rect.maxX

    var p = Path()
    p.move(to: CGPoint(x: left + topRadius, y: top))
    p.addLine(to: CGPoint(x: leftCutoutEdge - innerRadius, y: top))
    p.addQuadCurve(
      to: CGPoint(x: leftCutoutEdge, y: top + innerRadius),
      control: CGPoint(x: leftCutoutEdge, y: top)
    )
    p.addLine(to: CGPoint(x: leftCutoutEdge, y: top + cutoutDepth - innerRadius))
    p.addQuadCurve(
      to: CGPoint(x: leftCutoutEdge + innerRadius, y: top + cutoutDepth),
      control: CGPoint(x: leftCutoutEdge, y: top + cutoutDepth)
    )
    p.addLine(to: CGPoint(x: rightCutoutEdge - innerRadius, y: top + cutoutDepth))
    p.addQuadCurve(
      to: CGPoint(x: rightCutoutEdge, y: top + cutoutDepth - innerRadius),
      control: CGPoint(x: rightCutoutEdge, y: top + cutoutDepth)
    )
    p.addLine(to: CGPoint(x: rightCutoutEdge, y: top + innerRadius))
    p.addQuadCurve(
      to: CGPoint(x: rightCutoutEdge + innerRadius, y: top),
      control: CGPoint(x: rightCutoutEdge, y: top)
    )
    p.addLine(to: CGPoint(x: right - topRadius, y: top))
    p.addQuadCurve(
      to: CGPoint(x: right, y: top + topRadius),
      control: CGPoint(x: right, y: top)
    )
    p.addLine(to: CGPoint(x: right, y: bottom - bottomRadius))
    p.addQuadCurve(
      to: CGPoint(x: right - bottomRadius, y: bottom),
      control: CGPoint(x: right, y: bottom)
    )
    p.addLine(to: CGPoint(x: left + bottomRadius, y: bottom))
    p.addQuadCurve(
      to: CGPoint(x: left, y: bottom - bottomRadius),
      control: CGPoint(x: left, y: bottom)
    )
    p.addLine(to: CGPoint(x: left, y: top + topRadius))
    p.addQuadCurve(
      to: CGPoint(x: left + topRadius, y: top),
      control: CGPoint(x: left, y: top)
    )
    p.closeSubpath()
    return p
  }
}

// MARK: - Shortcuts Tab

private struct ShortcutsTabContent: View {
  @EnvironmentObject var appState: AppState

  var body: some View {
    VStack(spacing: 16) {
      SettingsPanel {
        SectionTitle(text: "Keyboard Shortcuts")
        Text("Record the keys Aira listens for while launching or controlling a live session.")
          .settingsFont(.body, size: 14)
          .foregroundStyle(Color("colorText").opacity(0.62))
          .padding(.top, 2)

        VStack(spacing: 8) {
          shortcutRow("Toggle Notch", $appState.settings.shortcutToggleNotch)
          shortcutRow("Toggle Pill Window", $appState.settings.shortcutTogglePill)
          shortcutRow("Space to Pause", $appState.settings.shortcutToggleVoiceSync)
          shortcutRow("Scroll Up", $appState.settings.shortcutScrollUp)
          shortcutRow("Scroll Down", $appState.settings.shortcutScrollDown)
          shortcutRow("End Session", $appState.settings.shortcutEndSession)
        }
        .padding(.top, 12)
      }
    }
  }

  private func shortcutRow(_ label: String, _ key: Binding<String>) -> some View {
    HStack(alignment: .center) {
      Text(label)
        .settingsFont(.body, size: 18)
        .foregroundStyle(Color("colorText"))
      Spacer()
      ShortcutKeyCapsField(shortcut: key)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

// MARK: - System Tab

private struct SystemTabContent: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  private var countdownDurationBinding: Binding<Int> {
    Binding(
      get: { appState.settings.countdownDuration },
      set: { appState.settings.countdownDuration = min(max($0, 0), 10) }
    )
  }

  private var autoScrollSpeedSliderBinding: Binding<Double> {
    Binding(
      get: { ManualScrollConfiguration.clampedWPM(appState.settings.autoScrollWPM) },
      set: { appState.settings.autoScrollWPM = ManualScrollConfiguration.clampedWPM($0) }
    )
  }

  private var countdownSummary: String {
    let duration = appState.settings.countdownDuration
    if duration == 0 {
      return "Off"
    }

    if duration == 1 {
      return "1 second"
    }

    return "\(duration) seconds"
  }

  private func systemFieldLabel(_ text: String) -> some View {
    Text(text)
      .settingsFont(.body, size: 14)
      .foregroundStyle(Color("colorText").opacity(0.66))
  }

  @ViewBuilder
  private func voiceScrollModeButton(_ mode: VoiceScrollMode) -> some View {
    let isActive = appState.settings.voiceScrollMode == mode

    Button {
      appState.settings.voiceScrollMode = mode
    } label: {
      VStack(alignment: .leading, spacing: 5) {
        Text(mode.settingsTitle)
          .settingsFont(.body, size: 17)
          .foregroundStyle(isActive ? Color.white : Color("colorText"))
        Text(mode.settingsDescription)
          .settingsFont(.body, size: 13)
          .foregroundStyle(
            isActive
              ? Color.white.opacity(0.82)
              : Color("colorText").opacity(0.62)
          )
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(
        isActive
          ? managerTheme.primaryAccent(for: colorScheme)
          : managerTheme.controlFill(for: colorScheme).opacity(0.82)
      )
      .clipShape(RoundedRectangle(cornerRadius: 14))
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(
            isActive
              ? Color.white.opacity(colorScheme == .dark ? 0.42 : 0.58)
              : Color("colorText").opacity(0.14),
            lineWidth: isActive ? 2 : 1.5
          )
      )
      .contentShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
    .settingsPointingHandCursor()
  }

  var body: some View {
    VStack(spacing: 16) {
      SettingsPanel {
        SectionTitle(text: "Before your Session")
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Lead-in before scrolling begins")
                .settingsFont(.body, size: 18)
                .foregroundStyle(Color("colorText"))
              Text("Set to zero to start immediately when you cast to the notch.")
                .settingsFont(.body, size: 14)
                .foregroundStyle(Color("colorText").opacity(0.6))
            }
            Spacer()
            Text(countdownSummary)
              .settingsFont(.body, size: 18)
              .foregroundStyle(managerTheme.primaryAccent(for: colorScheme))
          }

          HStack(spacing: 12) {
            countdownStepButton(systemName: "minus") {
              countdownDurationBinding.wrappedValue -= 1
            }
            .disabled(countdownDurationBinding.wrappedValue == 0)

            TextField(
              "Seconds",
              value: countdownDurationBinding,
              formatter: countdownFormatter
            )
            .textFieldStyle(.plain)
            .settingsFont(.body, size: 20)
            .foregroundStyle(Color("colorText"))
            .multilineTextAlignment(.center)
            .frame(width: 88, height: 66)
            .background(managerTheme.controlFill(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
              RoundedRectangle(cornerRadius: 14)
                .stroke(Color("colorText").opacity(0.12), lineWidth: 1.5)
            )

            countdownStepButton(systemName: "plus") {
              countdownDurationBinding.wrappedValue += 1
            }
            .disabled(countdownDurationBinding.wrappedValue == 10)

            Text("seconds")
              .settingsFont(.body, size: 16)
              .foregroundStyle(Color("colorText").opacity(0.62))
          }
          Divider().opacity(0.2).padding(.vertical, 2)

          VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
              VStack(alignment: .leading, spacing: 4) {
                Text("Scroll speed (pt/s)")
                  .settingsFont(.body, size: 18)
                  .foregroundStyle(Color("colorText"))
                Text(
                  "Sets the manual reading pace before you begin and still drives Manual mode when Voice-Sync is off."
                )
                .settingsFont(.body, size: 14)
                .foregroundStyle(Color("colorText").opacity(0.6))
              }
              Spacer()
              Text("\(Int(autoScrollSpeedSliderBinding.wrappedValue.rounded())) pt/s")
                .settingsFont(.body, size: 18)
                .foregroundStyle(managerTheme.primaryAccent(for: colorScheme))
            }

            Slider(
              value: autoScrollSpeedSliderBinding,
              in: ManualScrollConfiguration.minimumWPM...ManualScrollConfiguration.maximumWPM,
              step: 1
            )
            .tint(managerTheme.primaryAccent(for: colorScheme))

            HStack {
              Text("\(Int(ManualScrollConfiguration.minimumWPM)) pt/s")
              Spacer()
              Text("\(Int(ManualScrollConfiguration.maximumWPM)) pt/s")
            }
            .settingsFont(.body, size: 14)
            .foregroundStyle(Color("colorText").opacity(0.55))
          }
        }
        .padding(.top, 14)
      }

      SettingsPanel {
        SectionTitle(text: "During your Session")
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 14) {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("Voice scroll mode")
                  .settingsFont(.body, size: 18)
                  .foregroundStyle(Color("colorText"))
                Text(
                  "Choose manual-speed scrolling, sound-triggered movement, or word-by-word tracking."
                )
                .settingsFont(.body, size: 14)
                .foregroundStyle(Color("colorText").opacity(0.6))
              }
              Spacer()
            }

            VStack(spacing: 8) {
              ForEach(VoiceScrollMode.allCases, id: \.self) { mode in
                voiceScrollModeButton(mode)
              }
            }
          }

          // Sensitivity affects microphone-driven scroll modes.
          VStack(alignment: .leading, spacing: 10) {
            let usesSpeechSensitivity = appState.settings.voiceScrollMode.usesSpeechSensitivity
            systemFieldLabel("Mic Sensitivity")
            HStack(spacing: 8) {
              ForEach(SpeechSensitivity.allCases, id: \.self) { level in
                let isActive = appState.settings.speechSensitivity == level
                Button {
                  appState.settings.speechSensitivity = level
                } label: {
                  Text(level.rawValue.capitalized)
                    .settingsFont(.body, size: 17)
                    .foregroundStyle(
                      Color("colorText")
                        .opacity(usesSpeechSensitivity ? 1 : 0.35)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                      isActive && usesSpeechSensitivity
                        ? managerTheme.primaryAccent(for: colorScheme).opacity(0.24)
                        : managerTheme.controlFill(for: colorScheme).opacity(0.75)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                      RoundedRectangle(cornerRadius: 12)
                        .stroke(
                          isActive && usesSpeechSensitivity
                            ? managerTheme.primaryAccent(for: colorScheme)
                            : Color("colorText").opacity(0.14),
                          lineWidth: isActive && usesSpeechSensitivity ? 3 : 2
                        ))
                }
                .buttonStyle(.plain)
                .disabled(!usesSpeechSensitivity)
              }
            }
            Text(
              "Applies to Sound-based and Word tracking modes. Classic uses the manual scroll speed."
            )
            .settingsFont(.body, size: 14)
            .foregroundStyle(
              Color("colorText")
                .opacity(usesSpeechSensitivity ? 0.64 : 0.3))
          }
          .opacity(appState.settings.voiceScrollMode.usesSpeechSensitivity ? 1 : 0.5)
          .animation(.easeInOut(duration: 0.2), value: appState.settings.voiceScrollMode)

          Divider().opacity(0.2)

          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Spoken-word highlighting")
                .settingsFont(.body, size: 18)
                .foregroundStyle(Color("colorText"))
              Text(
                "Visual only. Dims spoken words and marks current word without changing scroll behavior."
              )
              .settingsFont(.body, size: 14)
              .foregroundStyle(Color("colorText").opacity(0.6))
            }
            Spacer()
            Toggle("", isOn: $appState.settings.spokenWordHighlightingEnabled)
              .toggleStyle(.switch)
              .tint(managerTheme.primaryAccent(for: colorScheme))
              .labelsHidden()
          }

          Divider().opacity(0.2)

          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Show script progress")
                .settingsFont(.body, size: 18)
                .foregroundStyle(Color("colorText"))
              Text(
                "Adds a thin progress line at the bottom edge of active notch and pill overlays."
              )
              .settingsFont(.body, size: 14)
              .foregroundStyle(Color("colorText").opacity(0.6))
            }
            Spacer()
            Toggle("", isOn: $appState.settings.showScriptProgress)
              .toggleStyle(.switch)
              .tint(managerTheme.primaryAccent(for: colorScheme))
              .labelsHidden()
          }

          Divider().opacity(0.2)

          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Pause on mouse hover")
                .settingsFont(.body, size: 18)
                .foregroundStyle(Color("colorText"))
              Text(
                "Pauses notch scrolling while pointer stays over overlay. Pill windows ignore this setting."
              )
              .settingsFont(.body, size: 14)
              .foregroundStyle(Color("colorText").opacity(0.6))
            }
            Spacer()
            Toggle("", isOn: $appState.settings.pauseOnHoverEnabled)
              .toggleStyle(.switch)
              .tint(managerTheme.primaryAccent(for: colorScheme))
              .labelsHidden()
          }
        }
        .padding(.top, 14)
      }

      SettingsPanel {
        SectionTitle(text: "Privacy")
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Hide overlays from screen sharing")
                .settingsFont(.body, size: 18)
                .foregroundStyle(Color("colorText"))
              Text(
                "Turn this off if you want notch or Pill Window overlay to appear in screenshots, recordings, or video calls."
              )
              .settingsFont(.body, size: 14)
              .foregroundStyle(Color("colorText").opacity(0.6))
            }
            Spacer()
            Toggle("", isOn: $appState.settings.screenCaptureExclusionEnabled)
              .toggleStyle(.switch)
              .tint(managerTheme.primaryAccent(for: colorScheme))
              .labelsHidden()
          }

          Text(
            appState.settings.screenCaptureExclusionEnabled
              ? "On by default. Aira asks macOS to exclude overlay windows from capture streams."
              : "Off. Overlay windows remain visible to screen capture apps by choice, so stealth warnings stay suppressed."
          )
          .settingsFont(.body, size: 14)
          .foregroundStyle(Color("colorText").opacity(0.62))
        }
        .padding(.top, 14)
      }
    }
  }

  private func countdownStepButton(systemName: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(Color("colorText"))
        .frame(width: 34, height: 34)
        .background(managerTheme.controlFill(for: colorScheme).opacity(0.82))
        .clipShape(Circle())
        .overlay(
          Circle()
            .stroke(Color("colorText").opacity(0.12), lineWidth: 1.5)
        )
    }
    .buttonStyle(.plain)
  }

  private var countdownFormatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .none
    formatter.minimum = 0
    formatter.maximum = 10
    return formatter
  }
}
