import AppKit
import SwiftUI

// MARK: - Tab

private enum SettingsTab: CaseIterable, Hashable {
  case appearance, notch, system

  var label: String {
    switch self {
    case .appearance: return "Appearance"
    case .notch: return "The Notch"
    case .system: return "System"
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
      }
      .buttonStyle(.plain)
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
  @State private var expandedManualPillSlot: Int? = nil
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
  private let moodPresets = MoodPreset.all
  private var previewHasPhysicalNotch: Bool { NotchWindowController.builtInDisplayHasPhysicalNotch }
  private var previewTextTopPadding: CGFloat { previewHasPhysicalNotch ? 40 : 18 }

  // Binding that bridges Color ↔ hex string in appState
  private var overlayColorBinding: Binding<Color> {
    Binding(
      get: { Color(hex: appState.settings.defaultOverlayAppearance.backgroundColor) },
      set: { newColor in
        let ns = NSColor(newColor).usingColorSpace(.sRGB) ?? .white
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
        let ns = NSColor(newColor).usingColorSpace(.sRGB) ?? .black
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
          Text("Your teleprompter text appears here")
            .font(
              .custom(
                appState.settings.defaultOverlayAppearance.fontName,
                size: min(max(appState.settings.defaultOverlayAppearance.fontSize * 0.72, 12), 24)
              )
            )
            .fontWeight(.semibold)
            .foregroundStyle(Color(hex: appState.settings.defaultOverlayAppearance.textColor))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.top, previewTextTopPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: previewNotchWidth, height: previewNotchHeight)
        .clipShape(NotchWrapShape(hasNotch: previewHasPhysicalNotch))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 156)
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
            14...32)

          HStack {
            Spacer()
            Button("Reset to Defaults") {
              resetOverlayFeelToDefaults()
            }
            .font(.custom("CrimsonText-Regular", size: 16))
            .foregroundStyle(Color("colorBackground"))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color("colorPrimary"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .buttonStyle(.plain)
          }
        }
        .padding(.top, 14)
      }

      SettingsPanel {
        SectionTitle(text: "Mood Presets")
        Text("Apply a complete overlay mood in one move, then keep refining from there.")
          .font(.custom("CrimsonText-Regular", size: 14))
          .foregroundStyle(Color("colorText").opacity(0.6))
          .padding(.top, 2)

        HStack(spacing: 12) {
          ForEach(moodPresets) { preset in
            let isActive = appState.settings.defaultOverlayAppearance == preset.appearance
            Button {
              appState.settings.defaultOverlayAppearance = preset.appearance
            } label: {
              VStack(alignment: .leading, spacing: 10) {
                ZStack {
                  Circle()
                    .fill(Color(hex: preset.appearance.backgroundColor))
                    .frame(width: 52, height: 52)
                  Text("Aa")
                    .font(.custom("IndieFlower", size: 20))
                    .foregroundStyle(Color(hex: preset.appearance.textColor))
                }

                Text(preset.name)
                  .font(.custom("IndieFlower", size: 22))
                  .foregroundStyle(Color("colorText"))

                Text(
                  preset.name == "Day"
                    ? "Sage paper with cream text for daytime contrast."
                    : "Charcoal glass with warm tan text for low-light focus."
                )
                .font(.custom("CrimsonText-Regular", size: 14))
                .foregroundStyle(Color("colorText").opacity(0.64))
                .fixedSize(horizontal: false, vertical: true)
              }
              .padding(16)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                isActive
                  ? Color("colorPrimary").opacity(0.12)
                  : Color("colorBackground").opacity(0.7)
              )
              .clipShape(RoundedRectangle(cornerRadius: 18))
              .overlay(
                RoundedRectangle(cornerRadius: 18)
                  .stroke(
                    isActive ? Color("colorPrimary") : Color("colorText").opacity(0.14),
                    lineWidth: isActive ? 3 : 2
                  )
              )
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.top, 14)
      }

      SettingsPanel {
        SectionTitle(text: "Overlay Font")
        Text("Pick the typeface after you land on the mood you want in the preview.")
          .font(.custom("CrimsonText-Regular", size: 14))
          .foregroundStyle(Color("colorText").opacity(0.6))
          .padding(.top, 2)
        SystemFontPicker(selectedFont: $appState.settings.defaultOverlayAppearance.fontName)
          .padding(.top, 10)
      }

      SettingsPanel {
        SectionTitle(text: "Pill Windows")
        Text("Choose whether free-moving pill overlays are available during a live session.")
          .font(.custom("CrimsonText-Regular", size: 14))
          .foregroundStyle(Color("colorText").opacity(0.6))
          .padding(.top, 2)

        VStack(alignment: .leading, spacing: 16) {
          HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Enable Pill Windows")
                .font(.custom("IndieFlower", size: 22))
                .foregroundStyle(Color("colorText"))
              Text("Turn this off to keep live sessions limited to the main overlay.")
                .font(.custom("CrimsonText-Regular", size: 14))
                .foregroundStyle(Color("colorText").opacity(0.62))
            }
            Spacer(minLength: 12)
            Toggle("", isOn: $appState.settings.pillsEnabled)
              .toggleStyle(.switch)
              .tint(Color("colorPrimary"))
              .labelsHidden()
              .accessibilityLabel("Enable Pill Windows")
          }

          VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: "Maximum Pill Windows")
            HStack(spacing: 8) {
              pillCountButton(count: 1)
              pillCountButton(count: 2)
            }
            .disabled(!appState.settings.pillsEnabled)
            .opacity(appState.settings.pillsEnabled ? 1 : 0.45)

