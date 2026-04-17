import AppKit
import SwiftUI

class PillWindowController {
    private static let defaultFrameSize = CGSize(width: 600, height: 180)

    private var panel: NSPanel?
    let mode: PillContentMode
    private(set) var scriptID: UUID?
    var currentAppearance: OverlayAppearance = .default
    private let defaultAppearance: OverlayAppearance = .default
    private var currentScript: Script?
    private var countdownDuration: Int = 0
    private var voiceSyncEnabled: Bool = true
    private var autoScrollWPM: Double = 0
    private var playheadCoordinator: SessionPlayheadCoordinator?
    private var scrollCoordinator: SessionScrollCoordinator?
    private var reportsPrimaryMetrics: Bool = false
    private var voiceSyncMode: VoiceSyncMode = .voice
    private var voiceSync: VoiceSyncEngine?
    private var audioMonitor: AudioLevelMonitor?
    private var onClose: (() -> Void)?
    private var onSwapWithNotch: (() -> Void)?
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
                 onClose: @escaping () -> Void,
                 onSwapWithNotch: (() -> Void)? = nil) {
        currentAppearance = appearance
        currentScript = script
        scriptID = script.id
        self.countdownDuration = countdownDuration
        self.voiceSyncEnabled = voiceSyncEnabled
        self.autoScrollWPM = autoScrollWPM
        self.playheadCoordinator = playheadCoordinator
        self.scrollCoordinator = scrollCoordinator
        self.reportsPrimaryMetrics = reportsPrimaryMetrics
        self.voiceSyncMode = voiceSyncMode
        self.voiceSync = voiceSync
        self.audioMonitor = audioMonitor
        self.onClose = onClose
        self.onSwapWithNotch = onSwapWithNotch

        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: Self.defaultFrameSize),
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

        panel.contentView = NSHostingView(rootView: makeContentView(for: script))

        // Position in the center of the main screen's visible frame.
        // Avoid panel.center() — it uses NSScreen.main which follows the key window
        // and can place the pill on a secondary monitor unexpectedly.
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame
        let pillWidth = Self.defaultFrameSize.width
        let pillHeight = Self.defaultFrameSize.height
        let x = screenFrame.midX - pillWidth / 2
        let y = screenFrame.midY - pillHeight / 2
        panel.setFrame(CGRect(x: x, y: y, width: pillWidth, height: pillHeight), display: false)

        panel.orderFrontRegardless()
        self.panel = panel
    }

    func close() {
        panel?.close()
        panel = nil
        currentScript = nil
        scriptID = nil
    }

    func updateScript(_ script: Script) {
        currentScript = script
        scriptID = script.id
        guard let panel else { return }
        panel.contentView = NSHostingView(rootView: makeContentView(for: script))
    }

    func resetToDefaultSize() {
        guard let panel else { return }
        let currentFrame = panel.frame
        let centeredFrame = CGRect(
            x: currentFrame.midX - Self.defaultFrameSize.width / 2,
            y: currentFrame.midY - Self.defaultFrameSize.height / 2,
            width: Self.defaultFrameSize.width,
            height: Self.defaultFrameSize.height
        )
        panel.setFrame(centeredFrame, display: true, animate: true)
    }

    private func makeContentView(for script: Script) -> PillContentView {
        PillContentView(
            script: script,
            appearance: currentAppearance,
            countdownDuration: countdownDuration,
            voiceSyncEnabled: voiceSyncEnabled,
            autoScrollWPM: autoScrollWPM,
            playheadCoordinator: playheadCoordinator ?? SessionPlayheadCoordinator(),
            scrollCoordinator: scrollCoordinator ?? SessionScrollCoordinator(),
            reportsPrimaryMetrics: reportsPrimaryMetrics,
            mode: mode,
            voiceSyncMode: voiceSyncMode,
            voiceSync: voiceSync ?? VoiceSyncEngine(),
            audioMonitor: audioMonitor ?? AudioLevelMonitor(),
            onClose: { [weak self] in
                self?.onClose?()
            },
            onAppearanceChange: { [weak self] updatedAppearance in
                self?.currentAppearance = updatedAppearance
            },
            onSwapWithNotch: onSwapWithNotch,
            defaultAppearance: defaultAppearance,
            onResetDefaultSize: { [weak self] in
                self?.resetToDefaultSize()
            }
        )
    }
}
