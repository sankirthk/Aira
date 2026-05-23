import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ScriptEditorLaunchMenuAction: Identifiable, Equatable {
  enum Kind: Equatable {
    case castWithSatellite
  }

  let kind: Kind
  let title: String

  var id: String { title }

  static let defaultItems: [ScriptEditorLaunchMenuAction] = [
    .init(kind: .castWithSatellite, title: "Cast with Pill Windows")
  ]
}

enum ScriptEditorSatelliteLaunchChoice: Equatable, CaseIterable {
  case mirrorCurrentScript
  case manual

  var title: String {
    switch self {
    case .mirrorCurrentScript:
      return "Mirror current script"
    case .manual:
      return "Manual"
    }
  }
}

struct ScriptEditorSatelliteLaunchSection: Identifiable, Equatable {
  let slotIndex: Int
  var choice: ScriptEditorSatelliteLaunchChoice = .mirrorCurrentScript
  var selectedManualScriptID: UUID?

  var id: Int { slotIndex }

  var title: String {
    "Pill Window \(slotIndex)"
  }
}

struct ScriptEditorSatelliteLaunchPanelState: Equatable {
  var sections: [ScriptEditorSatelliteLaunchSection]
  static let manualScriptRowAffordance = ScriptEditorSatelliteLaunchRowAffordance(
    usesFullWidthHitArea: true,
    usesPointingHandCursor: true,
    usesHoverCursorTracking: true
  )
  static let choiceButtonAffordance = ScriptEditorSatelliteLaunchRowAffordance(
    usesFullWidthHitArea: true,
    usesPointingHandCursor: true,
    usesHoverCursorTracking: true
  )

  static func make(enabledSatelliteCount: Int) -> Self {
    let count = max(1, min(enabledSatelliteCount, 2))
    return Self(
      sections: (1...count).map { index in
        ScriptEditorSatelliteLaunchSection(slotIndex: index)
      }
    )
  }

  func pillModes() -> [PillContentMode] {
    sections.compactMap { section in
      switch section.choice {
      case .mirrorCurrentScript:
        return .voiceSync
      case .manual:
        guard let scriptID = section.selectedManualScriptID else {
          return nil
        }
        return .manual(scriptId: scriptID)
      }
    }
  }

  func launchRequest(scripts: [ScriptMeta]) -> ScriptEditorSatelliteLaunchRequest {
    let scriptsByID = Dictionary(uniqueKeysWithValues: scripts.map { ($0.id, $0) })

    var satelliteSelections: [SatelliteLaunchSelection] = []
    var skippedDueToEmptyScript = 0

    for section in sections {
      switch section.choice {
      case .mirrorCurrentScript:
        satelliteSelections.append(
          SatelliteLaunchSelection(slotIndex: section.slotIndex, mode: .voiceSync)
        )
      case .manual:
        guard let scriptID = section.selectedManualScriptID else {
          // No script selected yet — not a skip, just not ready
          continue
        }
        if let script = scriptsByID[scriptID], script.wordCount > 0 {
          satelliteSelections.append(
            SatelliteLaunchSelection(
              slotIndex: section.slotIndex, mode: .manual(scriptId: scriptID))
          )
        } else {
          // Script selected but empty
          skippedDueToEmptyScript += 1
        }
      }
    }

    return ScriptEditorSatelliteLaunchRequest(
      requestedSatelliteCount: sections.count,
      satelliteSelections: satelliteSelections,
      skippedDueToEmptyScript: skippedDueToEmptyScript
    )
  }

  static func manualScriptDropdownTitle(
    for section: ScriptEditorSatelliteLaunchSection,
    scripts: [ScriptMeta]
  ) -> String {
    guard let selectedID = section.selectedManualScriptID,
      let selectedScript = scripts.first(where: { $0.id == selectedID })
    else {
      return "Select script"
    }
    return selectedScript.title
  }
}

struct ScriptEditorSatelliteLaunchRowAffordance: Equatable {
  let usesFullWidthHitArea: Bool
  let usesPointingHandCursor: Bool
  let usesHoverCursorTracking: Bool
}

struct ScriptEditorSatelliteLaunchRequest: Equatable {
  let requestedSatelliteCount: Int
  let satelliteSelections: [SatelliteLaunchSelection]
  let skippedDueToEmptyScript: Int

  var pillModes: [PillContentMode] {
    satelliteSelections.map(\.mode)
  }

  var skippedSatelliteFeedbackMessage: String? {
    guard skippedDueToEmptyScript > 0 else { return nil }
    if skippedDueToEmptyScript == 1 {
      return "1 Pill Window will be skipped because the selected script is empty."
    }
    return
      "\(skippedDueToEmptyScript) Pill Windows will be skipped because the selected scripts are empty."
  }
}

enum ScriptEditorPresentationState {
  static func blocksEditorInteraction(
    isLaunchMenuPresented: Bool,
    isSatelliteLaunchPanelPresented: Bool
  ) -> Bool {
    isLaunchMenuPresented || isSatelliteLaunchPanelPresented
  }
}