            Text(
              appState.settings.pillsEnabled
                ? "Allow one or two floating pill windows during a live session."
                : "Enable pill windows to choose how many can appear during a live session."
            )
            .font(.custom("CrimsonText-Regular", size: 14))
            .foregroundStyle(Color("colorText").opacity(0.62))
          }

          Divider().opacity(0.2)

          VStack(alignment: .leading, spacing: 16) {
            FieldLabel(text: "Content Mode")

            ForEach(0..<appState.settings.clampedMaxPillCount, id: \.self) { slot in
              pillContentModeSection(forSlot: slot)
            }
          }
          .disabled(!appState.settings.pillsEnabled)
          .opacity(appState.settings.pillsEnabled ? 1 : 0.45)
        }
        .padding(.top, 12)
      }
    }
  }

  private var previewNotchWidth: CGFloat {
    let normalized =
      (appState.settings.notchWindowWidth - NotchWidthConfiguration.minimumWidth)
      / (NotchWidthConfiguration.maximumWidth - NotchWidthConfiguration.minimumWidth)
    let clamped = min(max(normalized, 0), 1)
    return 240 + (160 * clamped)
  }

  private var previewNotchHeight: CGFloat {
    let normalized =
      (appState.settings.notchWindowHeight - NotchHeightConfiguration.minimumHeight)
      / (NotchHeightConfiguration.maximumHeight - NotchHeightConfiguration.minimumHeight)
    let clamped = min(max(normalized, 0), 1)
    return 108 + (48 * clamped)
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

      ColorPicker("", selection: selection, supportsOpacity: false)
        .labelsHidden()
        .opacity(0.015)
        .contentShape(Rectangle())
    }
    .aspectRatio(1, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color("colorText").opacity(0.12), lineWidth: 1)
    )
  }

  private func resetOverlayFeelToDefaults() {
    appState.settings.notchWindowWidth = NotchWidthConfiguration.defaultWidth
    appState.settings.notchWindowHeight = NotchHeightConfiguration.defaultHeight
    appState.settings.defaultOverlayAppearance.opacity = OverlayAppearance.default.opacity
    appState.settings.defaultOverlayAppearance.fontSize = OverlayAppearance.default.fontSize
  }

  @ViewBuilder
  private func pillContentModeSection(forSlot slot: Int) -> some View {
    let mode = appState.settings.pillContentMode(forSlot: slot)

    VStack(alignment: .leading, spacing: 8) {
      Text("Pill \(slot + 1)")
        .font(.custom("IndieFlower", size: 22))
        .foregroundStyle(Color("colorText"))

      HStack(spacing: 8) {
        ForEach(["Sync", "Manual"], id: \.self) { label in
          let isSync = label == "Sync"
          let isSelected = isSync ? mode == .voiceSync : mode != .voiceSync

          Button {
            if isSync {
              appState.settings.setPillContentMode(.voiceSync, forSlot: slot)
            } else {
              enableManualPillMode(forSlot: slot)
            }
          } label: {
            Text(label)
              .font(.custom("CrimsonText-Regular", size: 16))
              .foregroundStyle(
                isSelected ? Color("colorBackground") : Color("colorText").opacity(0.6)
              )
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
              .background(isSelected ? Color("colorPrimary") : Color("colorBackground"))
              .clipShape(RoundedRectangle(cornerRadius: 10))
              .overlay(
                RoundedRectangle(cornerRadius: 10)
                  .stroke(Color("colorText").opacity(0.1), lineWidth: 1)
              )
          }
          .buttonStyle(.plain)
          .disabled(!appState.settings.pillsEnabled || (!isSync && appState.scripts.isEmpty))
        }
      }

      if case .manual(let selectedId) = mode {
        Button {
          expandedManualPillSlot = expandedManualPillSlot == slot ? nil : slot
        } label: {
          HStack(spacing: 10) {
            Text(appState.scripts.first(where: { $0.id == selectedId })?.title ?? "Select a script")
              .font(.custom("CrimsonText-Regular", size: 16))
              .foregroundStyle(Color("colorText"))
            Spacer()
            Image(systemName: expandedManualPillSlot == slot ? "chevron.up" : "chevron.down")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(Color("colorText").opacity(0.55))
          }
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
        .disabled(!appState.settings.pillsEnabled || appState.scripts.isEmpty)

        if expandedManualPillSlot == slot {
          ScrollView {
            VStack(spacing: 6) {
              ForEach(appState.scripts) { meta in
                Button {
                  appState.settings.setPillContentMode(.manual(scriptId: meta.id), forSlot: slot)
                  expandedManualPillSlot = nil
                } label: {
                  HStack(spacing: 10) {
                    Text(meta.title)
                      .font(.custom("CrimsonText-Regular", size: 16))
                      .foregroundStyle(Color("colorText"))
                      .lineLimit(1)
                    Spacer()
                    if meta.id == selectedId {
                      Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color("colorPrimary"))
                    }
                  }
                  .padding(.horizontal, 14)
                  .padding(.vertical, 10)
                  .background(Color("colorBackground").opacity(0.9))
                  .clipShape(RoundedRectangle(cornerRadius: 12))
                  .overlay(
                    RoundedRectangle(cornerRadius: 12)
                      .stroke(Color("colorText").opacity(0.1), lineWidth: 1)
                  )
                }
                .buttonStyle(.plain)
              }
            }
          }
          .frame(maxHeight: 220)
          .padding(8)
          .background(Color("colorSurface").opacity(0.7))
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(Color("colorText").opacity(0.1), lineWidth: 1)
          )
        }
      }

      Text(
        mode == .voiceSync
          ? "Pill \(slot + 1) follows the notch and stays in sync with the shared session scroll."
          : "Pill \(slot + 1) displays its selected script and scrolls manually."
      )
      .font(.custom("CrimsonText-Regular", size: 14))
      .foregroundStyle(Color("colorText").opacity(0.62))
    }
  }

  private func enableManualPillMode(forSlot slot: Int) {
    if case .manual = appState.settings.pillContentMode(forSlot: slot) {
      return
    }

    guard let firstScript = appState.scripts.first else { return }
    appState.settings.setPillContentMode(.manual(scriptId: firstScript.id), forSlot: slot)
    expandedManualPillSlot = slot
  }

  @ViewBuilder
  private func pillCountButton(count: Int) -> some View {
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
}

