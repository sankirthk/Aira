import AppKit
import Combine
import Foundation

struct PillLaunchPlan {
  let slotIndex: Int
  let mode: PillContentMode
  let script: Script
}

struct SatelliteLaunchSelection: Equatable {
  let slotIndex: Int
  let mode: PillContentMode
}

enum OverlaySessionLaunchIntent: Equatable {
  case notchOnly
  case mirroredSatellites(count: Int)
  case assignedSatellites([SatelliteLaunchSelection])

  var satelliteSelections: [SatelliteLaunchSelection] {
    switch self {
    case .notchOnly:
      return []
    case .mirroredSatellites(let count):
      guard count > 0 else { return [] }
      return (1...count).map { slotIndex in
        SatelliteLaunchSelection(slotIndex: slotIndex, mode: .voiceSync)
      }
    case .assignedSatellites(let selections):
      return selections
    }
  }

  var allowsNotchUndock: Bool {
    satelliteSelections.isEmpty
  }
}

enum PillLaunchPolicy {
  static func canLaunchPill(with script: Script) -> Bool {
    !script.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  static func resolvedLaunchPlans(
    for selections: [SatelliteLaunchSelection],
    fallbackScript: Script,
    loadScript: (UUID) -> Script?
  ) -> [PillLaunchPlan] {
    selections.compactMap { selection in
      guard
        let script = resolvedScript(
          for: selection.mode,
          fallbackScript: fallbackScript,
          loadScript: loadScript
        )
      else {
        return nil
      }
      guard canLaunchPill(with: script) else { return nil }
      return PillLaunchPlan(
        slotIndex: selection.slotIndex,
        mode: selection.mode,
        script: script
      )
    }
  }

  private static func resolvedScript(
    for mode: PillContentMode,
    fallbackScript: Script,
    loadScript: (UUID) -> Script?
  ) -> Script? {
    guard case .manual(let scriptID) = mode else {
      return fallbackScript
    }

    return loadScript(scriptID)
  }
}

/// Entry point for creating and managing all overlay windows for a session.
@MainActor
class OverlayWindowController {
  weak var appState: AppState? {
    didSet {
      bindAppState()
    }
  }
  private var notchController: NotchWindowController?
  private var pillControllers: [PillWindowController] = []
  private let sessionShortcutMonitor = KeyboardShortcutMonitor()
  private let voiceSyncKeyboardMonitor = VoiceSyncKeyboardMonitor()
  private var settingsCancellable: AnyCancellable?
  private var activationCancellable: AnyCancellable?

  let voiceSync = VoiceSyncEngine()
  let audioMonitor = AudioLevelMonitor()
  let playheadCoordinator = SessionPlayheadCoordinator()
  let scrollCoordinator = SessionScrollCoordinator()

  var hasActiveNotch: Bool {
    notchController != nil
  }

  var pillCount: Int {
    pillControllers.count
  }

  private var hasActiveOverlays: Bool {
    notchController != nil || !pillControllers.isEmpty
  }

  init() {
    voiceSync.audioLevelMonitor = audioMonitor
    activationCancellable = NotificationCenter.default.publisher(
      for: NSApplication.didBecomeActiveNotification
    )
    .sink { [weak self] _ in
      self?.startSessionKeyboardMonitorsIfNeeded()
    }
  }

  private func bindAppState() {
    settingsCancellable = appState?.$settings
      .sink { [weak self] settings in
        self?.notchController?.updateSessionBehavior(
          voiceSyncEnabled: settings.voiceSyncEnabled,
          spokenWordHighlightingEnabled: settings.spokenWordHighlightingEnabled,
          pauseOnHoverEnabled: settings.pauseOnHoverEnabled
        )
        self?.notchController?.updateSpokenWordHighlighting(
          enabled: settings.spokenWordHighlightingEnabled)
        for pillController in self?.pillControllers ?? [] {
          pillController.updateSessionBehavior(
            voiceSyncEnabled: settings.voiceSyncEnabled,
            spokenWordHighlightingEnabled: settings.spokenWordHighlightingEnabled,
            pauseOnHoverEnabled: settings.pauseOnHoverEnabled
          )
          pillController.updateSpokenWordHighlighting(
            enabled: settings.spokenWordHighlightingEnabled)
        }
      }
  }

