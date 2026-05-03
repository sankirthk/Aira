import AppKit
import SwiftUI

// MARK: - Tab

private enum SettingsTab: CaseIterable, Hashable {
  case appearance, notch, satellite, system

  var label: String {
    switch self {
    case .appearance: return "Appearance"
    case .notch: return "The Notch"
    case .satellite: return "Pill Windows"
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

  private var topChromeColor: Color {
    appState.settings.appearanceMode == .dark
      ? Color(hex: "#484C49")
      : Color("colorBackground")
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
      .modifier(SettingsChromeModifier(isStandaloneWindow: availableSize == nil))
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
        .font(.custom("IndieFlower", size: 30))
        .foregroundStyle(Color("colorText"))
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 24)
    .padding(.top, 20)
    .padding(.bottom, 18)
    .background(topChromeColor)
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
          .font(.custom("IndieFlower", size: 23))
          .foregroundStyle(
            appState.settings.appearanceMode == .dark
              ? Color.white
              : (isActive ? Color.white : Color("colorText").opacity(0.82))
          )
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 14)
      .background(isActive ? Color("colorPrimary") : Color.clear)
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
      .background(topChromeColor)

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
        case .system:
          settingsScrollContainer {
            SystemTabContent()
          }
        }
      }
      .background(Color("colorBackground"))
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

  func body(content: Content) -> some View {
    if isStandaloneWindow {
      content
        .background(Color("colorBackground"))
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

// MARK: - Shared Helpers

private struct SettingsPanel<Content: View>: View {
  @ViewBuilder let content: () -> Content
  var body: some View {
    VStack(alignment: .leading, spacing: 0) { content() }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(20)
      .background(Color("colorSurface").opacity(0.82))
      .clipShape(RoundedRectangle(cornerRadius: 20))
      .overlay(
        RoundedRectangle(cornerRadius: 20)
          .stroke(Color("colorText").opacity(0.1), lineWidth: 2))
  }
}

private struct SectionTitle: View {
  let text: String
  var body: some View {
    Text(text)
      .font(.custom("IndieFlower", size: 28))
      .foregroundStyle(Color("colorText"))
  }
}

private struct FieldLabel: View {
  let text: String
  var body: some View {
    Text(text)
      .font(.custom("IndieFlower", size: 14))
      .foregroundStyle(Color("colorText").opacity(0.66))
  }
}

// MARK: - Shortcut keycap display + recorder

/// Displays a keyboard shortcut as styled keycaps.
/// Tap to enter recording mode; press the new combo to save; press Escape or click away to cancel.
private struct ShortcutKeyCapsField: View {
  @Binding var shortcut: String
  @State private var isRecording = false
  @State private var keyMonitor: Any?

  var body: some View {
    Group {
      if isRecording {
        Text("Type shortcut…")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(Color("colorPrimary"))
          .padding(.horizontal, 14)
          .padding(.vertical, 9)
          .background(Color("colorBackground"))
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color("colorPrimary"), lineWidth: 2))
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
        .background(Color("colorBackground"))
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
                  VStack(alignment: .leading, spacing: 2) {
                    Text(family)
                      .font(.custom(family, size: 15))
                      .foregroundStyle(Color("colorText"))
                      .lineLimit(1)
                    Text("The quick brown fox")
                      .font(.custom(family, size: 12))
                      .foregroundStyle(Color("colorText").opacity(0.55))
                      .lineLimit(1)
                  }
                  Spacer()
                  if selectedFont == family {
                    Image(systemName: "checkmark")
                      .font(.system(size: 12, weight: .semibold))
                      .foregroundStyle(Color("colorPrimary"))
                  }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color("colorBackground").opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                  RoundedRectangle(cornerRadius: 12)
                    .stroke(
                      selectedFont == family
                        ? Color("colorPrimary") : Color("colorText").opacity(0.08),
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
        .background(Color("colorSurface").opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(Color("colorText").opacity(0.1), lineWidth: 1)
        )
      }

      HStack {
        Text("Preview")
          .font(.custom("CrimsonText-Regular", size: 14))
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

  private let sizes: [(String, ManagerTypography)] = [
    ("Small", .small), ("Medium", .medium), ("Large", .large),
  ]

  var body: some View {
    VStack(spacing: 16) {

      // App Theme
      SettingsPanel {
        SectionTitle(text: "App Theme")
        Text("Pick the room tone the control hub opens with.")
          .font(.custom("CrimsonText-Regular", size: 16))
          .foregroundStyle(Color("colorText").opacity(0.68))
          .padding(.top, 4)

        HStack(spacing: 14) {
          themeCard(
            "Light Paper",
            "Warm cream workspace with charcoal ink and sage accents.",
            Color(hex: "#F5F2EC"), .light)
          themeCard(
            "Dark Studio",
            "Low-light rehearsal mode with paper ink flipped to cream.",
            Color(hex: "#2B2B2B"), .dark)
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
              .font(.custom("CrimsonText-Regular", size: 14))
              .foregroundStyle(Color("colorText").opacity(0.66))
            HStack(spacing: 8) {
              ForEach(sizes, id: \.0) { label, size in
                let isActive = appState.settings.managerTypography == size
                Button {
                  appState.settings.managerTypography = size
                } label: {
                  Text(label)
                    .font(.custom("CrimsonText-Regular", size: 18))
                    .foregroundStyle(Color("colorText"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                      isActive
                        ? Color("colorPrimary").opacity(0.1)
                        : Color("colorSurface").opacity(0.75)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                      RoundedRectangle(cornerRadius: 14)
                        .stroke(
                          isActive ? Color("colorPrimary") : Color("colorText").opacity(0.14),
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
          .font(.custom("IndieFlower", size: 24))
          .foregroundStyle(Color("colorText"))
          .padding(.top, 10)
        Text(tone)
          .font(.custom("CrimsonText-Regular", size: 14))
          .foregroundStyle(Color("colorText").opacity(0.64))
          .lineSpacing(2)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 4)
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        isActive ? Color("colorPrimary").opacity(0.1) : Color("colorSurface").opacity(0.82)
      )
      .clipShape(RoundedRectangle(cornerRadius: 18))
      .overlay(
        RoundedRectangle(cornerRadius: 18)
          .stroke(
            isActive ? Color("colorPrimary") : Color("colorText").opacity(0.16),
            lineWidth: isActive ? 3 : 2))
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Notch Tab

private struct NotchTabContent: View {
  @EnvironmentObject var appState: AppState
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
          Color(hex: appState.settings.defaultOverlayAppearance.backgroundColor)
            .opacity(appState.settings.defaultOverlayAppearance.opacity)
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

          HStack {
            Spacer()
            Button {
              resetOverlayFeelToDefaults()
            } label: {
              Text("Reset to Defaults")
                .font(.custom("CrimsonText-Regular", size: 16))
                .foregroundStyle(Color("colorBackground"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color("colorPrimary"))
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
          .font(.custom("CrimsonText-Regular", size: 14))
          .foregroundStyle(Color("colorText").opacity(0.6))
          .padding(.top, 2)
        SystemFontPicker(selectedFont: $appState.settings.defaultOverlayAppearance.fontName)
          .padding(.top, 10)
      }

      SettingsPanel {
        SectionTitle(text: "Accessibility")
        Text("Use layout-focused readability controls here without duplicating font choice.")
          .font(.custom("CrimsonText-Regular", size: 14))
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
        Text(label).font(.custom("IndieFlower", size: 22)).foregroundStyle(Color("colorText"))
        Spacer()
        Text(valueText).font(.custom("IndieFlower", size: 20)).foregroundStyle(
          Color("colorPrimary"))
      }
      Slider(value: value, in: range).tint(Color("colorPrimary"))
    }
  }

  private func sliderRow(
    _ label: String, _ valueText: String,
    _ value: Binding<CGFloat>, _ range: ClosedRange<CGFloat>
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(label).font(.custom("IndieFlower", size: 22)).foregroundStyle(Color("colorText"))
        Spacer()
        Text(valueText).font(.custom("IndieFlower", size: 20)).foregroundStyle(
          Color("colorPrimary"))
      }
      Slider(value: value, in: range).tint(Color("colorPrimary"))
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
        .font(.custom("IndieFlower", size: 12))
        .foregroundStyle(Color("colorText"))
        .lineLimit(1)
    }
    .padding(8)
    .frame(maxWidth: .infinity)
    .background(
      isActive
        ? Color("colorPrimary").opacity(0.12)
        : Color("colorBackground").opacity(0.7)
    )
    .clipShape(RoundedRectangle(cornerRadius: 13))
    .overlay(
      RoundedRectangle(cornerRadius: 13)
        .stroke(
          isActive ? Color("colorPrimary") : Color("colorText").opacity(0.1),
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
        .font(.custom("CrimsonText-Regular", size: 17))
        .foregroundStyle(isSelected ? Color("colorBackground") : Color("colorText"))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(isSelected ? Color("colorPrimary") : Color("colorBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(
              isSelected ? Color("colorPrimary") : Color("colorText").opacity(0.14),
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
          .font(.custom("CrimsonText-Regular", size: 16))
          .foregroundStyle(Color("colorPrimary"))
      }

      Slider(
        value: value,
        in: range,
        step: step
      )
      .tint(Color("colorPrimary"))

      HStack {
        Text(minimumText)
        Spacer()
        Text(maximumText)
      }
      .font(.custom("CrimsonText-Regular", size: 14))
      .foregroundStyle(Color("colorText").opacity(0.55))
    }
  }

}

// MARK: - Pill Windows Tab

private struct SatelliteTabContent: View {
  @EnvironmentObject var appState: AppState
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
      SettingsPanel {
        SectionTitle(text: "Pill Windows")
        Text(
          "Choose how many free-moving Pill Windows are available. Content is chosen when launching from the Script Editor."
        )
        .font(.custom("CrimsonText-Regular", size: 14))
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
            .font(.custom("CrimsonText-Regular", size: 14))
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
            .font(.custom("CrimsonText-Regular", size: 14))
            .foregroundStyle(Color("colorText").opacity(0.62))
          }
        }
        .padding(.top, 12)
      }

      satellitePreviewPanel

      ScrollView {
        VStack(spacing: 16) {
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

              HStack {
                Spacer()
                Button {
                  clearSelectedSlotOverride()
                } label: {
                  Text(selectedSlotIsInherited ? "Using Notch Defaults" : "Use Notch Defaults")
                    .font(.custom("CrimsonText-Regular", size: 16))
                    .foregroundStyle(Color("colorBackground"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                      selectedSlotIsInherited
                        ? Color("colorText").opacity(0.35)
                        : Color("colorPrimary")
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
              .font(.custom("CrimsonText-Regular", size: 14))
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
            .font(.custom("CrimsonText-Regular", size: 14))
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

        RoundedRectangle(cornerRadius: 24)
          .fill(
            Color(hex: selectedSlotAppearance.backgroundColor).opacity(
              selectedSlotAppearance.opacity)
          )
          .frame(width: 420, height: 144)
          .overlay(
            OverlayAppearancePreviewText(
              text: previewSampleText,
              appearance: selectedSlotAppearance,
              width: 420,
              topPadding: 20
            )
          )
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
        .font(.custom("CrimsonText-Regular", size: 16))
        .foregroundStyle(isActive ? Color("colorBackground") : Color("colorText").opacity(0.7))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(isActive ? Color("colorPrimary") : Color("colorBackground"))
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
          .font(.custom("CrimsonText-Regular", size: 16))
        Spacer()
        Text(usesOverride ? "Custom" : "Inherit")
          .font(.custom("Inter-Regular", size: 11))
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            usesOverride
              ? Color("colorSecondary").opacity(isActive ? 0.28 : 0.14)
              : Color("colorPrimary").opacity(isActive ? 0.28 : 0.14)
          )
          .clipShape(Capsule())
      }
      .foregroundStyle(isActive ? Color("colorBackground") : Color("colorText"))
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity)
      .background(isActive ? Color("colorPrimary") : Color("colorBackground"))
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
        Text(label).font(.custom("IndieFlower", size: 22)).foregroundStyle(Color("colorText"))
        Spacer()
        Text(valueText).font(.custom("IndieFlower", size: 20)).foregroundStyle(
          Color("colorPrimary"))
      }
      Slider(value: value, in: range).tint(Color("colorPrimary"))
    }
  }

  private func sliderRow(
    _ label: String, _ valueText: String,
    _ value: Binding<CGFloat>, _ range: ClosedRange<CGFloat>
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(label).font(.custom("IndieFlower", size: 22)).foregroundStyle(Color("colorText"))
        Spacer()
        Text(valueText).font(.custom("IndieFlower", size: 20)).foregroundStyle(
          Color("colorPrimary"))
      }
      Slider(value: value, in: range).tint(Color("colorPrimary"))
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
        .font(.custom("IndieFlower", size: 12))
        .foregroundStyle(Color("colorText"))
        .lineLimit(1)
    }
    .padding(8)
    .frame(maxWidth: .infinity)
    .background(
      isActive
        ? Color("colorPrimary").opacity(0.12)
        : Color("colorBackground").opacity(0.7)
    )
    .clipShape(RoundedRectangle(cornerRadius: 13))
    .overlay(
      RoundedRectangle(cornerRadius: 13)
        .stroke(
          isActive ? Color("colorPrimary") : Color("colorText").opacity(0.1),
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
        .font(.custom("CrimsonText-Regular", size: 17))
        .foregroundStyle(isSelected ? Color("colorBackground") : Color("colorText"))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(isSelected ? Color("colorPrimary") : Color("colorBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(
              isSelected ? Color("colorPrimary") : Color("colorText").opacity(0.14),
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
          .font(.custom("CrimsonText-Regular", size: 16))
          .foregroundStyle(Color("colorPrimary"))
      }

      Slider(
        value: value,
        in: range,
        step: step
      )
      .tint(Color("colorPrimary"))

      HStack {
        Text(minimumText)
        Spacer()
        Text(maximumText)
      }
      .font(.custom("CrimsonText-Regular", size: 14))
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

// MARK: - System Tab

private struct SystemTabContent: View {
  @EnvironmentObject var appState: AppState

  private var countdownDurationBinding: Binding<Int> {
    Binding(
      get: { appState.settings.countdownDuration },
      set: { appState.settings.countdownDuration = min(max($0, 0), 10) }
    )
  }

  private var autoScrollWPMSliderBinding: Binding<Double> {
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
      .font(.custom("CrimsonText-Regular", size: 14))
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
          .font(.custom("CrimsonText-Regular", size: 17))
          .foregroundStyle(
            Color("colorText")
              .opacity(appState.settings.voiceSyncEnabled ? 1 : 0.35)
          )
        Text(mode.settingsDescription)
          .font(.custom("CrimsonText-Regular", size: 13))
          .foregroundStyle(
            Color("colorText")
              .opacity(appState.settings.voiceSyncEnabled ? 0.62 : 0.28)
          )
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(
        isActive && appState.settings.voiceSyncEnabled
          ? Color("colorPrimary").opacity(0.1)
          : Color("colorBackground").opacity(0.75)
      )
      .clipShape(RoundedRectangle(cornerRadius: 14))
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(
            isActive && appState.settings.voiceSyncEnabled
              ? Color("colorPrimary")
              : Color("colorText").opacity(0.14),
            lineWidth: isActive && appState.settings.voiceSyncEnabled ? 3 : 2
          )
      )
      .contentShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
    .disabled(!appState.settings.voiceSyncEnabled)
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
                .font(.custom("CrimsonText-Regular", size: 18))
                .foregroundStyle(Color("colorText"))
              Text("Set to zero to start immediately when you cast to the notch.")
                .font(.custom("CrimsonText-Regular", size: 14))
                .foregroundStyle(Color("colorText").opacity(0.6))
            }
            Spacer()
            Text(countdownSummary)
              .font(.custom("CrimsonText-Regular", size: 18))
              .foregroundStyle(Color("colorPrimary"))
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
            .font(.custom("CrimsonText-Regular", size: 20))
            .foregroundStyle(Color("colorText"))
            .multilineTextAlignment(.center)
            .frame(width: 88, height: 66)
            .background(Color("colorBackground"))
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
              .font(.custom("CrimsonText-Regular", size: 16))
              .foregroundStyle(Color("colorText").opacity(0.62))
          }
          Divider().opacity(0.2).padding(.vertical, 2)

          VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
              VStack(alignment: .leading, spacing: 4) {
                Text("Scroll speed (pt/s)")
                  .font(.custom("CrimsonText-Regular", size: 18))
                  .foregroundStyle(Color("colorText"))
                Text(
                  "Sets the physical scroll speed before you begin and still drives Manual mode when Voice-Sync is off."
                )
                .font(.custom("CrimsonText-Regular", size: 14))
                .foregroundStyle(Color("colorText").opacity(0.6))
              }
              Spacer()
              Text("\(Int(autoScrollWPMSliderBinding.wrappedValue.rounded())) pt/s")
                .font(.custom("CrimsonText-Regular", size: 18))
                .foregroundStyle(Color("colorPrimary"))
            }

            Slider(
              value: autoScrollWPMSliderBinding,
              in: ManualScrollConfiguration.minimumWPM...ManualScrollConfiguration.maximumWPM,
              step: 1
            )
            .tint(Color("colorPrimary"))

            HStack {
              Text("\(Int(ManualScrollConfiguration.minimumWPM)) pt/s")
              Spacer()
              Text("\(Int(ManualScrollConfiguration.maximumWPM)) pt/s")
            }
            .font(.custom("CrimsonText-Regular", size: 14))
            .foregroundStyle(Color("colorText").opacity(0.55))
          }
        }
        .padding(.top, 14)
      }

      SettingsPanel {
        SectionTitle(text: "During your Session")
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text("Voice-activated tracking")
                .font(.custom("CrimsonText-Regular", size: 18))
                .foregroundStyle(Color("colorText"))
              Text("Moves only when human speech is recognized and keeps script anchored smoothly.")
                .font(.custom("CrimsonText-Regular", size: 14))
                .foregroundStyle(Color("colorText").opacity(0.6))
            }
            Spacer()
            Toggle("", isOn: $appState.settings.voiceSyncEnabled)
              .toggleStyle(.switch)
              .tint(Color("colorPrimary"))
              .labelsHidden()
          }

          VStack(alignment: .leading, spacing: 14) {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("Voice scroll mode")
                  .font(.custom("CrimsonText-Regular", size: 18))
                  .foregroundStyle(Color("colorText"))
                Text(
                  "Choose whether speech only highlights words, gates steady scrolling, or tracks the recognized word directly."
                )
                .font(.custom("CrimsonText-Regular", size: 14))
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
          .disabled(!appState.settings.voiceSyncEnabled)
          .opacity(appState.settings.voiceSyncEnabled ? 1.0 : 0.6)

          // Sensitivity — disabled when voice tracking is off
          VStack(alignment: .leading, spacing: 10) {
            systemFieldLabel("Speech Sensitivity")
            HStack(spacing: 8) {
              ForEach(SpeechSensitivity.allCases, id: \.self) { level in
                let isActive = appState.settings.speechSensitivity == level
                Button {
                  appState.settings.speechSensitivity = level
                } label: {
                  Text(level.rawValue.capitalized)
                    .font(.custom("CrimsonText-Regular", size: 17))
                    .foregroundStyle(
                      Color("colorText")
                        .opacity(appState.settings.voiceSyncEnabled ? 1 : 0.35)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                      isActive && appState.settings.voiceSyncEnabled
                        ? Color("colorPrimary").opacity(0.1)
                        : Color("colorBackground").opacity(0.75)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                      RoundedRectangle(cornerRadius: 12)
                        .stroke(
                          isActive && appState.settings.voiceSyncEnabled
                            ? Color("colorPrimary")
                            : Color("colorText").opacity(0.14),
                          lineWidth: isActive && appState.settings.voiceSyncEnabled ? 3 : 2
                        ))
                }
                .buttonStyle(.plain)
                .disabled(!appState.settings.voiceSyncEnabled)
              }
            }
            Text("Keeps the scroll tied to your natural pace instead of forcing a robotic cadence.")
              .font(.custom("CrimsonText-Regular", size: 14))
              .foregroundStyle(
                Color("colorText")
                  .opacity(appState.settings.voiceSyncEnabled ? 0.64 : 0.3))
          }
          .opacity(appState.settings.voiceSyncEnabled ? 1 : 0.5)
          .animation(.easeInOut(duration: 0.2), value: appState.settings.voiceSyncEnabled)

          Divider().opacity(0.2)

          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Spoken-word highlighting")
                .font(.custom("CrimsonText-Regular", size: 18))
                .foregroundStyle(Color("colorText"))
              Text(
                "Visual only. Dims spoken words and marks current word without changing scroll behavior."
              )
              .font(.custom("CrimsonText-Regular", size: 14))
              .foregroundStyle(Color("colorText").opacity(0.6))
            }
            Spacer()
            Toggle("", isOn: $appState.settings.spokenWordHighlightingEnabled)
              .toggleStyle(.switch)
              .tint(Color("colorPrimary"))
              .labelsHidden()
          }

          Divider().opacity(0.2)

          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Pause on mouse hover")
                .font(.custom("CrimsonText-Regular", size: 18))
                .foregroundStyle(Color("colorText"))
              Text(
                "Pauses notch scrolling while pointer stays over overlay. Pill windows ignore this setting."
              )
              .font(.custom("CrimsonText-Regular", size: 14))
              .foregroundStyle(Color("colorText").opacity(0.6))
            }
            Spacer()
            Toggle("", isOn: $appState.settings.pauseOnHoverEnabled)
              .toggleStyle(.switch)
              .tint(Color("colorPrimary"))
              .labelsHidden()
          }
        }
        .padding(.top, 14)
      }

      SettingsPanel {
        SectionTitle(text: "Controls")
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

      SettingsPanel {
        SectionTitle(text: "Privacy")
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Hide overlays from screen sharing")
                .font(.custom("CrimsonText-Regular", size: 18))
                .foregroundStyle(Color("colorText"))
              Text(
                "Turn this off if you want notch or Pill Window overlay to appear in screenshots, recordings, or video calls."
              )
              .font(.custom("CrimsonText-Regular", size: 14))
              .foregroundStyle(Color("colorText").opacity(0.6))
            }
            Spacer()
            Toggle("", isOn: $appState.settings.screenCaptureExclusionEnabled)
              .toggleStyle(.switch)
              .tint(Color("colorPrimary"))
              .labelsHidden()
          }

          Text(
            appState.settings.screenCaptureExclusionEnabled
              ? "On by default. Aira asks macOS to exclude overlay windows from capture streams."
              : "Off. Overlay windows remain visible to screen capture apps by choice, so stealth warnings stay suppressed."
          )
          .font(.custom("CrimsonText-Regular", size: 14))
          .foregroundStyle(Color("colorText").opacity(0.62))
        }
        .padding(.top, 14)
      }
    }
  }

  private func shortcutRow(_ label: String, _ key: Binding<String>) -> some View {
    HStack(alignment: .center) {
      Text(label)
        .font(.custom("CrimsonText-Regular", size: 18))
        .foregroundStyle(Color("colorText"))
      Spacer()
      ShortcutKeyCapsField(shortcut: key)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }

  private func countdownStepButton(systemName: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(Color("colorText"))
        .frame(width: 34, height: 34)
        .background(Color("colorBackground").opacity(0.82))
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