struct ScriptEditorView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme
  @Binding var script: Script
  @State private var saveErrorMessage: String?
  @State private var importErrorMessage: String?
  @State private var selectedRange = NSRange(location: 0, length: 0)
  @State private var isLaunchMenuPresented = false
  @State private var isCuePopoverPresented = false
  @State private var isSatelliteLaunchPanelPresented = false
  @State private var satelliteLaunchPanelState = ScriptEditorSatelliteLaunchPanelState(
    sections: []
  )
  let managerFontScale: CGFloat
  let isReadOnly: Bool
  var onCast: () -> Void
  var onCastWithSatellite: ([SatelliteLaunchSelection]) -> Void = { _ in }
  var onBack: () -> Void

  private var usesGlass: Bool { managerTheme.usesLiquidGlassMode }

  private var saveButtonForegroundColor: Color {
    colorScheme == .dark ? .white : managerTheme.actionAccent(for: colorScheme)
  }

  private var classicEditorHeaderBackground: Color {
    if managerTheme.colorPalette == .aira {
      return colorScheme == .dark
        ? managerTheme.contentBackground(for: colorScheme) : Color(hex: "#F0F4F0")
    }
    return managerTheme.surfaceFill(for: colorScheme)
  }

  private var classicEditorSurfaceBackground: Color {
    return managerTheme.contentBackground(for: colorScheme)
  }

  private var classicEditorPanelBackground: Color {
    return managerTheme.surfaceFill(for: colorScheme)
  }

  var wordCount: Int {
    ScriptEditorMetrics.wordCount(for: script.body)
  }

  private var blocksEditorInteraction: Bool {
    ScriptEditorPresentationState.blocksEditorInteraction(
      isLaunchMenuPresented: isLaunchMenuPresented,
      isSatelliteLaunchPanelPresented: isSatelliteLaunchPanelPresented
    )
  }

  var estimatedDuration: String {
    let minutes = max(1, wordCount / 130)
    return "\(wordCount) words · ~\(minutes)m"
  }

  private func scaled(_ size: CGFloat) -> CGFloat {
    size * managerFontScale
  }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      VStack(spacing: 0) {

        HStack(spacing: 12) {
          Button {
            onBack()
          } label: {
            AiraIcon(
              type: .back, size: 20,
              color: colorScheme == .dark ? .white : managerTheme.actionAccent(for: colorScheme),
              animated: false
            )
            .padding(8)
            .background {
              if usesGlass {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .fill(
                    managerTheme.actionAccent(for: colorScheme).opacity(
                      colorScheme == .dark ? 0.18 : 0.12)
                  )
                  .background(
                    .ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
              } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .fill(
                    managerTheme.actionAccent(for: colorScheme).opacity(
                      colorScheme == .dark ? 0.16 : 0.10))
              }
            }
            .overlay {
              if usesGlass {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .strokeBorder(
                    managerTheme.actionAccent(for: colorScheme).opacity(0.30), lineWidth: 0.5)
              }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          .buttonStyle(.plain)

          TextField("Script title", text: $script.title)
            .font(
              usesGlass
                ? .system(size: scaled(20), weight: .semibold)
                : .custom("IndieFlower", size: scaled(20))
            )
            .textFieldStyle(.plain)
            .foregroundStyle(usesGlass ? .primary : Color("colorText"))
            .tint(managerTheme.actionAccent(for: colorScheme))
            .disabled(isReadOnly)

          Spacer()

          Text(estimatedDuration)
            .font(
              usesGlass
                ? .system(size: scaled(13))
                : .custom("Inter-Regular", size: scaled(13))
            )
            .foregroundStyle(usesGlass ? .secondary : Color("colorMuted"))

          if isReadOnly {
            Text("Live script · read only")
              .font(
                usesGlass
                  ? .system(size: scaled(13))
                  : .custom("CrimsonText-Regular", size: scaled(13))
              )
              .foregroundStyle(usesGlass ? .secondary : Color("colorMuted"))
          }

          Button {
            isCuePopoverPresented.toggle()
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "plus")
              Text("Cue")
            }
          }
          .buttonStyle(AiraWobblyToolbarButtonStyle(variant: .tertiary))
          .popover(isPresented: $isCuePopoverPresented, arrowEdge: .bottom) {
            CuePopoverView(isReadOnly: isReadOnly, usesGlass: usesGlass) { cue in
              insertCue(cue)
              isCuePopoverPresented = false
            }
            .environment(\.managerFontScale, managerFontScale)
            .environment(\.managerTheme, managerTheme)
          }
          .disabled(isReadOnly)
          .opacity(isReadOnly ? 0.55 : 1)

          Button {
            importFromFile()
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "square.and.arrow.down")
              Text("Import")
            }
          }
          .buttonStyle(AiraWobblyToolbarButtonStyle(variant: .tertiary))
          .disabled(isReadOnly)
          .opacity(isReadOnly ? 0.55 : 1)

          Button {
            saveScript()
          } label: {
            HStack(spacing: 8) {
              AiraIcon(
                type: .save, size: 18,
                color: saveButtonForegroundColor,
                animated: false
              )
              Text("Save")
                .foregroundStyle(saveButtonForegroundColor)
            }
          }
          .buttonStyle(AiraWobblyToolbarButtonStyle(variant: .tertiary))
          .disabled(isReadOnly)
          .opacity(isReadOnly ? 0.55 : 1)

          ScriptEditorLaunchSplitButton(
            isMenuPresented: $isLaunchMenuPresented,
            onPrimaryPress: {
              isLaunchMenuPresented = false
              onCast()
            },
            onCastWithSatellite: {
              isLaunchMenuPresented = false
              handleLaunchMenuAction(.castWithSatellite)
            }
          )
          .disabled(isReadOnly)
          .opacity(isReadOnly ? 0.55 : 1)
        }
        .frame(height: 44)
        .padding(ManagerLayoutParity.scriptEditorHeaderPadding)
        .background(usesGlass ? Color.clear : classicEditorHeaderBackground)

        ScriptEditorPanel(backgroundColor: classicEditorPanelBackground) {
          VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
              ScriptTextEditor(
                text: $script.body,
                selectedRange: $selectedRange,
                isEditable: !isReadOnly,
                suppressInteractivity: blocksEditorInteraction
              )
              .padding(14)
              .frame(maxWidth: .infinity, maxHeight: .infinity)

              if script.body.isEmpty {
                Text("Start typing your script here...")
                  .font(
                    usesGlass
                      ? .system(size: scaled(18))
                      : .custom("CrimsonText-Regular", size: scaled(18))
                  )
                  .foregroundColor(usesGlass ? .secondary : Color("colorText").opacity(0.4))
                  .padding(.horizontal, 20)
                  .padding(.vertical, 20)
                  .allowsHitTesting(false)
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
              Text("\(wordCount) words")
              Spacer()
              Text("\(script.body.count) characters")
            }
            .font(
              usesGlass
                ? .system(size: scaled(15))
                : .custom("CrimsonText-Regular", size: scaled(15))
            )
            .foregroundStyle(usesGlass ? .secondary : Color("colorMuted"))
            .padding(.top, 16)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(usesGlass ? Color.clear : classicEditorSurfaceBackground)
      }
      .managerSurface(
        cornerRadius: ManagerLayoutParity.scriptEditorRootCornerRadius,
        classicFill: classicEditorSurfaceBackground,
        strokeOpacity: 0.12
      )

      if isSatelliteLaunchPanelPresented {
        Color.clear
          .contentShape(Rectangle())
          .ignoresSafeArea()
          .onTapGesture {
            isSatelliteLaunchPanelPresented = false
          }

        ScriptEditorSatelliteLaunchPanel(
          state: $satelliteLaunchPanelState,
          scripts: appState.scripts,
          onLaunch: {
            let launchRequest = satelliteLaunchPanelState.launchRequest(scripts: appState.scripts)
            isSatelliteLaunchPanelPresented = false
            onCastWithSatellite(launchRequest.satelliteSelections)
          },
          onCancel: {
            isSatelliteLaunchPanelPresented = false
          }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 36)
      }
    }
    .alert("Unable to Save Script", isPresented: saveErrorIsPresented) {
      Button("OK", role: .cancel) {
        saveErrorMessage = nil
      }
    } message: {
      Text(saveErrorMessage ?? "Please try again.")
    }
    .alert("Import Failed", isPresented: importErrorIsPresented) {
      Button("OK", role: .cancel) {
        importErrorMessage = nil
      }
    } message: {
      Text(importErrorMessage ?? "Could not read the file.")
    }
  }

  private var saveErrorIsPresented: Binding<Bool> {
    Binding(
      get: { saveErrorMessage != nil },
      set: { if !$0 { saveErrorMessage = nil } }
    )
  }

  private var importErrorIsPresented: Binding<Bool> {
    Binding(
      get: { importErrorMessage != nil },
      set: { if !$0 { importErrorMessage = nil } }
    )
  }

  private func saveScript() {
    guard !isReadOnly else {
      return
    }

    do {
      try appState.saveScript(script)
      if let savedScript = appState.activeScript {
        script = savedScript
      }
    } catch {
      saveErrorMessage = error.localizedDescription
    }
  }

  private func importFromFile() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.plainText, .pdf, UTType(filenameExtension: "docx")].compactMap {
      $0
    }
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.message = "Choose a text, PDF, or Word file to import"

    guard panel.runModal() == .OK, let url = panel.url else { return }

    do {
      let text = try appState.extractText(from: url)
      script.body = text
    } catch {
      importErrorMessage = error.localizedDescription
    }
  }

  private func insertCue(_ cue: String) {
    guard !isReadOnly else {
      return
    }

    let result = ScriptEditorTextInsertion.insertCue(
      cue,
      into: script.body,
      selectedRange: selectedRange
    )
    script.body = result.text
    selectedRange = result.selectedRange
  }

  private func handleLaunchMenuAction(_ action: ScriptEditorLaunchMenuAction.Kind) {
    switch action {
    case .castWithSatellite:
      presentSatelliteLaunchPanel()
    }
  }

  private func presentSatelliteLaunchPanel() {
    satelliteLaunchPanelState = ScriptEditorSatelliteLaunchPanelState.make(
      enabledSatelliteCount: appState.settings.clampedMaxPillCount
    )
    isSatelliteLaunchPanelPresented = true
  }
}

