import AppKit
import SwiftUI

class NotchWindowController {
    private var panel: NSPanel?
    private(set) var scriptID: UUID?
    var currentAppearance: OverlayAppearance = .default
    var isStealthEnabled: Bool {
        panel?.sharingType == NSWindow.SharingType.none
    }

    func present(script: Script, appearance: OverlayAppearance, countdownDuration: Int,
                 voiceSyncEnabled: Bool = true, autoScrollWPM: Double = 0,
                 playheadCoordinator: SessionPlayheadCoordinator,
                 scrollCoordinator: SessionScrollCoordinator,
                 voiceSyncMode: VoiceSyncMode = .voice,
                 voiceSync: VoiceSyncEngine, audioMonitor: AudioLevelMonitor,
                 onEndSession: @escaping () -> Void) {
        currentAppearance = appearance
        scriptID = script.id

        let screen = builtInScreen
        let notchHeight = screen.safeAreaInsets.top
        let notchWidth = Self.physicalNotchWidth(screen: screen)
        let notchSize = CGSize(width: notchWidth, height: notchHeight)

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Stealth — exclude from all screen capture streams (REQ-005)
        panel.sharingType = .none

        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let content = NotchContentView(
            script: script,
            appearance: appearance,
            countdownDuration: countdownDuration,
            voiceSyncEnabled: voiceSyncEnabled,
            autoScrollWPM: autoScrollWPM,
            playheadCoordinator: playheadCoordinator,
            scrollCoordinator: scrollCoordinator,
            reportsPrimaryMetrics: true,
            notchSize: notchSize,
            voiceSyncMode: voiceSyncMode,
            voiceSync: voiceSync,
            audioMonitor: audioMonitor,
            onEndSession: onEndSession
        )
        panel.contentView = NSHostingView(rootView: content)

        positionUnderNotch(panel: panel, screen: screen, notchHeight: notchHeight, appearance: appearance)

        panel.orderFrontRegardless()
        self.panel = panel

        // Verification is handled by OverlayWindowController so the manager can show a warning banner.
    }

    func close() {
        panel?.close()
        panel = nil
        scriptID = nil
    }

    /// Returns the built-in display — the screen with the camera notch.
    /// Never uses NSScreen.main, which tracks the key window and may be an external monitor.
    private var builtInScreen: NSScreen {
        if let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return screen
        }
        let builtIn = NSScreen.screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                    as? CGDirectDisplayID else { return false }
            return CGDisplayIsBuiltin(id) != 0
        }
        return builtIn ?? NSScreen.screens[0]
    }

    /// Derives the physical notch width from the auxiliary menu-bar areas on each side.
    /// On macOS 12+, auxiliaryTopLeftArea and auxiliaryTopRightArea represent the usable
    /// menu-bar regions left and right of the camera housing. Their combined width subtracted
    /// from the screen width gives the exact physical notch width — no hardcoding required.
    /// Returns 0 on non-notched Macs (both auxiliary areas are nil).
    private static func physicalNotchWidth(screen: NSScreen) -> CGFloat {
        guard let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea else {
            return 0
        }
        return screen.frame.width - leftArea.width - rightArea.width
    }

    private func positionUnderNotch(panel: NSPanel, screen: NSScreen,
                                    notchHeight: CGFloat, appearance: OverlayAppearance) {
        // Panel height: tall enough to show readable text below the notch.
        // 3.5× the notch height guarantees the notch occupies the top ~29% of the panel,
        // leaving comfortable reading room beneath it on any Mac model.
        let panelHeight = max(notchHeight * 3.5, appearance.fontSize * 4.2 + notchHeight + 24)
        // Narrower than the old 460–520pt range to keep the reading column tight
        // and minimise visible eye movement during presentation.
        let panelWidth = min(max(320, appearance.fontSize * 14), 400)
        let x = screen.frame.midX - panelWidth / 2

        // Panel top must be flush with the top of the screen (screen.frame.maxY).
        // The NotchOverlayShape clips the physical notch cutout from within the panel —
        // offsetting below screen.frame.maxY would leave a visible gap above the overlay.
        let y = screen.frame.maxY - panelHeight
        panel.setFrame(CGRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }
}
