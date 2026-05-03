import AppKit
import SwiftUI

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
    let validManualScriptIDs = Set(
      scripts
        .filter { $0.wordCount > 0 }
        .map(\.id)
    )

    let satelliteSelections = sections.compactMap { section -> SatelliteLaunchSelection? in
      switch section.choice {
      case .mirrorCurrentScript:
        return SatelliteLaunchSelection(slotIndex: section.slotIndex, mode: .voiceSync)
      case .manual:
        guard let scriptID = section.selectedManualScriptID,
          validManualScriptIDs.contains(scriptID)
        else {
          return nil
        }
        return SatelliteLaunchSelection(
          slotIndex: section.slotIndex,
          mode: .manual(scriptId: scriptID)
        )
      }
    }

    return ScriptEditorSatelliteLaunchRequest(
      requestedSatelliteCount: sections.count,
      satelliteSelections: satelliteSelections
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

  var pillModes: [PillContentMode] {
    satelliteSelections.map(\.mode)
  }

  var skippedSatelliteCount: Int {
    max(0, requestedSatelliteCount - satelliteSelections.count)
  }

  var skippedSatelliteFeedbackMessage: String? {
    guard skippedSatelliteCount > 0 else { return nil }
    if skippedSatelliteCount == 1 {
      return "1 Pill Window will be skipped because it does not have a valid script."
    }
    return
      "\(skippedSatelliteCount) Pill Windows will be skipped because they do not have valid scripts."
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
  @Binding var script: Script
  @State private var saveErrorMessage: String?
  @State private var selectedRange = NSRange(location: 0, length: 0)
  @State private var isLaunchMenuPresented = false
  @State private var isSatelliteLaunchPanelPresented = false
  @State private var satelliteLaunchPanelState = ScriptEditorSatelliteLaunchPanelState(
    sections: []
  )
  let managerFontScale: CGFloat
  let isReadOnly: Bool
  var onCast: () -> Void
  var onCastWithSatellite: ([SatelliteLaunchSelection]) -> Void = { _ in }
  var onBack: () -> Void

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
            AiraIcon(type: .back, size: 20, color: Color("colorBackground"), animated: false)
              .padding(8)
              .background(Color.white.opacity(0.12))
              .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          .buttonStyle(.plain)

          TextField("Script title", text: $script.title)
            .font(.custom("Manrope-Bold", size: scaled(20)))
            .textFieldStyle(.plain)
            .foregroundStyle(Color("colorBackground"))
            .tint(Color("colorSecondary"))
            .disabled(isReadOnly)

          Spacer()

          Text(estimatedDuration)
            .font(.custom("Inter-Regular", size: scaled(13)))
            .foregroundStyle(Color("colorBackground").opacity(0.72))

          if isReadOnly {
            Text("Live script · read only")
              .font(.custom("CrimsonText-Regular", size: scaled(13)))
              .foregroundStyle(Color("colorBackground"))
          }

          Button {
            saveScript()
          } label: {
            HStack(spacing: 8) {
              AiraIcon(type: .save, size: 18, color: Color("colorText"), animated: false)
              Text("Save")
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
            }
          )
          .disabled(isReadOnly)
          .opacity(isReadOnly ? 0.55 : 1)
        }
        .padding(16)
        .background(Color("colorPrimary"))

        HStack(alignment: .top, spacing: 24) {
          ScriptEditorPanel(backgroundColor: Color("colorBackground")) {
            VStack(alignment: .leading, spacing: 0) {
              ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                  .fill(Color("colorBackground"))
                  .overlay(
                    RoundedRectangle(cornerRadius: 10)
                      .stroke(Color("colorText").opacity(0.2), lineWidth: 2)
                  )

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
                    .font(.custom("CrimsonText-Regular", size: scaled(18)))
                    .foregroundStyle(Color("colorText").opacity(0.4))
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
              .font(.custom("CrimsonText-Regular", size: scaled(15)))
              .foregroundStyle(Color("colorMuted"))
              .padding(.top, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .frame(maxWidth: .infinity, maxHeight: .infinity)

          CuePanelView(isReadOnly: isReadOnly, onInsertCue: insertCue)
            .frame(width: 320)
        }
        .background(Color("colorBackground"))
        .padding(24)
      }

      if isLaunchMenuPresented {
        Color.clear
          .contentShape(Rectangle())
          .ignoresSafeArea()
          .onTapGesture {
            isLaunchMenuPresented = false
            isSatelliteLaunchPanelPresented = false
          }

        ScriptEditorLaunchMenuPanel(
          actions: ScriptEditorLaunchMenuAction.defaultItems,
          onActionSelected: { action in
            isLaunchMenuPresented = false
            handleLaunchMenuAction(action.kind)
          }
        )
        .padding(.top, 58)
        .padding(.trailing, 16)
      }

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
  }

  private var saveErrorIsPresented: Binding<Bool> {
    Binding(
      get: { saveErrorMessage != nil },
      set: { isPresented in
        if isPresented == false {
          saveErrorMessage = nil
        }
      }
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

private struct ScriptEditorLaunchSplitButton: View {
  @Binding var isMenuPresented: Bool
  let onPrimaryPress: () -> Void
  @Environment(\.managerFontScale) private var managerFontScale

  private var cornerRadius: CGFloat { 7 }
  private var controlHeight: CGFloat { 44 }
  private var dividerHeight: CGFloat { 24 }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      HStack(spacing: 0) {
        Button {
          onPrimaryPress()
        } label: {
          HStack(spacing: 8) {
            AiraIcon(type: .notch, size: 18, color: .white, animated: false)
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
      }
      .frame(height: controlHeight)
      .font(.custom("IndieFlower", size: 15 * managerFontScale))
      .foregroundStyle(.white)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color("colorSecondary"))
      )
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
      .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
      .overlay(splitButtonBorder)
    }
    .frame(height: controlHeight)
  }

  private var splitButtonBorder: some View {
    RoundedRectangle(cornerRadius: cornerRadius)
      .inset(by: 2)
      .stroke(
        Color.white.opacity(0.8),
        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [2, 1])
      )
  }
}

private struct ScriptEditorLaunchMenuPanel: View {
  let actions: [ScriptEditorLaunchMenuAction]
  let onActionSelected: (ScriptEditorLaunchMenuAction) -> Void
  @Environment(\.managerFontScale) private var managerFontScale

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(actions) { action in
        Button {
          onActionSelected(action)
        } label: {
          HStack(spacing: 10) {
            Text(action.title)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 9)
          .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .font(.custom("CrimsonText-Regular", size: 15 * managerFontScale))
        .foregroundStyle(Color("colorText"))
        .background(
          RoundedRectangle(cornerRadius: 10)
            .fill(Color("colorBackground"))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .stroke(Color("colorText").opacity(0.12), lineWidth: 1)
        )
        .pointingHandCursor()
      }
    }
    .padding(8)
    .frame(width: 248)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(Color("colorSurface"))
        .overlay(
          RoundedRectangle(cornerRadius: 14)
            .stroke(Color("colorText"), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.16), radius: 10, y: 6)
    )
  }
}