  func presentSession(
    script: Script, appearance: OverlayAppearance,
    countdownDuration: Int, voiceSyncEnabled: Bool = true,
    autoScrollWPM: Double = 0,
    voiceSyncMode: VoiceSyncMode = .voice
  ) {
    presentSession(
      script: script,
      appearance: appearance,
      countdownDuration: countdownDuration,
      voiceSyncEnabled: voiceSyncEnabled,
      autoScrollWPM: autoScrollWPM,
      voiceSyncMode: voiceSyncMode,
      launchIntent: .notchOnly
    )
  }

  func presentMirroredSatelliteSession(
    script: Script,
    appearance: OverlayAppearance,
    countdownDuration: Int,
    satelliteCount: Int,
    voiceSyncEnabled: Bool = true,
    autoScrollWPM: Double = 0,
    voiceSyncMode: VoiceSyncMode = .voice
  ) {
    presentSession(
      script: script,
      appearance: appearance,
      countdownDuration: countdownDuration,
      voiceSyncEnabled: voiceSyncEnabled,
      autoScrollWPM: autoScrollWPM,
      voiceSyncMode: voiceSyncMode,
      launchIntent: .mirroredSatellites(count: satelliteCount)
    )
  }

  func presentAssignedSatelliteSession(
    script: Script, appearance: OverlayAppearance,
    countdownDuration: Int, voiceSyncEnabled: Bool = true,
    autoScrollWPM: Double = 0,
    voiceSyncMode: VoiceSyncMode = .voice,
    satelliteSelections: [SatelliteLaunchSelection]
  ) {
    presentSession(
      script: script,
      appearance: appearance,
      countdownDuration: countdownDuration,
      voiceSyncEnabled: voiceSyncEnabled,
      autoScrollWPM: autoScrollWPM,
      voiceSyncMode: voiceSyncMode,
      launchIntent: .assignedSatellites(satelliteSelections)
    )
  }

  private func presentSession(
    script: Script,
    appearance: OverlayAppearance,
    countdownDuration: Int,
    voiceSyncEnabled: Bool,
    autoScrollWPM: Double,
    voiceSyncMode: VoiceSyncMode,
    launchIntent: OverlaySessionLaunchIntent
  ) {
    let satelliteSelections = launchIntent.satelliteSelections
    let launchTrace = SessionLaunchTrace(label: "presentSession")
    launchTrace.mark("presentSession.begin")
    endSession()
    launchTrace.mark("presentSession.afterEndSession")
    prepareSharedSession(script: script)
    launchTrace.mark("presentSession.afterPrepareSharedSession")
    AiraLogger.shared.info(
      "Started session scriptId=\(script.id.uuidString) pills=\(satelliteSelections.count)",
      category: "session")

    // Launch notch window
    let notch = NotchWindowController()
    notch.present(
      script: script, appearance: appearance,
      notchWindowWidth: appState?.settings.notchWindowWidth ?? NotchWidthConfiguration.defaultWidth,
      notchWindowHeight: appState?.settings.notchWindowHeight
        ?? NotchHeightConfiguration.defaultHeight,
      countdownDuration: countdownDuration,
      voiceSyncEnabled: voiceSyncEnabled,
      spokenWordHighlightingEnabled: appState?.settings.spokenWordHighlightingEnabled ?? false,
      pauseOnHoverEnabled: appState?.settings.pauseOnHoverEnabled ?? true,
      autoScrollWPM: autoScrollWPM,
      screenCaptureExclusionEnabled: appState?.settings.screenCaptureExclusionEnabled ?? true,
      playheadCoordinator: playheadCoordinator,
      scrollCoordinator: scrollCoordinator,
      voiceSyncMode: voiceSyncMode,
      voiceSync: voiceSync, audioMonitor: audioMonitor,
      launchTrace: launchTrace,
      canUndock: launchIntent.allowsNotchUndock,
      onEndSession: { [weak self] in
        self?.endSession()
      })
    notchController = notch

    // Launch any pill windows
    let pillLaunchPlans = PillLaunchPolicy.resolvedLaunchPlans(
      for: satelliteSelections,
      fallbackScript: script,
      loadScript: { [weak self] scriptID in
        self?.loadScript(id: scriptID)
      }
    )

    for plan in pillLaunchPlans {
      let resolvedAppearance =
        appState?.settings.effectiveSatelliteAppearance(
          forSlot: plan.slotIndex, fallback: appearance)
        ?? appearance
      addPill(
        mode: plan.mode, script: plan.script, appearance: resolvedAppearance,
        countdownDuration: countdownDuration, voiceSyncEnabled: voiceSyncEnabled,
        spokenWordHighlightingEnabled: appState?.settings.spokenWordHighlightingEnabled ?? false,
        pauseOnHoverEnabled: appState?.settings.pauseOnHoverEnabled ?? true,
        autoScrollWPM: autoScrollWPM, voiceSyncMode: voiceSyncMode)
    }

    appState?.stealthWarning = !stealthIsHonored
    syncPresenterSessionState()
    startSessionKeyboardMonitorsIfNeeded()
  }

