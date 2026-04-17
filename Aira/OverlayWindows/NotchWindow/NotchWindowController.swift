import AppKit
import SwiftUI

class NotchWindowController {
    private var panel: NSPanel?
    private(set) var scriptID: UUID?
    var currentAppearance: OverlayAppearance = .default
    private var defaultAppearance: OverlayAppearance = .default
    private var defaultWidth: Double = NotchWidthConfiguration.defaultWidth
    private var defaultHeight: Double = NotchHeightConfiguration.defaultHeight
    private var currentScript: Script?
    private var countdownDuration: Int = 0
    private var voiceSyncEnabled: Bool = true
    private var autoScrollWPM: Double = 0
    private var playheadCoordinator: SessionPlayheadCoordinator?
    private var scrollCoordinator: SessionScrollCoordinator?
    private var voiceSyncMode: VoiceSyncMode = .voice
    private var voiceSync: VoiceSyncEngine?
    private var audioMonitor: AudioLevelMonitor?
    private var onEndSession: (() -> Void)?
    var isStealthEnabled: Bool {
        panel?.sharingType == NSWindow.SharingType.none
    }

    func present(script: Script, appearance: OverlayAppearance, notchWindowWidth: Double,
                 notchWindowHeight: Double,
                 countdownDuration: Int,
                 voiceSyncEnabled: Bool = true, autoScrollWPM: Double = 0,
                 playheadCoordinator: SessionPlayheadCoordinator,
                 scrollCoordinator: SessionScrollCoordinator,
                 voiceSyncMode: VoiceSyncMode = .voice,
                 voiceSync: VoiceSyncEngine, audioMonitor: AudioLevelMonitor,
                 onEndSession: @escaping () -> Void) {
        currentAppearance = appearance
        currentScript = script
        defaultAppearance = .default
        scriptID = script.id
        defaultWidth = NotchWidthConfiguration.defaultWidth
        defaultHeight = NotchHeightConfiguration.defaultHeight
        self.countdownDuration = countdownDuration
        self.voiceSyncEnabled = voiceSyncEnabled
        self.autoScrollWPM = autoScrollWPM
        self.playheadCoordinator = playheadCoordinator
        self.scrollCoordinator = scrollCoordinator
        self.voiceSyncMode = voiceSyncMode
        self.voiceSync = voiceSync
        self.audioMonitor = audioMonitor
        self.onEndSession = onEndSession

        let screen = builtInScreen
        let notchSize = Self.notchSize(for: screen)
        let notchHeight = notchSize.height

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

        panel.contentView = NSHostingView(rootView: makeContentView(for: script, notchSize: notchSize))

        positionUnderNotch(
            panel: panel,
            screen: screen,
            notchHeight: notchHeight,
            appearance: appearance,
            notchWindowWidth: defaultWidth,
            notchWindowHeight: defaultHeight
        )

        panel.orderFrontRegardless()
        self.panel = panel

        // Verification is handled by OverlayWindowController so the manager can show a warning banner.
    }

    func close() {
        panel?.close()
        panel = nil
        currentScript = nil
        scriptID = nil
        resizeStartFrame = nil
        currentAppearance = .default
        defaultAppearance = .default
    }

    func updateScript(_ script: Script) {
        currentScript = script
        scriptID = script.id
        guard let panel else { return }
        let screen = panel.screen ?? builtInScreen
        let notchSize = Self.notchSize(for: screen)
        panel.contentView = NSHostingView(rootView: makeContentView(for: script, notchSize: notchSize))
    }

    /// Returns the built-in display. Never uses `NSScreen.main`, which tracks the
    /// key window and may be an external monitor.
    private var builtInScreen: NSScreen {
        Self.preferredBuiltInScreen()
    }