private struct ScriptEditorSatelliteLaunchPanel: View {
  @Binding var state: ScriptEditorSatelliteLaunchPanelState
  let scripts: [ScriptMeta]
  let onLaunch: () -> Void
  let onCancel: () -> Void
  @State private var expandedManualSectionID: Int?
  @Environment(\.managerFontScale) private var managerFontScale

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
    .background(
      RoundedRectangle(cornerRadius: 18)
        .fill(Color("colorSurface"))
        .overlay(
          RoundedRectangle(cornerRadius: 18)
            .stroke(Color("colorText"), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 8)
    )
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Cast with Pill Windows")
        .font(.custom("Manrope-Bold", size: 20 * managerFontScale))
        .foregroundStyle(Color("colorText"))

      Text("Choose what each enabled Pill Window should show before launch.")
        .font(.custom("CrimsonText-Regular", size: 14 * managerFontScale))
        .foregroundStyle(Color("colorMuted"))
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
        .buttonStyle(AiraWobblyToolbarButtonStyle(variant: .secondary))
        .pointingHandCursor()
    }
  }

  private func skipFeedback(message: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color("colorSecondary"))

      Text(message)
        .font(.custom("CrimsonText-Regular", size: 13 * managerFontScale))
        .foregroundStyle(Color("colorText"))
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color("colorBackground"))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color("colorSecondary").opacity(0.24), lineWidth: 1)
    )
  }

  @ViewBuilder
  private func satelliteSectionView(for index: Int) -> some View {
    let section = sectionBinding(for: index)

    VStack(alignment: .leading, spacing: 10) {
      Text(section.wrappedValue.title)
        .font(.custom("Manrope-Bold", size: 15 * managerFontScale))
        .foregroundStyle(Color("colorText"))

      HStack(spacing: 8) {
        ForEach(ScriptEditorSatelliteLaunchChoice.allCases, id: \.self) { choice in
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
              .contentShape(RoundedRectangle(cornerRadius: 10))
          }
          .buttonStyle(.plain)
          .frame(maxWidth: .infinity)
          .font(.custom("CrimsonText-Regular", size: 14 * managerFontScale))
          .foregroundStyle(
            section.wrappedValue.choice == choice ? Color("colorBackground") : Color("colorText")
          )
          .background(
            RoundedRectangle(cornerRadius: 10)
              .fill(
                section.wrappedValue.choice == choice
                  ? Color("colorSecondary")
                  : Color("colorBackground")
              )
          )
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color("colorText").opacity(0.12), lineWidth: 1)
          )
          .contentShape(RoundedRectangle(cornerRadius: 10))
          .pointingHandCursor()
        }
      }

      if section.wrappedValue.choice == .manual {
        manualScriptPicker(for: section)
      }
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(Color("colorBackground"))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color("colorText").opacity(0.14), lineWidth: 1)
    )
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
        .foregroundStyle(Color("colorText"))
        .background(
          RoundedRectangle(cornerRadius: 10)
            .fill(Color("colorSurface"))
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
    .foregroundStyle(isSelected ? Color("colorBackground") : Color("colorText"))
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(isSelected ? Color("colorPrimary") : Color("colorSurface"))
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
      RoundedRectangle(cornerRadius: 12)
        .fill(backgroundColor)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color("colorText"), lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

      RoundedRectangle(cornerRadius: 10)
        .inset(by: 3)
        .stroke(
          Color("colorText").opacity(0.3),
          style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [4, 2])
        )

      content
        .padding(32)
    }
  }
}

struct ScriptTextEditor: NSViewRepresentable {
  @Binding var text: String
  @Binding var selectedRange: NSRange
  let isEditable: Bool
  let suppressInteractivity: Bool

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
    textView.textColor = NSColor(Color("colorText"))
    textView.insertionPointColor = NSColor(Color("colorText"))
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
      let textColor = NSColor(Color("colorText"))
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
    insertionPointColor = suppressInteractivity ? .clear : NSColor(Color("colorText"))
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
