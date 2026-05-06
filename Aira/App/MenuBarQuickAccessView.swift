import AppKit
import SwiftUI

struct MenuBarQuickAccessView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.dismiss) private var dismiss
  let overlayController: OverlayWindowController
  @ObservedObject private var voiceSync: VoiceSyncEngine
  @State private var selectedScriptID: UUID?

  init(overlayController: OverlayWindowController) {
    self.overlayController = overlayController
    self._voiceSync = ObservedObject(wrappedValue: overlayController.voiceSync)
  }

  private var recentScripts: [ScriptMeta] {
    Array(appState.scripts.prefix(12))
  }

  private var featuredScript: ScriptMeta? {
    if let active = appState.activeScript,
      let meta = appState.scripts.first(where: { $0.id == active.id })
    {
      return meta
    }
    return recentScripts.first
  }

  private var selectedScript: ScriptMeta? {
    MenuBarScriptSelectionPresentation.selectedScript(
      recentScripts: recentScripts,
      selectedScriptID: selectedScriptID,
      fallbackScript: featuredScript
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Aira")
            .font(.custom("Manrope-Bold", size: 18))
            .foregroundStyle(Color("colorText"))
          Text(appState.sessionActive ? "Session live" : "Ready to cast")
            .font(.custom("CrimsonText-Regular", size: 14))
            .foregroundStyle(Color("colorText").opacity(0.6))
        }

        Spacer()

        Text(appState.sessionActive ? "LIVE" : "IDLE")
          .font(.custom("Inter-Regular", size: 11))
          .foregroundStyle(appState.sessionActive ? Color("colorBackground") : Color("colorText"))
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(appState.sessionActive ? Color("colorSecondary") : Color("colorSurface"))
          .clipShape(Capsule())
          .overlay(
            Capsule()
              .stroke(Color("colorText").opacity(0.08), lineWidth: 1)
          )
      }

      VStack(spacing: 10) {
        castButton(
          title: MenuBarScriptSelectionPresentation.castTitle(
            selectedScript: selectedScript,
            includesPills: false
          ),
          systemImage: "play.rectangle.fill",
          background: Color("colorSecondary"),
          action: castFeaturedScriptToNotch
        )

        castButton(
          title: MenuBarScriptSelectionPresentation.castTitle(
            selectedScript: selectedScript,
            includesPills: true
          ),
          systemImage: "rectangle.on.rectangle",
          background: Color("colorPrimary"),
          action: castFeaturedScriptToNotchWithPills
        )

        HStack(spacing: 10) {
          quickActionButton(
            title: "Open Editor",
            systemImage: "macwindow",
            background: Color("colorPrimary"),
            foreground: Color("colorBackground"),
            showsBorder: false,
            action: openManagerWindow
          )

          quickActionButton(
            title: MenuBarVoiceControlPresentation.title(isPausedByUser: voiceSync.isPausedByUser),
            systemImage: MenuBarVoiceControlPresentation.symbolName(
              isPausedByUser: voiceSync.isPausedByUser),
            background: Color("colorSurface"),
            foreground: Color("colorText"),
            showsBorder: true,
            action: toggleVoicePause
          )
          .opacity(voiceControlIsEnabled ? 1 : 0.55)
          .disabled(!voiceControlIsEnabled)

          quickActionButton(
            title: "End Session",
            systemImage: "stop.fill",
            background: Color("colorSurface"),
            foreground: Color("colorText"),
            showsBorder: true,
            action: endSession
          )
          .opacity(appState.sessionActive ? 1 : 0.55)
          .disabled(!appState.sessionActive)
        }
      }

      VStack(alignment: .leading, spacing: 10) {
        Text("Recent Scripts")
          .font(.custom("Manrope-Bold", size: 14))
          .foregroundStyle(Color("colorText"))

        if recentScripts.isEmpty {
          Text("No scripts yet. Open the manager to create your first one.")
            .font(.custom("CrimsonText-Regular", size: 14))
            .foregroundStyle(Color("colorText").opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
        } else {
          ScrollView {
            VStack(spacing: 10) {
              ForEach(recentScripts) { script in
                Button {
                  selectedScriptID = script.id
                } label: {
                  let isSelected = selectedScript?.id == script.id
                  HStack(spacing: 12) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                      .font(.system(size: 15, weight: .semibold))
                      .foregroundStyle(
                        isSelected
                          ? Color("colorSecondary") : Color("colorText").opacity(0.35))

                    VStack(alignment: .leading, spacing: 2) {
                      Text(script.title)
                        .font(.custom("CrimsonText-Regular", size: 15))
                        .foregroundStyle(Color("colorText"))
                        .lineLimit(1)
                      Text("\(script.wordCount) words")
                        .font(.custom("Inter-Regular", size: 11))
                        .foregroundStyle(Color("colorText").opacity(0.5))
                    }

                    Spacer()

                    Text(isSelected ? "Selected" : "Select")
                      .font(.custom("Inter-Regular", size: 11))
                      .foregroundStyle(
                        Color("colorText").opacity(isSelected ? 0.7 : 0.45))
                  }
                  .padding(.horizontal, 12)
                  .padding(.vertical, 10)
                  .background(
                    isSelected
                      ? Color("colorSecondary").opacity(0.14)
                      : Color("colorSurface")
                  )
                  .clipShape(RoundedRectangle(cornerRadius: 10))
                  .overlay(
                    RoundedRectangle(cornerRadius: 10)
                      .stroke(
                        isSelected
                          ? Color("colorSecondary").opacity(0.6)
                          : Color("colorText").opacity(0.07),
                        lineWidth: isSelected ? 1.5 : 1
                      )
                  )
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 10))
                .help("Select \(script.title)")
              }
            }
            .padding(.vertical, 2)
          }
          .frame(height: 226)
        }
      }
    }
    .padding(16)
    .frame(width: 330)
    .background(Color("colorBackground"))
    .onAppear(perform: ensureSelection)
    .onChange(of: appState.scripts.map(\.id)) { _, _ in
      ensureSelection()
    }
  }

  @ViewBuilder
  private func castButton(
    title: String,
    systemImage: String,
    background: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: systemImage)
          .font(.system(size: 14, weight: .semibold))
        Text(title)
          .lineLimit(1)
          .font(.custom("Inter-Regular", size: 13))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(background)
      .foregroundStyle(Color("colorBackground"))
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .disabled(selectedScript == nil)
    .opacity(selectedScript == nil ? 0.45 : 1)
    .help(title)
  }

  @ViewBuilder
  private func quickActionButton(
    title: String,
    systemImage: String,
    background: Color,
    foreground: Color,
    showsBorder: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: systemImage)
          .font(.system(size: 12, weight: .semibold))
        Text(title)
          .font(.custom("Inter-Regular", size: 12))
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 10)
      .padding(.vertical, 11)
      .background(background)
      .foregroundStyle(foreground)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color("colorText").opacity(showsBorder ? 0.08 : 0), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .help(title)
  }

  private func castFeaturedScriptToNotch() {
    guard let selectedScript else { return }
    castScriptToNotch(id: selectedScript.id, includePills: false)
  }

  private func castFeaturedScriptToNotchWithPills() {
    guard let selectedScript else { return }
    castScriptToNotch(id: selectedScript.id, includePills: true)
  }

  private func ensureSelection() {
    guard !recentScripts.isEmpty else {
      selectedScriptID = nil
      return
    }

    if let selectedScriptID, recentScripts.contains(where: { $0.id == selectedScriptID }) {
      return
    }

    selectedScriptID = featuredScript?.id
  }

  private func castScriptToNotch(id: UUID, includePills: Bool = false) {
    do {
      overlayController.appState = appState
      dismissMenuBarWindows()
      let script = try appState.loadScript(id: id)
      // Hide manager window and become accessory BEFORE presenting overlays —
      // switching policy after panels appear can cause macOS to hide them.
      hideManagerWindowIfNeeded()
      if includePills {
        overlayController.presentMirroredSatelliteSession(
          script: script,
          appearance: appState.settings.defaultOverlayAppearance,
          countdownDuration: appState.settings.countdownDuration,
          satelliteCount: appState.settings.maxPillCount,
          voiceSyncEnabled: appState.settings.voiceSyncEnabled,
          autoScrollWPM: ManualScrollConfiguration.clampedWPM(appState.settings.autoScrollWPM),
          voiceSyncMode: appState.settings.voiceSyncMode
        )
      } else {
        overlayController.presentSession(
          script: script,
          appearance: appState.settings.defaultOverlayAppearance,
          countdownDuration: appState.settings.countdownDuration,
          voiceSyncEnabled: appState.settings.voiceSyncEnabled,
          autoScrollWPM: ManualScrollConfiguration.clampedWPM(appState.settings.autoScrollWPM),
          voiceSyncMode: appState.settings.voiceSyncMode
        )
      }
      dismissMenuBarWindows()
    } catch {
      NSSound.beep()
    }
  }

  private func openManagerWindow() {
    closeMenuBarWindowsNow()

    Task { @MainActor in
      closeMenuBarWindowsNow()
      AppWindowCoordinator.restoreManagerWindow()
    }
  }

  private func toggleVoicePause() {
    guard voiceControlIsEnabled else { return }
    overlayController.voiceSync.togglePause()
  }

  private func endSession() {
    overlayController.endSession()
    dismissMenuBarWindows()
  }

  private func quitApplication() {
    dismissMenuBarWindows()
    NSApp.terminate(nil)
  }

  private var voiceControlIsEnabled: Bool {
    MenuBarVoiceControlPresentation.isEnabled(hasActiveSession: appState.sessionActive)
  }
  private func hideManagerWindowIfNeeded() {
    AppWindowCoordinator.hideManagerWindowForSession()
  }

  private var currentMenuBarWindow: NSWindow? {
    AppWindowCoordinator.currentTransientMenuBarWindow()
  }

  private func dismissMenuBarWindows() {
    closeMenuBarWindowsNow()

    Task { @MainActor in
      closeMenuBarWindowsNow()
    }
  }

  private func closeMenuBarWindowsNow() {
    dismiss()

    let currentWindow = currentMenuBarWindow
    AppWindowCoordinator.closeTransientMenuBarWindow(currentWindow)
    AppWindowCoordinator.closeAllTransientMenuBarWindows()
  }
}