  @discardableResult
  func addPill(
    mode: PillContentMode, script: Script, appearance: OverlayAppearance,
    countdownDuration: Int, voiceSyncEnabled: Bool = true,
    spokenWordHighlightingEnabled: Bool = false,
    pauseOnHoverEnabled: Bool = true,
    autoScrollWPM: Double = 0, voiceSyncMode: VoiceSyncMode = .voice
  ) -> Bool {
    guard PillLaunchPolicy.canLaunchPill(with: script) else {
      AiraLogger.shared.info(
        "Skipped pill launch for empty scriptId=\(script.id.uuidString)",
        category: "overlay"
      )
      return false
    }

    if !hasActiveOverlays {
      prepareSharedSession(script: script)
    }

    let pill = PillWindowController(mode: mode)
    let usesPrimaryMetrics = notchController == nil && pillControllers.isEmpty
    pill.present(
      script: script, appearance: appearance,
      countdownDuration: countdownDuration,
      voiceSyncEnabled: voiceSyncEnabled,
      spokenWordHighlightingEnabled: spokenWordHighlightingEnabled,
      pauseOnHoverEnabled: pauseOnHoverEnabled,
      autoScrollWPM: autoScrollWPM,
      screenCaptureExclusionEnabled: appState?.settings.screenCaptureExclusionEnabled ?? true,
      playheadCoordinator: playheadCoordinator,
      scrollCoordinator: scrollCoordinator,
      reportsPrimaryMetrics: usesPrimaryMetrics,
      voiceSyncMode: voiceSyncMode,
      voiceSync: voiceSync, audioMonitor: audioMonitor,
      onClose: { [weak self, weak pill] in
        guard let self, let pill else { return }
        self.removePill(pill)
      },
      onSwapWithNotch: notchController == nil
        ? nil
        : { [weak self, weak pill] in
          guard let self, let pill else { return }
          self.swapManualPillScriptWithNotch(pill)
        })
    pillControllers.append(pill)
    notchController?.setCanUndock(false)
    AiraLogger.shared.info(
      "Added pill scriptId=\(script.id.uuidString) mode=\(String(describing: mode))",
      category: "overlay")
    appState?.stealthWarning = !stealthIsHonored
    syncPresenterSessionState()
    startSessionKeyboardMonitorsIfNeeded()
    return true
  }

  func endSession() {
    AiraLogger.shared.info(
      "Ended session notchActive=\(notchController != nil) pillCount=\(pillControllers.count)",
      category: "session"
    )
    voiceSync.stop()
    audioMonitor.reset()
    playheadCoordinator.endSession()
    scrollCoordinator.clearPrimaryMetrics()
    notchController?.close()
    notchController = nil
    for pillController in pillControllers {
      pillController.close()
    }
    pillControllers = []
    stopSessionKeyboardMonitors()
    appState?.setPresenterSessionState(isActive: false, scriptIDs: [])
  }

  func closeLastPill() {
    guard let pill = pillControllers.last else {
      return
    }
    removePill(pill)
  }

  func refreshSessionKeyboardMonitorsIfNeeded() {
    startSessionKeyboardMonitorsIfNeeded()
  }