private struct ScriptEditorRootBorder: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(
      cornerRadius: ManagerLayoutParity.scriptEditorRootCornerRadius,
      style: .continuous
    )

    content
      .clipShape(shape)
      .overlay {
        shape
          .strokeBorder(
            (colorScheme == .dark ? Color.white : Color("colorText")).opacity(
              colorScheme == .dark ? 0.20 : 0.16),
            lineWidth: 1
          )
          .allowsHitTesting(false)
      }
  }
}

private struct ScriptEditorLaunchSplitButton: View {
  @Binding var isMenuPresented: Bool
  let onPrimaryPress: () -> Void
  let onCastWithSatellite: () -> Void
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  private var usesGlass: Bool { managerTheme.usesLiquidGlassMode }
  private var isDark: Bool { colorScheme == .dark }
  private var launchForegroundColor: Color {
    .white
  }
  private var launchAccentColor: Color {
    managerTheme.actionAccent(for: colorScheme)
  }
  private var cornerRadius: CGFloat { ManagerLayoutParity.toolbarButtonCornerRadius }
  private var controlHeight: CGFloat { ManagerLayoutParity.toolbarButtonHeight }
  private var dividerHeight: CGFloat { 24 }

  private var menuFont: Font {
    usesGlass
      ? .system(size: 14 * managerFontScale, weight: .regular, design: .default)
      : .custom("CrimsonText-Regular", size: 15 * managerFontScale)
  }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      HStack(spacing: 0) {
        Button {
          onPrimaryPress()
        } label: {
          HStack(spacing: 8) {
            AiraIcon(type: .notch, size: 18, color: launchForegroundColor, animated: false)
            Text("Cast to Notch")
          }
          .padding(.leading, 16)
          .padding(.trailing, 14)
          .frame(height: controlHeight)
        }
        .buttonStyle(.plain)
        .contentShape(.rect)

        Rectangle()
          .fill(Color.white.opacity(0.28))
          .frame(width: 1, height: dividerHeight)

        Button {
          isMenuPresented.toggle()
        } label: {
          Image(systemName: "chevron.down")
            .font(.system(size: 10, weight: .semibold))
            .frame(width: 30, height: controlHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isMenuPresented, arrowEdge: .bottom) {
          popoverContent
        }
      }
      .frame(height: controlHeight)
      .font(
        usesGlass
          ? .system(size: 15 * managerFontScale, weight: .medium)
          : .custom("IndieFlower", size: 15 * managerFontScale)
      )
      .foregroundStyle(launchForegroundColor)
      .background {
        launchButtonBackground
      }
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        if usesGlass {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
              launchAccentColor.opacity(isDark ? 0.45 : 0.60),
              lineWidth: 1
            )
        } else {
          splitButtonBorder
        }
      }
      .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
    .frame(height: controlHeight)
  }

  private var popoverContent: some View {
    Button {
      isMenuPresented = false
      onCastWithSatellite()
    } label: {
      HStack(spacing: 10) {
        Text("Cast with Pill Windows")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .buttonStyle(.plain)
    .font(menuFont)
    .foregroundStyle(usesGlass ? .primary : Color("colorText"))
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(
          usesGlass
            ? AnyShapeStyle(.background)
            : AnyShapeStyle(managerTheme.controlFill(for: colorScheme))
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(
          (usesGlass ? managerTheme.actionAccent(for: colorScheme) : Color("colorText")).opacity(
            0.18),
          lineWidth: 1
        )
    )
    .padding(8)
    .frame(width: 210)
  }

  private var splitButtonBorder: some View {
    RoundedRectangle(cornerRadius: cornerRadius)
      .inset(by: 2)
      .stroke(
        Color.white.opacity(0.8),
        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [2, 1])
      )
  }

  @ViewBuilder
  private var launchButtonBackground: some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

    if usesGlass {
      let opacity: Double = isDark ? 0.48 : 0.76
      shape
        .fill(launchAccentColor.opacity(opacity))
        .background(.ultraThinMaterial, in: shape)
    } else {
      shape.fill(managerTheme.classicSelectedActionFill(for: colorScheme))
    }
  }
}