enum MenuBarVoiceControlPresentation {
  static func isEnabled(hasActiveSession: Bool) -> Bool {
    hasActiveSession
  }

  static func title(isPausedByUser: Bool) -> String {
    isPausedByUser ? "Resume Voice" : "Pause Voice"
  }

  static func symbolName(isPausedByUser: Bool) -> String {
    isPausedByUser ? "play.fill" : "pause.fill"
  }
}

enum MenuBarScriptSelectionPresentation {
  static func selectedScript(
    recentScripts: [ScriptMeta],
    selectedScriptID: UUID?,
    fallbackScript: ScriptMeta?
  ) -> ScriptMeta? {
    if let selectedScriptID,
      let selectedScript = recentScripts.first(where: { $0.id == selectedScriptID })
    {
      return selectedScript
    }

    guard let fallbackScript,
      recentScripts.contains(where: { $0.id == fallbackScript.id })
    else {
      return recentScripts.first
    }

    return fallbackScript
  }

  static func castTitle(selectedScript: ScriptMeta?, includesPills: Bool) -> String {
    guard let selectedScript else {
      return includesPills ? "Cast to Notch + Pills" : "Cast to Notch"
    }

    return includesPills
      ? "Cast \(selectedScript.title) to Notch + Pills"
      : "Cast \(selectedScript.title) to Notch"
  }
}