  func updateScreenCaptureExclusion(enabled: Bool) {
    notchController?.updateScreenCaptureExclusion(enabled: enabled)
    for pillController in pillControllers {
      pillController.updateScreenCaptureExclusion(enabled: enabled)
    }
    appState?.stealthWarning = !stealthIsHonored
  }

  private var stealthIsHonored: Bool {
    let notchStealth = notchController?.isStealthEnabled ?? true
    let pillStealth = pillControllers.allSatisfy(\.isStealthEnabled)
    return notchStealth && pillStealth
  }

  private func removePill(_ pill: PillWindowController) {
    pill.close()
    pillControllers.removeAll { $0 === pill }
    AiraLogger.shared.info(
      "Removed pill remainingCount=\(pillControllers.count)", category: "overlay")
    notchController?.setCanUndock(pillControllers.isEmpty)
    appState?.stealthWarning = !stealthIsHonored
    if hasActiveOverlays {
      syncPresenterSessionState()
    } else {
      shutdownSharedSession()
    }
  }

  private func syncPresenterSessionState() {
    let scriptIDs = Set(
      ([notchController?.scriptID].compactMap { $0 }) + pillControllers.compactMap(\.scriptID)
    )
    appState?.setPresenterSessionState(isActive: !scriptIDs.isEmpty, scriptIDs: scriptIDs)
  }

  private func prepareSharedSession(script: Script) {
    voiceSync.loadScript(text: script.body)
    audioMonitor.sensitivity = appState?.settings.speechSensitivity ?? .medium
    audioMonitor.reset()
    playheadCoordinator.beginSession()
  }

  private func swapManualPillScriptWithNotch(_ pill: PillWindowController) {
    guard pill.mode != .voiceSync,
      let notchController,
      let notchScriptID = notchController.scriptID,
      let pillScriptID = pill.scriptID,
      let notchScript = loadScript(id: notchScriptID),
      let pillScript = loadScript(id: pillScriptID)
    else {
      return
    }

    voiceSync.loadScript(text: pillScript.body)
    audioMonitor.reset()
    playheadCoordinator.beginSession()
    scrollCoordinator.clearPrimaryMetrics()
    notchController.updateScript(pillScript)
    pill.updateScript(notchScript)
    syncPresenterSessionState()
  }

  private func loadScript(id: UUID) -> Script? {
    guard let appState else { return nil }

    do {
      return try appState.readScript(id: id)
    } catch {
      AiraLogger.shared.error(
        error, category: "overlay", context: "Failed to load script \(id.uuidString)")
      return nil
    }
  }

  private func shutdownSharedSession() {
    voiceSync.stop()
    audioMonitor.reset()
    playheadCoordinator.endSession()
    scrollCoordinator.clearPrimaryMetrics()
    stopSessionKeyboardMonitors()
    appState?.setPresenterSessionState(isActive: false, scriptIDs: [])
  }

  private func startSessionKeyboardMonitorsIfNeeded() {
    guard hasActiveOverlays, let appState else {
      stopSessionKeyboardMonitors()
      return
    }

    let settings = appState.settings
    sessionShortcutMonitor.start(
      bindings: [
        .init(shortcut: settings.shortcutEndSession) { [weak self] in
          self?.endSession()
        }
      ],
      promptForAccessibility: false
    )

    voiceSyncKeyboardMonitor.start(
      toggleShortcut: settings.shortcutToggleVoiceSync,
      scrollUpShortcut: settings.shortcutScrollUp,
      scrollDownShortcut: settings.shortcutScrollDown,
      promptForAccessibility: false,
      onToggle: { [weak self] in
        Task { @MainActor in
          self?.voiceSync.togglePause()
        }
      },
      onScrollUp: { [weak self] in
        Task { @MainActor in
          self?.voiceSync.requestManualLineNudge(direction: -1)
        }
      },
      onScrollDown: { [weak self] in
        Task { @MainActor in
          self?.voiceSync.requestManualLineNudge(direction: 1)
        }
      }
    )
  }

  private func stopSessionKeyboardMonitors() {
    sessionShortcutMonitor.stop()
    voiceSyncKeyboardMonitor.stop()
  }
}