enum ScriptEditorLaunchButtonAffordances {
  static let classicUsesSharedToolbarHeight = true
  static let classicUsesSharedToolbarCornerRadius = true
  static let classicUsesOutlinedToolbarTreatment = true
  static let classicPreservesTerracottaFillAndWhiteText = true
  static let liquidGlassKeepsProminentLaunchTreatment = true
}

struct ScriptEditorSatelliteLaunchPanel: View {
  @Binding var state: ScriptEditorSatelliteLaunchPanelState
  let scripts: [ScriptMeta]
  let onLaunch: () -> Void
  let onCancel: () -> Void
  @State private var expandedManualSectionID: Int?
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  private var usesGlass: Bool { managerTheme.usesLiquidGlassMode }
  private var isDark: Bool { colorScheme == .dark }
  private var classicSecondary: Color {
    managerTheme.actionAccent(for: colorScheme)
  }
  private var classicPrimary: Color {
    managerTheme.actionAccent(for: colorScheme)
  }

  private var launchRequest: ScriptEditorSatelliteLaunchRequest {
    state.launchRequest(scripts: scripts)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header
      sections
      if let skippedSatelliteFeedbackMessage = launchRequest.skippedSatelliteFeedbackMessage {
        skipFeedback(message: skippedSatelliteFeedbackMessage)
      }
      actions
    }
    .padding(18)
    .frame(width: 420)
    .managerSurface(cornerRadius: 18, classicFill: Color("colorSurface"), strokeOpacity: 0.12)
    .shadow(color: .black.opacity(0.18), radius: 12, y: 8)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Cast with Pill Windows")
        .font(
          usesGlass
            ? .system(size: 20 * managerFontScale, weight: .bold)
            : .custom("Manrope-Bold", size: 20 * managerFontScale)
        )
        .foregroundStyle(usesGlass ? .primary : Color("colorText"))

