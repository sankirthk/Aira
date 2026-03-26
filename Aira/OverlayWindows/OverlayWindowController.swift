import Foundation

/// Entry point for creating and managing all overlay windows for a session.
@MainActor
class OverlayWindowController {
    weak var appState: AppState?
    private var notchController: NotchWindowController?
    private var pillControllers: [PillWindowController] = []

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
    }

    func presentSession(script: Script, appearance: OverlayAppearance,
                        countdownDuration: Int, voiceSyncEnabled: Bool = true,
                        autoScrollWPM: Double = 0,
                        voiceSyncMode: VoiceSyncMode = .voice,
                        pillModes: [PillContentMode] = []) {
        endSession()
        prepareSharedSession(script: script)

        // Launch notch window
        let notch = NotchWindowController()
        notch.present(script: script, appearance: appearance,
                      countdownDuration: countdownDuration,
                      voiceSyncEnabled: voiceSyncEnabled,
                      autoScrollWPM: autoScrollWPM,
                      playheadCoordinator: playheadCoordinator,
                      scrollCoordinator: scrollCoordinator,
                      voiceSyncMode: voiceSyncMode,
                      voiceSync: voiceSync, audioMonitor: audioMonitor,
                      onEndSession: { [weak self] in
                          self?.endSession()
                      })
        notchController = notch

        // Launch any pill windows
        for mode in pillModes {
            let pillScript = resolvedScript(for: mode, fallbackScript: script)
            addPill(mode: mode, script: pillScript, appearance: appearance,
                    countdownDuration: countdownDuration, voiceSyncEnabled: voiceSyncEnabled,
                    autoScrollWPM: autoScrollWPM, voiceSyncMode: voiceSyncMode)
        }

        appState?.stealthWarning = !stealthIsHonored
        syncPresenterSessionState()
    }

    func addPill(mode: PillContentMode, script: Script, appearance: OverlayAppearance,
                 countdownDuration: Int, voiceSyncEnabled: Bool = true,
                 autoScrollWPM: Double = 0, voiceSyncMode: VoiceSyncMode = .voice) {
        if !hasActiveOverlays {
            prepareSharedSession(script: script)
        }

        let pill = PillWindowController(mode: mode)
        let usesPrimaryMetrics = notchController == nil && pillControllers.isEmpty
        pill.present(script: script, appearance: appearance,
                     countdownDuration: countdownDuration,
                     voiceSyncEnabled: voiceSyncEnabled,
                     autoScrollWPM: autoScrollWPM,
                     playheadCoordinator: playheadCoordinator,
                     scrollCoordinator: scrollCoordinator,
                     reportsPrimaryMetrics: usesPrimaryMetrics,
                     voiceSyncMode: voiceSyncMode,
                     voiceSync: voiceSync, audioMonitor: audioMonitor,
                     onClose: { [weak self, weak pill] in
                         guard let self, let pill else { return }
                         self.removePill(pill)
                     })
        pillControllers.append(pill)
        appState?.stealthWarning = !stealthIsHonored
        syncPresenterSessionState()
    }

    func endSession() {
        voiceSync.stop()
        audioMonitor.reset()
        playheadCoordinator.endSession()
        scrollCoordinator.clearPrimaryMetrics()
        notchController?.close()
        notchController = nil
        pillControllers.forEach { $0.close() }
        pillControllers = []
        appState?.setPresenterSessionState(isActive: false, scriptIDs: [])
    }

    func closeLastPill() {
        guard let pill = pillControllers.last else {
            return
        }
        removePill(pill)
    }

    private var stealthIsHonored: Bool {
        let notchStealth = notchController?.isStealthEnabled ?? true
        let pillStealth = pillControllers.allSatisfy(\.isStealthEnabled)
        return notchStealth && pillStealth
    }

    private func resolvedScript(for mode: PillContentMode, fallbackScript: Script) -> Script {
        guard case .manual(let scriptID) = mode else {
            return fallbackScript
        }

        guard let appState else {
            return fallbackScript
        }

        do {
            return try appState.readScript(id: scriptID)
        } catch {
            return fallbackScript
        }
    }

    private func removePill(_ pill: PillWindowController) {
        pill.close()
        pillControllers.removeAll { $0 === pill }
        appState?.stealthWarning = !stealthIsHonored
        if hasActiveOverlays {
            syncPresenterSessionState()
        } else {
            shutdownSharedSession()
        }
    }

    private func syncPresenterSessionState() {
        let scriptIDs = Set(
            ([notchController?.scriptID].compactMap { $0 }) +
            pillControllers.compactMap(\.scriptID)
        )
        appState?.setPresenterSessionState(isActive: !scriptIDs.isEmpty, scriptIDs: scriptIDs)
    }

    private func prepareSharedSession(script: Script) {
        voiceSync.loadScript(text: script.body)
        audioMonitor.sensitivity = appState?.settings.speechSensitivity ?? .medium
        audioMonitor.reset()
        playheadCoordinator.beginSession()
    }

    private func shutdownSharedSession() {
        voiceSync.stop()
        audioMonitor.reset()
        playheadCoordinator.endSession()
        scrollCoordinator.clearPrimaryMetrics()
        appState?.setPresenterSessionState(isActive: false, scriptIDs: [])
    }
}
