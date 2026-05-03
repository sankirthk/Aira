import AppKit
import SwiftUI

@MainActor
class PillWindowController {
  private static let defaultFrameSize = CGSize(width: 600, height: 180)

  private var panel: NSPanel?
  private var hostingView: NSHostingView<PillContentView>?
  let mode: PillContentMode
  private(set) var scriptID: UUID?
  var currentAppearance: OverlayAppearance = .default
  private var defaultAppearance: OverlayAppearance = .default
  private var currentScript: Script?
  private var countdownDuration: Int = 0
  private var voiceSyncEnabled: Bool = true
  private var spokenWordHighlightingEnabled: Bool = false
  private var pauseOnHoverEnabled: Bool = true
  private var autoScrollWPM: Double = 0
  private var playheadCoordinator: SessionPlayheadCoordinator?
  private var scrollCoordinator: SessionScrollCoordinator?
  private var reportsPrimaryMetrics: Bool = false
  private var voiceSyncMode: VoiceSyncMode = .voice
  private var voiceSync: VoiceSyncEngine?
  private var audioMonitor: AudioLevelMonitor?
  private var onClose: (() -> Void)?
  private var onSwapWithNotch: (() -> Void)?
  private var screenCaptureExclusionEnabled: Bool = true
  private var restoredFrameAfterFullScreen: CGRect?
  private var isPseudoFullScreen: Bool = false
  var isStealthEnabled: Bool {
    guard let panel else {
      return OverlayStealthConfiguration.treatsConfiguredStateAsStealthSatisfied(
        screenCaptureExclusionEnabled: screenCaptureExclusionEnabled)
    }
    return panel.sharingType
      == OverlayStealthConfiguration.configuredSharingType(
        screenCaptureExclusionEnabled: screenCaptureExclusionEnabled)
  }

  init(mode: PillContentMode) {
    self.mode = mode
  }

  func present(
    script: Script, appearance: OverlayAppearance, countdownDuration: Int,
    voiceSyncEnabled: Bool = true,
    spokenWordHighlightingEnabled: Bool = false,
    pauseOnHoverEnabled: Bool = true,
    autoScrollWPM: Double = 0,
    screenCaptureExclusionEnabled: Bool = true,
    playheadCoordinator: SessionPlayheadCoordinator,
    scrollCoordinator: SessionScrollCoordinator,
    reportsPrimaryMetrics: Bool = false,
    voiceSyncMode: VoiceSyncMode = .voice,
    voiceSync: VoiceSyncEngine, audioMonitor: AudioLevelMonitor,
    onClose: @escaping () -> Void,
    onSwapWithNotch: (() -> Void)? = nil
  ) {
    currentAppearance = appearance
    defaultAppearance = appearance
    currentScript = script
    scriptID = script.id
    self.countdownDuration = countdownDuration
    self.voiceSyncEnabled = voiceSyncEnabled
    self.spokenWordHighlightingEnabled = spokenWordHighlightingEnabled
    self.pauseOnHoverEnabled = pauseOnHoverEnabled
    self.autoScrollWPM = autoScrollWPM
    self.screenCaptureExclusionEnabled = screenCaptureExclusionEnabled
    self.playheadCoordinator = playheadCoordinator
    self.scrollCoordinator = scrollCoordinator
    self.reportsPrimaryMetrics = reportsPrimaryMetrics
    self.voiceSyncMode = voiceSyncMode
    self.voiceSync = voiceSync
    self.audioMonitor = audioMonitor
    self.onClose = onClose
    self.onSwapWithNotch = onSwapWithNotch

    let panel = OverlayScrollForwardingPanel(
      contentRect: CGRect(origin: .zero, size: Self.defaultFrameSize),
      styleMask: [.borderless, .nonactivatingPanel, .resizable],
      backing: .buffered,
      defer: false
    )

    panel.sharingType = OverlayStealthConfiguration.configuredSharingType(
      screenCaptureExclusionEnabled: screenCaptureExclusionEnabled)
    panel.isFloatingPanel = true
    panel.level = .screenSaver
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.isMovableByWindowBackground = true
    panel.collectionBehavior = [
      .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
    ]

    let hostingView = NSHostingView(rootView: makeContentView(for: script))
    panel.contentView = hostingView

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
    self.hostingView = hostingView
  }

