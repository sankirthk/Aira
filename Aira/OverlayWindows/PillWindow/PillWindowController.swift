import AppKit
import SwiftUI

class PillWindowController {
    private var panel: NSPanel?
    let mode: PillContentMode
    private(set) var scriptID: UUID?
    var currentAppearance: OverlayAppearance = .default
    var isStealthEnabled: Bool {
        panel?.sharingType == NSWindow.SharingType.none
    }

    init(mode: PillContentMode) {
        self.mode = mode
    }

    func present(script: Script, appearance: OverlayAppearance, countdownDuration: Int,
                 voiceSyncEnabled: Bool = true,
                 autoScrollWPM: Double = 0,
                 playheadCoordinator: SessionPlayheadCoordinator,
                 scrollCoordinator: SessionScrollCoordinator,
                 reportsPrimaryMetrics: Bool = false,
                 voiceSyncMode: VoiceSyncMode = .voice,
                 voiceSync: VoiceSyncEngine, audioMonitor: AudioLevelMonitor,
                 onClose: @escaping () -> Void) {
        currentAppearance = appearance
        scriptID = script.id

        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 180),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.sharingType = .none
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let content = PillContentView(
            script: script,
            appearance: appearance,
            countdownDuration: countdownDuration,
            voiceSyncEnabled: voiceSyncEnabled,
            autoScrollWPM: autoScrollWPM,
            playheadCoordinator: playheadCoordinator,
            scrollCoordinator: scrollCoordinator,
            reportsPrimaryMetrics: reportsPrimaryMetrics,
            mode: mode,
            voiceSyncMode: voiceSyncMode,
            voiceSync: voiceSync,
            audioMonitor: audioMonitor,
            onClose: onClose
        )
        panel.contentView = NSHostingView(rootView: content)

        // Position in the center of the main screen's visible frame.
        // Avoid panel.center() — it uses NSScreen.main which follows the key window
        // and can place the pill on a secondary monitor unexpectedly.
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame
        let pillWidth: CGFloat = 600
        let pillHeight: CGFloat = 180
        let x = screenFrame.midX - pillWidth / 2
        let y = screenFrame.midY - pillHeight / 2
        panel.setFrame(CGRect(x: x, y: y, width: pillWidth, height: pillHeight), display: false)

        panel.orderFrontRegardless()
        self.panel = panel
    }

    func close() {
        panel?.close()
        panel = nil
        scriptID = nil
    }
}