// MARK: - Notch Wrap Shape

/// Translates the clip-path from NotchPreview.tsx exactly.
/// Source coordinate space: 250 × 110
/// Notch cutout: x 65→185 (120 wide), y 0→30 (30 deep), centred at x=125
/// Outer corners: 5pt radius top, 10pt radius bottom
private struct NotchWrapShape: Shape {
  let hasNotch: Bool

  func path(in rect: CGRect) -> Path {
    guard hasNotch else {
      return NotchOverlayGeometry.fallbackPath(in: rect)
    }

    let sx = rect.width / 250.0
    let sy = rect.height / 110.0
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
    var p = Path()
    p.move(to: pt(10, 30))
    p.addLine(to: pt(10, 10))
    p.addQuadCurve(to: pt(15, 5), control: pt(10, 5))  // top-left corner
    p.addLine(to: pt(65, 5))
    p.addLine(to: pt(65, 16))
    p.addQuadCurve(to: pt(69, 27), control: pt(65, 23))  // notch inner-left upper
    p.addQuadCurve(to: pt(79, 30), control: pt(72, 30))  // notch inner-left lower
    p.addLine(to: pt(171, 30))
    p.addQuadCurve(to: pt(181, 27), control: pt(178, 30))  // notch inner-right lower
    p.addQuadCurve(to: pt(185, 16), control: pt(185, 23))  // notch inner-right upper
    p.addLine(to: pt(185, 5))
    p.addLine(to: pt(235, 5))
    p.addQuadCurve(to: pt(240, 10), control: pt(240, 5))  // top-right corner
    p.addLine(to: pt(240, 95))
    p.addQuadCurve(to: pt(230, 105), control: pt(240, 105))  // bottom-right corner
    p.addLine(to: pt(20, 105))
    p.addQuadCurve(to: pt(10, 95), control: pt(10, 105))  // bottom-left corner
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

  var body: some View {
    VStack(spacing: 16) {

      SettingsPanel {
        SectionTitle(text: "Keyboard Shortcuts")
        VStack(spacing: 8) {
          shortcutRow("Toggle Notch", $appState.settings.shortcutToggleNotch)
          shortcutRow("Toggle Pill", $appState.settings.shortcutTogglePill)
          shortcutRow("Space to Pause", $appState.settings.shortcutToggleVoiceSync)
          shortcutRow("Scroll Up", $appState.settings.shortcutScrollUp)
          shortcutRow("Scroll Down", $appState.settings.shortcutScrollDown)
          shortcutRow("End Session", $appState.settings.shortcutEndSession)
        }
        .padding(.top, 12)
      }

      SettingsPanel {
        SectionTitle(text: "Session Countdown")
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
        }
        .padding(.top, 14)
      }

      SettingsPanel {
        SectionTitle(text: "Manual Scroll & Voice Pace")
        VStack(alignment: .leading, spacing: 14) {
          HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Auto-scroll speed (WPM)")
                .font(.custom("CrimsonText-Regular", size: 18))
                .foregroundStyle(Color("colorText"))
              Text("Sets the base speed for Manual scroll when Voice-Sync is off.")
                .font(.custom("CrimsonText-Regular", size: 14))
                .foregroundStyle(Color("colorText").opacity(0.6))
            }
            Spacer()
            Text("\(Int(autoScrollWPMSliderBinding.wrappedValue.rounded())) WPM")
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
            Text("\(Int(ManualScrollConfiguration.minimumWPM)) WPM")
            Spacer()
            Text("\(Int(ManualScrollConfiguration.maximumWPM)) WPM")
          }
          .font(.custom("CrimsonText-Regular", size: 14))
          .foregroundStyle(Color("colorText").opacity(0.55))
        }
        .padding(.top, 14)
      }

      SettingsPanel {
        SectionTitle(text: "Voice Tracking")
        VStack(alignment: .leading, spacing: 16) {

          // Toggle first
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text("Enable voice-activated scrolling")
                .font(.custom("CrimsonText-Regular", size: 18))
                .foregroundStyle(Color("colorText"))
              Text("Automatically scroll based on speech detection")
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
                Text("Voice Follow")
                  .font(.custom("CrimsonText-Regular", size: 18))
                  .foregroundStyle(Color("colorText"))
                Text(
                  "Moves with speech, uses your configured WPM as a base, adds a faster voice-follow pace, and keeps the script anchored smoothly."
                )
                .font(.custom("CrimsonText-Regular", size: 14))
                .foregroundStyle(Color("colorText").opacity(0.6))
              }
              Spacer()
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