      Text("Choose what each enabled Pill Window should show before launch.")
        .font(
          usesGlass
            ? .system(size: 14 * managerFontScale)
            : .custom("CrimsonText-Regular", size: 14 * managerFontScale)
        )
        .foregroundStyle(usesGlass ? .secondary : Color("colorMuted"))
    }
  }

  private var sections: some View {
    VStack(spacing: 12) {
      ForEach(state.sections.indices, id: \.self) { index in
        satelliteSectionView(for: index)
      }
    }
  }

  private var actions: some View {
    HStack {
      Spacer()

      Button("Cancel", action: onCancel)
        .buttonStyle(AiraWobblyToolbarButtonStyle(variant: .tertiary))
        .pointingHandCursor()

      Button("Launch", action: onLaunch)
        .buttonStyle(SatelliteLaunchPrimaryButtonStyle())
        .pointingHandCursor()
    }
  }

  private func skipFeedback(message: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(managerTheme.actionAccent(for: colorScheme))

      Text(message)
        .font(
          usesGlass
            ? .system(size: 13 * managerFontScale)
            : .custom("CrimsonText-Regular", size: 13 * managerFontScale)
        )
        .foregroundStyle(usesGlass ? .primary : Color("colorText"))
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      if usesGlass {
        ZStack {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial)
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(managerTheme.actionAccent(for: colorScheme).opacity(isDark ? 0.10 : 0.12))
        }
      } else {
        RoundedRectangle(cornerRadius: 12)
          .fill(managerTheme.controlFill(for: colorScheme))
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(
          managerTheme.actionAccent(for: colorScheme).opacity(usesGlass ? 0.30 : 0.24),
          lineWidth: usesGlass ? 0.5 : 1)
    )
  }

  @ViewBuilder
  private func satelliteSectionView(for index: Int) -> some View {
    let section = sectionBinding(for: index)

    VStack(alignment: .leading, spacing: 10) {
      Text(section.wrappedValue.title)
        .font(
          usesGlass
            ? .system(size: 15 * managerFontScale, weight: .semibold)
            : .custom("Manrope-Bold", size: 15 * managerFontScale)
        )
        .foregroundStyle(usesGlass ? .primary : Color("colorText"))

      HStack(spacing: 8) {
        ForEach(ScriptEditorSatelliteLaunchChoice.allCases, id: \.self) { choice in
          satelliteChoiceButton(choice: choice, section: section)
        }
      }

      if section.wrappedValue.choice == .manual {
        manualScriptPicker(for: section)
      }
    }
    .padding(12)
    .background {
      if usesGlass {
        ZStack {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
              isDark
                ? Color.white.opacity(0.04)
                : managerTheme.contentBackground(for: colorScheme).opacity(0.44))
        }
      } else {
        RoundedRectangle(cornerRadius: 14)
          .fill(managerTheme.controlFill(for: colorScheme))
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(
          usesGlass
            ? (isDark
              ? Color.white.opacity(0.12)
              : managerTheme.actionAccent(for: colorScheme).opacity(0.18))
            : Color("colorText").opacity(0.14),
          lineWidth: usesGlass ? 0.5 : 1
        )
    )
  }

  @ViewBuilder
  private func satelliteChoiceButton(
    choice: ScriptEditorSatelliteLaunchChoice,
    section: Binding<ScriptEditorSatelliteLaunchSection>
  ) -> some View {
    let isActive = section.wrappedValue.choice == choice
    let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

    Button {
      var updatedSection = section.wrappedValue
      updatedSection.choice = choice
      section.wrappedValue = updatedSection
      if choice != .manual && expandedManualSectionID == updatedSection.slotIndex {
        expandedManualSectionID = nil
      }
    } label: {
      Text(choice.title)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .contentShape(shape)
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity)
    .font(
      usesGlass
        ? .system(size: 14 * managerFontScale, weight: .medium)
        : .custom("CrimsonText-Regular", size: 14 * managerFontScale)
    )
    .foregroundStyle(choiceButtonForeground(isActive: isActive))
    .background { choiceButtonBackground(isActive: isActive) }
    .clipShape(shape)
    .overlay(shape.strokeBorder(choiceButtonStroke(isActive: isActive), lineWidth: 1))
    .contentShape(shape)
    .pointingHandCursor()
  }

  private func choiceButtonForeground(isActive: Bool) -> Color {
    if usesGlass {
      return isActive ? .white : .primary
    }
    return isActive ? Color.white : Color("colorText")
  }

  @ViewBuilder
  private func choiceButtonBackground(isActive: Bool) -> some View {
    let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
    if usesGlass {
      if isActive {
        shape
          .fill(managerTheme.actionAccent(for: colorScheme).opacity(isDark ? 0.48 : 0.76))
          .background(.ultraThinMaterial, in: shape)
      } else {
        ZStack {
          shape.fill(.ultraThinMaterial)
          shape.fill(
            isDark
              ? Color.white.opacity(0.06)
              : managerTheme.contentBackground(for: colorScheme).opacity(0.46))
        }
      }
    } else {
      shape.fill(
        isActive
          ? managerTheme.classicSelectedActionFill(for: colorScheme)
          : managerTheme.controlFill(for: colorScheme))
    }
  }

  private func choiceButtonStroke(isActive: Bool) -> Color {
    if usesGlass {
      return isActive
        ? managerTheme.actionAccent(for: colorScheme).opacity(isDark ? 0.45 : 0.60)
        : (isDark
          ? Color.white.opacity(0.15)
          : managerTheme.actionAccent(for: colorScheme).opacity(0.18))
    }
    return Color("colorText").opacity(0.12)
  }

  @ViewBuilder
  private func manualScriptPicker(for section: Binding<ScriptEditorSatelliteLaunchSection>)
    -> some View
  {
    if scripts.isEmpty {
      Text("Create or import a script before using Manual.")
        .font(.custom("CrimsonText-Regular", size: 13 * managerFontScale))
        .foregroundStyle(Color("colorMuted"))
    } else {
      VStack(alignment: .leading, spacing: 6) {
        Text("Script")
          .font(.custom("CrimsonText-Regular", size: 13 * managerFontScale))
          .foregroundStyle(Color("colorMuted"))

        Button {
          let sectionID = section.wrappedValue.slotIndex
          expandedManualSectionID = expandedManualSectionID == sectionID ? nil : sectionID
        } label: {
          HStack(spacing: 8) {
            Text(
              ScriptEditorSatelliteLaunchPanelState.manualScriptDropdownTitle(
                for: section.wrappedValue,
                scripts: scripts
              )
            )
            .lineLimit(1)

            Spacer()

            Image(
              systemName: expandedManualSectionID == section.wrappedValue.slotIndex
                ? "chevron.up" : "chevron.down"
            )
            .font(.system(size: 11, weight: .semibold))
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity)
          .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .font(.custom("CrimsonText-Regular", size: 14 * managerFontScale))
        .foregroundStyle(colorScheme == .dark ? Color.white : Color("colorText"))
        .background(
          RoundedRectangle(cornerRadius: 10)
            .fill(managerTheme.surfaceFill(for: colorScheme))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .stroke(Color("colorText").opacity(0.12), lineWidth: 1)
        )
        .pointingHandCursor()

        if expandedManualSectionID == section.wrappedValue.slotIndex {
          ScrollView {
            VStack(spacing: 6) {
              ForEach(sortedScripts) { script in
                manualScriptButton(script: script, section: section)
              }
            }
          }
          .frame(maxHeight: 180)
        }
      }
    }
  }

  private var sortedScripts: [ScriptMeta] {
    scripts.sorted { first, second in
      if first.lastEdited == second.lastEdited {
        return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
      }
      return first.lastEdited > second.lastEdited
    }
  }

  private func manualScriptButton(
    script: ScriptMeta,
    section: Binding<ScriptEditorSatelliteLaunchSection>
  ) -> some View {
    let isSelected = section.wrappedValue.selectedManualScriptID == script.id

    return Button {
      var updatedSection = section.wrappedValue
      updatedSection.selectedManualScriptID = script.id
      section.wrappedValue = updatedSection
      expandedManualSectionID = nil
    } label: {
      HStack(spacing: 8) {
        Text(script.title)
          .lineLimit(1)
        Spacer()
        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .semibold))
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity)
      .contentShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity)
    .font(.custom("CrimsonText-Regular", size: 14 * managerFontScale))
    .foregroundStyle(isSelected ? Color.white : Color("colorText"))
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(isSelected ? classicPrimary : managerTheme.surfaceFill(for: colorScheme))
    )
    .contentShape(RoundedRectangle(cornerRadius: 10))
    .pointingHandCursor()
  }

  private func sectionBinding(for index: Int)
    -> Binding<ScriptEditorSatelliteLaunchSection>
  {
    Binding(
      get: { state.sections[index] },
      set: { newSection in
        var panelState = state
        panelState.sections[index] = newSection
        _state.wrappedValue = panelState
      }
    )
  }
}

