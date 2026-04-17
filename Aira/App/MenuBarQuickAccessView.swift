import AppKit
import SwiftUI

struct MenuBarQuickAccessView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.dismiss) private var dismiss
  let overlayController: OverlayWindowController
  @ObservedObject private var voiceSync: VoiceSyncEngine

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
          title: featuredScript == nil ? "Cast to Notch" : "Cast \(featuredScript!.title) to Notch",
          systemImage: "play.rectangle.fill",
          background: Color("colorSecondary"),
          action: castFeaturedScriptToNotch
        )

        castButton(
          title: featuredScript == nil
            ? "Cast to Notch + Pills" : "Cast \(featuredScript!.title) to Notch + Pills",
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
                  castScriptToNotch(id: script.id)
                } label: {
                  HStack(spacing: 12) {
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

                    Image(systemName: "display")
                      .font(.system(size: 12, weight: .semibold))
                      .foregroundStyle(Color("colorSecondary"))
                  }
                  .padding(.horizontal, 12)
                  .padding(.vertical, 10)
                  .background(Color("colorSurface"))
                  .clipShape(RoundedRectangle(cornerRadius: 10))
                  .overlay(
                    RoundedRectangle(cornerRadius: 10)
                      .stroke(Color("colorText").opacity(0.07), lineWidth: 1)
                  )
                }
                .buttonStyle(.plain)
                .help("Cast \(script.title) to the notch")
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
    .disabled(featuredScript == nil)
    .opacity(featuredScript == nil ? 0.45 : 1)
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
    guard let featuredScript else { return }
    castScriptToNotch(id: featuredScript.id, includePills: false)
  }

  private func castFeaturedScriptToNotchWithPills() {
    guard let featuredScript else { return }
    castScriptToNotch(id: featuredScript.id, includePills: true)
  }

  private func castScriptToNotch(id: UUID, includePills: Bool = false) {
    do {
      overlayController.appState = appState
      dismissMenuBarWindows()
      let script = try appState.loadScript(id: id)
      // Hide manager window and become accessory BEFORE presenting overlays —
      // switching policy after panels appear can cause macOS to hide them.
      hideManagerWindowIfNeeded()
      overlayController.presentSession(
        script: script,
        appearance: appState.settings.defaultOverlayAppearance,
        countdownDuration: appState.settings.countdownDuration,
        voiceSyncEnabled: appState.settings.voiceSyncEnabled,
        autoScrollWPM: ManualScrollConfiguration.clampedWPM(appState.settings.autoScrollWPM),
        voiceSyncMode: appState.settings.voiceSyncMode,
        pillModes: includePills ? quickCastPillModes : enabledPillModes
      )
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

  private var enabledPillModes: [PillContentMode] {
    appState.settings.enabledPillModes
  }

  private var quickCastPillModes: [PillContentMode] {
    appState.settings.pillModes(forRequestedCount: max(appState.settings.maxPillCount, 1))
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