    static func preferredBuiltInScreen(from screens: [NSScreen] = NSScreen.screens) -> NSScreen {
        if let screen = screens.first(where: { hasPhysicalNotch(screen: $0) }) {
            return screen
        }
        let builtIn = screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                    as? CGDirectDisplayID else { return false }
            return CGDisplayIsBuiltin(id) != 0
        }
        return builtIn ?? screens[0]
    }

    static var builtInDisplayHasPhysicalNotch: Bool {
        hasPhysicalNotch(screen: preferredBuiltInScreen())
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

    static func hasPhysicalNotch(notchWidth: CGFloat, notchHeight: CGFloat) -> Bool {
        notchWidth > 0 && notchHeight > 0
    }

    static func notchSize(notchWidth: CGFloat, notchHeight: CGFloat) -> CGSize {
        guard hasPhysicalNotch(notchWidth: notchWidth, notchHeight: notchHeight) else {
            return .zero
        }
        return CGSize(width: notchWidth, height: notchHeight)
    }

    static func hasPhysicalNotch(screen: NSScreen) -> Bool {
        hasPhysicalNotch(
            notchWidth: physicalNotchWidth(screen: screen),
            notchHeight: screen.safeAreaInsets.top
        )
    }

    static func notchSize(for screen: NSScreen) -> CGSize {
        notchSize(
            notchWidth: physicalNotchWidth(screen: screen),
            notchHeight: screen.safeAreaInsets.top
        )
    }

    private func positionUnderNotch(panel: NSPanel, screen: NSScreen,
                                    notchHeight: CGFloat, appearance: OverlayAppearance,
                                    notchWindowWidth: Double,
                                    notchWindowHeight: Double) {
        let panelFrame = Self.defaultPanelFrame(
            screenFrame: screen.frame,
            notchHeight: notchHeight,
            appearance: appearance,
            preferredWidth: notchWindowWidth,
            preferredHeight: notchWindowHeight
        )
        panel.setFrame(panelFrame, display: true)
    }

    static func resolvedPanelWidth(_ preferredWidth: Double) -> CGFloat {
        CGFloat(NotchWidthConfiguration.clampedWidth(preferredWidth))
    }

    static func minimumPanelHeight(notchHeight: CGFloat, appearance: OverlayAppearance) -> CGFloat {
        max(
            CGFloat(NotchHeightConfiguration.minimumHeight),
            notchHeight * 3.5,
            appearance.fontSize * 4.2 + notchHeight + 24
        )
    }

    static func resolvedPanelHeight(_ preferredHeight: Double, notchHeight: CGFloat, appearance: OverlayAppearance) -> CGFloat {
        min(
            max(minimumPanelHeight(notchHeight: notchHeight, appearance: appearance), CGFloat(preferredHeight)),
            CGFloat(NotchHeightConfiguration.maximumHeight)
        )
    }

    static func defaultPanelFrame(
        screenFrame: CGRect,
        notchHeight: CGFloat,
        appearance: OverlayAppearance,
        preferredWidth: Double,
        preferredHeight: Double
    ) -> CGRect {
        let panelWidth = resolvedPanelWidth(preferredWidth)
        let panelHeight = resolvedPanelHeight(preferredHeight, notchHeight: notchHeight, appearance: appearance)
        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.maxY - panelHeight
        return CGRect(x: x, y: y, width: panelWidth, height: panelHeight)
    }

    static func resizedFrame(
        from startFrame: CGRect,
        edge: NotchResizeEdge,
        translation: CGSize,
        screenFrame: CGRect,
        notchHeight: CGFloat,
        appearance: OverlayAppearance
    ) -> CGRect {
        let minimumWidth = resolvedPanelWidth(NotchWidthConfiguration.minimumWidth)
        let maximumWidth = resolvedPanelWidth(NotchWidthConfiguration.maximumWidth)
        let minimumHeight = minimumPanelHeight(notchHeight: notchHeight, appearance: appearance)
        let maximumHeight = CGFloat(NotchHeightConfiguration.maximumHeight)

        var width = startFrame.width
        var height = startFrame.height

        if edge.affectsWidth {
            let delta = edge.widthMultiplier * translation.width * 2
            width = min(max(minimumWidth, startFrame.width + delta), maximumWidth)
        }

        if edge.affectsHeight {
            height = min(max(minimumHeight, startFrame.height + translation.height), maximumHeight)
        }

        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private var resizeStartFrame: CGRect?

    private func makeContentView(for script: Script, notchSize: CGSize) -> NotchContentView {
        NotchContentView(
            script: script,
            appearance: currentAppearance,
            countdownDuration: countdownDuration,
            voiceSyncEnabled: voiceSyncEnabled,
            autoScrollWPM: autoScrollWPM,
            playheadCoordinator: playheadCoordinator ?? SessionPlayheadCoordinator(),
            scrollCoordinator: scrollCoordinator ?? SessionScrollCoordinator(),
            reportsPrimaryMetrics: true,
            notchSize: notchSize,
            voiceSyncMode: voiceSyncMode,
            voiceSync: voiceSync ?? VoiceSyncEngine(),
            audioMonitor: audioMonitor ?? AudioLevelMonitor(),
            defaultAppearance: defaultAppearance,
            onEndSession: { [weak self] in
                self?.onEndSession?()
            },
            onAppearanceChange: { [weak self] updatedAppearance in
                self?.updateAppearance(updatedAppearance)
            },
            onResize: { [weak self] edge, translation in
                self?.resize(edge: edge, translation: translation)
            },
            onResizeEnd: { [weak self] in
                self?.endResize()
            },
            onResetDefaultSize: { [weak self] in
                self?.resetToDefaultSize()
            }
        )
    }

    private func updateAppearance(_ appearance: OverlayAppearance) {
        currentAppearance = appearance
        guard let panel, let screen = panel.screen ?? NSScreen.screens.first else {
            return
        }
        let frame = panel.frame
        let clampedHeight = max(frame.height, Self.minimumPanelHeight(notchHeight: screen.safeAreaInsets.top, appearance: appearance))
        panel.setFrame(
            CGRect(
                x: screen.frame.midX - frame.width / 2,
                y: screen.frame.maxY - clampedHeight,
                width: frame.width,
                height: min(clampedHeight, CGFloat(NotchHeightConfiguration.maximumHeight))
            ),
            display: true
        )
    }

    private func resetToDefaultSize() {
        guard let panel else { return }
        resizeStartFrame = nil
        let screen = panel.screen ?? builtInScreen
        positionUnderNotch(
            panel: panel,
            screen: screen,
            notchHeight: screen.safeAreaInsets.top,
            appearance: defaultAppearance,
            notchWindowWidth: defaultWidth,
            notchWindowHeight: defaultHeight
        )
    }

    private func resize(edge: NotchResizeEdge, translation: CGSize) {
        guard let panel else { return }
        let screen = panel.screen ?? builtInScreen
        let frame = resizeStartFrame ?? panel.frame
        if resizeStartFrame == nil {
            resizeStartFrame = frame
        }
        let newFrame = Self.resizedFrame(
            from: frame,
            edge: edge,
            translation: translation,
            screenFrame: screen.frame,
            notchHeight: screen.safeAreaInsets.top,
            appearance: currentAppearance
        )
        panel.setFrame(newFrame, display: true)
    }

    private func endResize() {
        resizeStartFrame = nil
    }
}

enum NotchResizeEdge {
    case leading
    case trailing
    case bottomLeading
    case bottom
    case bottomTrailing

    var affectsWidth: Bool {
        switch self {
        case .leading, .trailing, .bottomLeading, .bottomTrailing:
            return true
        case .bottom:
            return false
        }
    }

    var affectsHeight: Bool {
        switch self {
        case .bottomLeading, .bottom, .bottomTrailing:
            return true
        case .leading, .trailing:
            return false
        }
    }

    var widthMultiplier: CGFloat {
        switch self {
        case .leading, .bottomLeading:
            return -1
        case .trailing, .bottomTrailing:
            return 1
        case .bottom:
            return 0
        }
    }
}