private struct SatelliteLaunchPrimaryButtonStyle: ButtonStyle {
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  private var usesGlass: Bool { managerTheme.usesLiquidGlassMode }
  private var isDark: Bool { colorScheme == .dark }
  private var classicSecondary: Color {
    managerTheme.actionAccent(for: colorScheme)
  }

  func makeBody(configuration: Configuration) -> some View {
    let pressed = configuration.isPressed
    let shape = RoundedRectangle(cornerRadius: usesGlass ? 10 : 8, style: .continuous)

    let opacity: Double =
      isDark
      ? (pressed ? 0.62 : 0.48)
      : (pressed ? 0.82 : 0.76)

    configuration.label
      .font(
        usesGlass
          ? .system(size: 15 * managerFontScale, weight: .medium)
          : .custom("IndieFlower", size: 15 * managerFontScale)
      )
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, usesGlass ? 8 : 10)
      .background {
        if usesGlass {
          shape
            .fill(managerTheme.actionAccent(for: colorScheme).opacity(opacity))
            .background(.ultraThinMaterial, in: shape)
        } else {
          shape.fill(managerTheme.classicSelectedActionFill(for: colorScheme, isPressed: pressed))
        }
      }
      .clipShape(shape)
      .overlay {
        shape.strokeBorder(
          usesGlass
            ? managerTheme.actionAccent(for: colorScheme).opacity(isDark ? 0.45 : 0.60)
            : Color.white.opacity(0.8),
          lineWidth: usesGlass ? 1 : 1.5
        )
      }
      .scaleEffect(pressed ? 0.96 : 1)
      .animation(.easeOut(duration: 0.15), value: pressed)
  }
}

