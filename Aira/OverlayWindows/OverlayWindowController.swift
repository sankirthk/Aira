import Foundation

/// Entry point for creating and managing all overlay windows for a session.
@MainActor
class OverlayWindowController {
    weak var appState: AppState?
    private var notchController: NotchWindowController?
    private var pillControllers: [PillWindowController] = []
    private let sessionShortcutMonitor = KeyboardShortcutMonitor()
    private let voiceSyncKeyboardMonitor = VoiceSyncKeyboardMonitor()

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
        AiraLogger.shared.info("Started session scriptId=\(script.id.uuidString) pills=\(pillModes.count)", category: "session")

        // Launch notch window
        let notch = NotchWindowController()
        notch.present(script: script, appearance: appearance,
                      notchWindowWidth: appState?.settings.notchWindowWidth ?? NotchWidthConfiguration.defaultWidth,
                      notchWindowHeight: appState?.settings.notchWindowHeight ?? NotchHeightConfiguration.defaultHeight,
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
        startSessionKeyboardMonitorsIfNeeded()
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
                     },
                     onSwapWithNotch: notchController == nil ? nil : { [weak self, weak pill] in
                         guard let self, let pill else { return }
                         self.swapManualPillScriptWithNotch(pill)
                     })
        pillControllers.append(pill)
        AiraLogger.shared.info("Added pill scriptId=\(script.id.uuidString) mode=\(String(describing: mode))", category: "overlay")
        appState?.stealthWarning = !stealthIsHonored
        syncPresenterSessionState()
        startSessionKeyboardMonitorsIfNeeded()
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
        pillControllers.forEach { $0.close() }
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
            AiraLogger.shared.error(error, category: "overlay", context: "Failed to load manual pill script \(scriptID.uuidString)")
            return fallbackScript
        }
    }

    private func removePill(_ pill: PillWindowController) {
        pill.close()
        pillControllers.removeAll { $0 === pill }
        AiraLogger.shared.info("Removed pill remainingCount=\(pillControllers.count)", category: "overlay")
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

    private func swapManualPillScriptWithNotch(_ pill: PillWindowController) {
        guard pill.mode != .voiceSync,
              let notchController,
              let notchScriptID = notchController.scriptID,
              let pillScriptID = pill.scriptID,
              let notchScript = loadScript(id: notchScriptID),
              let pillScript = loadScript(id: pillScriptID) else {
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
            AiraLogger.shared.error(error, category: "overlay", context: "Failed to load script \(id.uuidString)")
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
        sessionShortcutMonitor.start(bindings: [
            .init(shortcut: settings.shortcutEndSession) { [weak self] in
                self?.endSession()
            }
        ])

        voiceSyncKeyboardMonitor.start(
            toggleShortcut: settings.shortcutToggleVoiceSync,
            scrollUpShortcut: settings.shortcutScrollUp,
            scrollDownShortcut: settings.shortcutScrollDown,
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