  func close() {
    panel?.contentView = nil
    panel?.orderOut(nil)
    panel?.close()
    panel = nil
    hostingView = nil
    currentScript = nil
    scriptID = nil
    currentAppearance = .default
    defaultAppearance = .default
    restoredFrameAfterFullScreen = nil
    isPseudoFullScreen = false
  }

  func updateScript(_ script: Script) {
    currentScript = script
    scriptID = script.id
    guard let hostingView else { return }
    hostingView.rootView = makeContentView(for: script)
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

  func toggleFullScreenIfAvailable() {
    guard let panel else {
      return
    }

    if isPseudoFullScreen {
      exitPseudoFullScreen(panel)
      return
    }

    guard let screen = panel.screen, Self.fullScreenAllowed(for: screen) else {
      return
    }

    enterPseudoFullScreen(panel, on: screen)
  }

  func updateScreenCaptureExclusion(enabled: Bool) {
    screenCaptureExclusionEnabled = enabled
    panel?.sharingType = OverlayStealthConfiguration.configuredSharingType(
      screenCaptureExclusionEnabled: enabled)
  }

  func updateSpokenWordHighlighting(enabled: Bool) {
    spokenWordHighlightingEnabled = enabled
    refreshContentView()
  }

  func updateSessionBehavior(
    voiceSyncEnabled: Bool,
    spokenWordHighlightingEnabled: Bool,
    pauseOnHoverEnabled: Bool
  ) {
    self.voiceSyncEnabled = voiceSyncEnabled
    self.spokenWordHighlightingEnabled = spokenWordHighlightingEnabled
    self.pauseOnHoverEnabled = pauseOnHoverEnabled
    refreshContentView()
  }

  static func fullScreenAllowed(
    for screen: NSScreen?,
    screens: [NSScreen] = NSScreen.screens
  ) -> Bool {
    guard
      let screen,
      let activeDisplayID = displayID(for: screen),
      let builtInDisplayID = displayID(
        for: NotchWindowController.preferredBuiltInScreen(from: screens))
    else {
      return false
    }

    return activeDisplayID != builtInDisplayID
  }

  private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
    screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
  }

  private func enterPseudoFullScreen(_ panel: NSPanel, on screen: NSScreen) {
    restoredFrameAfterFullScreen = panel.frame
    isPseudoFullScreen = true
    panel.hasShadow = false
    panel.isMovableByWindowBackground = false
    panel.setFrame(screen.frame, display: true, animate: true)
    refreshContentView()
  }

  private func exitPseudoFullScreen(_ panel: NSPanel) {
    let restoredFrame = restoredFrameAfterFullScreen ?? panel.frame
    restoredFrameAfterFullScreen = nil
    isPseudoFullScreen = false
    panel.setFrame(restoredFrame, display: true, animate: true)
    panel.hasShadow = true
    panel.isMovableByWindowBackground = true
    refreshContentView()
  }

  private func refreshContentView() {
    guard let currentScript, let hostingView else { return }
    hostingView.rootView = makeContentView(for: currentScript)
  }

  private func makeContentView(for script: Script) -> PillContentView {
    PillContentView(
      script: script,
      appearance: currentAppearance,
      countdownDuration: countdownDuration,
      voiceSyncEnabled: voiceSyncEnabled,
      spokenWordHighlightingEnabled: spokenWordHighlightingEnabled,
      pauseOnHoverEnabled: pauseOnHoverEnabled,
      autoScrollWPM: autoScrollWPM,
      playheadCoordinator: playheadCoordinator ?? SessionPlayheadCoordinator(),
      scrollCoordinator: scrollCoordinator ?? SessionScrollCoordinator(),
      reportsPrimaryMetrics: reportsPrimaryMetrics,
      mode: mode,
      isFullScreen: isPseudoFullScreen,
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
      onFullscreenToggle: { [weak self] in
        self?.toggleFullScreenIfAvailable()
      },
      defaultAppearance: defaultAppearance,
      onResetDefaultSize: { [weak self] in
        self?.resetToDefaultSize()
      }
    )
  }
}