private struct PointingHandCursorModifier: ViewModifier {
  @State private var isHovering = false

  func body(content: Content) -> some View {
    content
      .onHover { hovering in
        guard hovering != isHovering else { return }
        if hovering {
          NSCursor.pointingHand.push()
        } else {
          NSCursor.pop()
        }
        isHovering = hovering
      }
      .onDisappear {
        guard isHovering else { return }
        NSCursor.pop()
        isHovering = false
      }
  }
}

extension View {
  fileprivate func pointingHandCursor() -> some View {
    modifier(PointingHandCursorModifier())
  }
}

enum ScriptEditorMetrics {
  static func wordCount(for body: String) -> Int {
    body.split(whereSeparator: \.isWhitespace).count
  }
}

struct ScriptEditorPanel<Content: View>: View {
  let backgroundColor: Color
  @ViewBuilder var content: Content

  var body: some View {
    ZStack {
      Color.clear
        .managerSurface(
          cornerRadius: ManagerLayoutParity.scriptEditorPanelCornerRadius,
          classicFill: backgroundColor,
          strokeOpacity: 0.20
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

      content
        .padding(ManagerLayoutParity.scriptEditorPanelPadding)
    }
  }
}

struct ScriptTextEditor: NSViewRepresentable {
  @Environment(\.colorScheme) private var colorScheme
  @Binding var text: String
  @Binding var selectedRange: NSRange
  let isEditable: Bool
  let suppressInteractivity: Bool

  private var resolvedTextColor: NSColor {
    colorScheme == .dark ? .white : NSColor(Color("colorText"))
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text, selectedRange: $selectedRange)
  }

  static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
    (nsView.documentView as? NSTextView)?.delegate = nil
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.borderType = .noBorder
    scrollView.autohidesScrollers = true

    let textView = ScriptEditorNSTextView()
    textView.isRichText = false
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.allowsUndo = true
    textView.backgroundColor = .clear
    textView.drawsBackground = false
    textView.textColor = resolvedTextColor
    textView.insertionPointColor = resolvedTextColor
    textView.font = NSFont(name: "CrimsonText-Regular", size: 18) ?? .systemFont(ofSize: 18)
    textView.configureInteractivity(
      isEditable: isEditable,
      suppressInteractivity: suppressInteractivity
    )
    textView.isHorizontallyResizable = false
    textView.isVerticallyResizable = true
    textView.autoresizingMask = [.width]
    textView.textContainerInset = NSSize(width: 0, height: 2)
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = true
    textView.delegate = context.coordinator
    textView.string = text
    context.coordinator.applyCueStyling(to: textView)
    textView.selectedRange = selectedRange

    scrollView.documentView = textView
    context.coordinator.textView = textView
    return scrollView
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let textView = nsView.documentView as? ScriptEditorNSTextView else {
      return
    }

    context.coordinator.text = $text
    context.coordinator.selectedRange = $selectedRange
    textView.textColor = resolvedTextColor
    textView.insertionPointColor = suppressInteractivity ? .clear : resolvedTextColor
    textView.configureInteractivity(
      isEditable: isEditable,
      suppressInteractivity: suppressInteractivity
    )

    if textView.string != text {
      textView.string = text
      context.coordinator.applyCueStyling(to: textView)
    }

    if textView.selectedRange() != selectedRange {
      context.coordinator.isApplyingSelectionChange = true
      textView.setSelectedRange(selectedRange)
      context.coordinator.isApplyingSelectionChange = false
      textView.scrollRangeToVisible(selectedRange)
    }
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    var text: Binding<String>
    var selectedRange: Binding<NSRange>
    var isApplyingSelectionChange = false
    weak var textView: NSTextView?

    init(text: Binding<String>, selectedRange: Binding<NSRange>) {
      self.text = text
      self.selectedRange = selectedRange
    }

    func textDidChange(_ notification: Notification) {
      guard let textView else { return }
      text.wrappedValue = textView.string
      applyCueStyling(to: textView)
      selectedRange.wrappedValue = textView.selectedRange()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
      guard let textView else { return }
      guard isApplyingSelectionChange == false else { return }
      selectedRange.wrappedValue = textView.selectedRange()
    }

    func applyCueStyling(to textView: NSTextView) {
      guard let textStorage = textView.textStorage else { return }

      let selectedRange = textView.selectedRange()
      let baseFont = textView.font ?? .systemFont(ofSize: 18)
      let textColor = textView.textColor ?? NSColor(Color("colorText"))
      let cueTextColor = NSColor(Color("colorBackground"))
      let cueBackgroundColor = NSColor(Color("colorSecondary"))
      let baseAttributes: [NSAttributedString.Key: Any] = [
        .font: baseFont,
        .foregroundColor: textColor,
      ]
      let cueFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)

      isApplyingSelectionChange = true
      textStorage.beginEditing()
      textStorage.setAttributes(
        baseAttributes, range: NSRange(location: 0, length: textStorage.length))

      for range in ScriptEditorCueStyling.cueRanges(in: textView.string) {
        textStorage.addAttributes(
          [
            .font: cueFont,
            .foregroundColor: cueTextColor,
            .backgroundColor: cueBackgroundColor,
          ],
          range: range
        )
      }

      textStorage.endEditing()
      textView.setSelectedRange(selectedRange)
      textView.typingAttributes = ScriptEditorCueStyling.typingAttributes(
        forInsertionLocation: selectedRange.location,
        in: textView.string,
        baseAttributes: baseAttributes,
        cueAttributes: [
          .font: cueFont,
          .foregroundColor: cueTextColor,
          .backgroundColor: cueBackgroundColor,
        ]
      )
      isApplyingSelectionChange = false
    }
  }
}

final class ScriptEditorNSTextView: NSTextView {
  var suppressInteractivity = false {
    didSet {
      guard oldValue != suppressInteractivity else { return }
      if suppressInteractivity, window?.firstResponder === self {
        window?.makeFirstResponder(nil)
      }
      discardCursorRects()
      window?.invalidateCursorRects(for: self)
    }
  }

  func configureInteractivity(isEditable: Bool, suppressInteractivity: Bool) {
    self.suppressInteractivity = suppressInteractivity
    self.isEditable = isEditable && !suppressInteractivity
    isSelectable = !suppressInteractivity
    insertionPointColor =
      suppressInteractivity ? .clear : (textColor ?? NSColor(Color("colorText")))
  }

  override func resetCursorRects() {
    guard suppressInteractivity == false else {
      discardCursorRects()
      return
    }
    super.resetCursorRects()
  }

  override func cursorUpdate(with event: NSEvent) {
    guard suppressInteractivity == false else {
      NSCursor.arrow.set()
      return
    }
    super.cursorUpdate(with: event)
  }

  override func paste(_ sender: Any?) {
    guard
      isEditable,
      let pastedString = NSPasteboard.general.string(forType: .string),
      let transformed = ScriptEditorMarkdownPaste.normalizedTextIfMarkdown(pastedString)
    else {
      super.paste(sender)
      return
    }

    insertText(transformed, replacementRange: selectedRange())
  }
}

enum ScriptEditorCueStyling {
  static func cueRanges(in text: String) -> [NSRange] {
    let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
    let regex = try? NSRegularExpression(pattern: #"\[[^\]\r\n]+\]"#)
    return regex?.matches(in: text, range: nsRange).map(\.range) ?? []
  }

  static func applyCueAnnotationStyling(
    to attributedString: NSMutableAttributedString,
    baseFont: NSFont,
    textColor: NSColor,
    cueTextColor: NSColor,
    cueBackgroundColor: NSColor
  ) {
    let fullRange = NSRange(location: 0, length: attributedString.length)
    attributedString.setAttributes(
      [
        .font: baseFont,
        .foregroundColor: textColor,
      ],
      range: fullRange
    )

    let cueFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
    for range in cueRanges(in: attributedString.string) {
      attributedString.addAttributes(
        [
          .font: cueFont,
          .foregroundColor: cueTextColor,
          .backgroundColor: cueBackgroundColor,
        ],
        range: range
      )
    }
  }

  static func typingAttributes(
    forInsertionLocation location: Int,
    in text: String,
    baseAttributes: [NSAttributedString.Key: Any],
    cueAttributes: [NSAttributedString.Key: Any]
  ) -> [NSAttributedString.Key: Any] {
    for range in cueRanges(in: text) {
      if location > range.location && location < NSMaxRange(range) {
        return cueAttributes
      }
    }

    return baseAttributes
  }
}
