import AppKit
import SwiftUI

class NotchWindowController: NSObject, NSWindowDelegate {
  private var panel: NSPanel?
  private var hostingView: NSHostingView<NotchContentView>?
  private(set) var scriptID: UUID?
  var currentAppearance: OverlayAppearance = .default
  private var defaultAppearance: OverlayAppearance = .default
  private var defaultWidth: Double = NotchWidthConfiguration.defaultWidth
  private var defaultHeight: Double = NotchHeightConfiguration.defaultHeight
  private var currentScript: Script?
  private var countdownDuration: Int = 0
  private var voiceSyncEnabled: Bool = true
  private var spokenWordHighlightingEnabled: Bool = false
  private var pauseOnHoverEnabled: Bool = true
  private var autoScrollWPM: Double = 0
  private var playheadCoordinator: SessionPlayheadCoordinator?
  private var scrollCoordinator: SessionScrollCoordinator?
  private var voiceSyncMode: VoiceSyncMode = .voice
  private var voiceSync: VoiceSyncEngine?
  private var audioMonitor: AudioLevelMonitor?
  private var launchTrace: SessionLaunchTrace?
  private var onEndSession: (() -> Void)?
  private var screenCaptureExclusionEnabled: Bool = true
  private var canUndock: Bool = true
  private var isUndocked: Bool = false
  private var isUndockedFullScreen: Bool = false
  private var lastUndockedFrame: CGRect?
  private var restoredFrameAfterFullScreen: CGRect?
  private let undockedMinimumSize = CGSize(width: 360, height: 120)
  @MainActor
  var isStealthEnabled: Bool {
    guard let panel else {
      return OverlayStealthConfiguration.treatsConfiguredStateAsStealthSatisfied(
        screenCaptureExclusionEnabled: screenCaptureExclusionEnabled)
    }
    return panel.sharingType
      == OverlayStealthConfiguration.configuredSharingType(
        screenCaptureExclusionEnabled: screenCaptureExclusionEnabled)
  }

  @MainActor
  func present(
    script: Script, appearance: OverlayAppearance, notchWindowWidth: Double,
    notchWindowHeight: Double,
    countdownDuration: Int,
    voiceSyncEnabled: Bool = true, spokenWordHighlightingEnabled: Bool = false,
    pauseOnHoverEnabled: Bool = true, autoScrollWPM: Double = 0,
    screenCaptureExclusionEnabled: Bool = true,
    playheadCoordinator: SessionPlayheadCoordinator,
    scrollCoordinator: SessionScrollCoordinator,
    voiceSyncMode: VoiceSyncMode = .voice,
    voiceSync: VoiceSyncEngine, audioMonitor: AudioLevelMonitor,
    launchTrace: SessionLaunchTrace? = nil,
    canUndock: Bool = true,
    onEndSession: @escaping () -> Void
  ) {
    launchTrace?.mark("notch.present.begin")
    currentAppearance = appearance
    currentScript = script
    defaultAppearance = .default
    scriptID = script.id
    defaultWidth = NotchWidthConfiguration.clampedWidth(notchWindowWidth)
    defaultHeight = NotchHeightConfiguration.clampedHeight(notchWindowHeight)
    self.countdownDuration = countdownDuration
    self.voiceSyncEnabled = voiceSyncEnabled
    self.spokenWordHighlightingEnabled = spokenWordHighlightingEnabled
    self.pauseOnHoverEnabled = pauseOnHoverEnabled
    self.autoScrollWPM = autoScrollWPM
    self.screenCaptureExclusionEnabled = screenCaptureExclusionEnabled
    self.playheadCoordinator = playheadCoordinator
    self.scrollCoordinator = scrollCoordinator
    self.voiceSyncMode = voiceSyncMode
    self.voiceSync = voiceSync
    self.audioMonitor = audioMonitor
    self.launchTrace = launchTrace
    self.canUndock = canUndock
    self.isUndocked = false
    self.isUndockedFullScreen = false
    self.lastUndockedFrame = nil
    self.restoredFrameAfterFullScreen = nil
    self.onEndSession = onEndSession

    let screen = builtInScreen
    launchTrace?.mark("notch.screenResolved")
    let notchSize = Self.notchSize(for: screen)
    let notchHeight = notchSize.height

    let panel = OverlayScrollForwardingPanel(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel, .resizable],
      backing: .buffered,
      defer: false
    )
    launchTrace?.mark("notch.panelCreated")

    panel.sharingType = OverlayStealthConfiguration.configuredSharingType(
      screenCaptureExclusionEnabled: screenCaptureExclusionEnabled)

    panel.isFloatingPanel = true
    panel.level = .screenSaver
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    panel.delegate = self

    let hostingView = NSHostingView(rootView: makeContentView(for: script, notchSize: notchSize))
    launchTrace?.mark("notch.hostingViewCreated")
    panel.contentView = hostingView
    updateWindowInteractionState(for: panel)

    positionUnderNotch(
      panel: panel,
      screen: screen,
      notchHeight: notchHeight,
      appearance: appearance,
      notchWindowWidth: defaultWidth,
      notchWindowHeight: defaultHeight
    )

    panel.orderFrontRegardless()
    launchTrace?.mark("notch.orderedFront")
    self.panel = panel
    self.hostingView = hostingView

    // Verification is handled by OverlayWindowController so the manager can show a warning banner.
  }

  @MainActor
  func close() {
    panel?.contentView = nil
    panel?.orderOut(nil)
    panel?.close()
    panel = nil
    hostingView = nil
    currentScript = nil
    scriptID = nil
    resizeStartFrame = nil
    currentAppearance = .default
    defaultAppearance = .default
    launchTrace = nil
    canUndock = true
    isUndocked = false
    isUndockedFullScreen = false
    lastUndockedFrame = nil
    restoredFrameAfterFullScreen = nil
  }

  @MainActor
  func updateScript(_ script: Script) {
    currentScript = script
    scriptID = script.id
    refreshContentView()
  }

  @MainActor
  func updateScreenCaptureExclusion(enabled: Bool) {
    screenCaptureExclusionEnabled = enabled
    panel?.sharingType = OverlayStealthConfiguration.configuredSharingType(
      screenCaptureExclusionEnabled: enabled)
  }

  @MainActor
  func setCanUndock(_ canUndock: Bool) {
    guard self.canUndock != canUndock else { return }
    self.canUndock = canUndock
    refreshContentView()
  }

  @MainActor
  func updateSpokenWordHighlighting(enabled: Bool) {
    spokenWordHighlightingEnabled = enabled
    refreshContentView()
  }

  @MainActor
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

  /// Returns the built-in display. Never uses `NSScreen.main`, which tracks the
  /// key window and may be an external monitor.
  @MainActor
  private var builtInScreen: NSScreen {
    Self.preferredBuiltInScreen()
  }

  static func preferredBuiltInScreen(from screens: [NSScreen] = NSScreen.screens) -> NSScreen {
    if let screen = screens.first(where: { hasPhysicalNotch(screen: $0) }) {
      return screen
    }
    let builtIn = screens.first { screen in
      guard
        let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
          as? CGDirectDisplayID
      else { return false }
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
      let rightArea = screen.auxiliaryTopRightArea
    else {
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

  @MainActor
  private func positionUnderNotch(
    panel: NSPanel, screen: NSScreen,
    notchHeight: CGFloat, appearance: OverlayAppearance,
    notchWindowWidth: Double,
    notchWindowHeight: Double
  ) {
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

  static func resolvedPanelHeight(
    _ preferredHeight: Double, notchHeight: CGFloat, appearance: OverlayAppearance
  ) -> CGFloat {
    min(
      max(
        minimumPanelHeight(notchHeight: notchHeight, appearance: appearance),
        CGFloat(preferredHeight)),
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
    let panelHeight = resolvedPanelHeight(
      preferredHeight, notchHeight: notchHeight, appearance: appearance)
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
      let delta = edge.widthMultiplier * translation.width
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

  @MainActor
  private func makeContentView(for script: Script, notchSize: CGSize) -> NotchContentView {
    NotchContentView(
      script: script,
      appearance: currentAppearance,
      countdownDuration: countdownDuration,
      voiceSyncEnabled: voiceSyncEnabled,
      spokenWordHighlightingEnabled: spokenWordHighlightingEnabled,
      pauseOnHoverEnabled: pauseOnHoverEnabled,
      autoScrollWPM: autoScrollWPM,
      playheadCoordinator: playheadCoordinator ?? SessionPlayheadCoordinator(),
      scrollCoordinator: scrollCoordinator ?? SessionScrollCoordinator(),
      reportsPrimaryMetrics: true,
      isDocked: !isUndocked,
      canUndock: canUndock,
      isFullScreen: isUndockedFullScreen,
      notchSize: notchSize,
      voiceSyncMode: voiceSyncMode,
      voiceSync: voiceSync ?? VoiceSyncEngine(),
      audioMonitor: audioMonitor ?? AudioLevelMonitor(),
      launchTrace: launchTrace,
      defaultAppearance: defaultAppearance,
      onDockToggle: { [weak self] in
        self?.toggleDocking()
      },
      onFullscreenToggle: { [weak self] in
        self?.toggleUndockedFullScreen()
      },
      onPauseToggle: { [weak self] in
        self?.voiceSync?.togglePause()
      },
      onEndSession: { [weak self] in
        self?.onEndSession?()
      },
      onAppearanceChange: { [weak self] updatedAppearance in
        self?.updateAppearance(updatedAppearance)
      },
      onResize: { [weak self] edge, translation in
        self?.resize(edge: edge, translation: translation)
      },
      onFloatingResize: { [weak self] edge, translation in
        self?.resizeUndocked(edge: edge, translation: translation)
      },
      onResizeEnd: { [weak self] in
        self?.endResize()
      },
      onResetDefaultSize: { [weak self] in
        self?.resetToDefaultSize()
      }
    )
  }

  @MainActor
  private func updateAppearance(_ appearance: OverlayAppearance) {
    currentAppearance = appearance
    guard let panel, let screen = panel.screen ?? NSScreen.screens.first else {
      return
    }
    let frame = panel.frame

    if isUndocked {
      let minimumHeight = max(CGFloat(120), appearance.fontSize * 4.2 + 24)
      let clampedHeight = max(frame.height, minimumHeight)
      let clampedFrame = CGRect(
        x: frame.minX,
        y: frame.maxY - clampedHeight,
        width: frame.width,
        height: clampedHeight
      )
      lastUndockedFrame = clampedFrame
      panel.setFrame(clampedFrame, display: true)
      return
    }

    let clampedHeight = max(
      frame.height,
      Self.minimumPanelHeight(notchHeight: screen.safeAreaInsets.top, appearance: appearance))
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

  @MainActor
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

  @MainActor
  private func resize(edge: NotchResizeEdge, translation: CGSize) {
    guard let panel, !isUndocked else { return }
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

  @MainActor
  private func endResize() {
    resizeStartFrame = nil
  }

  @MainActor
  private func toggleDocking() {
    guard let panel else { return }

    if isUndocked {
      if isUndockedFullScreen {
        let restoredFrame = restoredFrameAfterFullScreen ?? lastUndockedFrame ?? panel.frame
        lastUndockedFrame = restoredFrame
        restoredFrameAfterFullScreen = nil
        isUndockedFullScreen = false
      }
      updateWindowInteractionState(for: panel, isUndocked: false, isUndockedFullScreen: false)
      let screen = builtInScreen
      let targetFrame = Self.defaultPanelFrame(
        screenFrame: screen.frame,
        notchHeight: screen.safeAreaInsets.top,
        appearance: currentAppearance,
        preferredWidth: defaultWidth,
        preferredHeight: defaultHeight
      )
      NSAnimationContext.runAnimationGroup(
        { context in
          context.duration = 0.22
          context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
          panel.animator().setFrame(targetFrame, display: true)
        },
        completionHandler: { [weak self] in
          guard let self else { return }
          Task { @MainActor [weak self] in
            guard let self else { return }
            self.isUndocked = false
            panel.hasShadow = false
            self.refreshContentView()
          }
        }
      )
      return
    }

    guard canUndock else { return }
    isUndocked = true
    isUndockedFullScreen = false
    let startFrame = lastUndockedFrame ?? panel.frame
    panel.hasShadow = true
    updateWindowInteractionState(for: panel, isUndocked: true, isUndockedFullScreen: false)
    panel.setFrame(startFrame, display: true, animate: true)
    refreshContentView()
  }

  @MainActor
  private func toggleUndockedFullScreen() {
    guard let panel, isUndocked else { return }
    if isUndockedFullScreen {
      exitUndockedFullScreen(panel)
      return
    }
    guard let screen = panel.screen else { return }
    enterUndockedFullScreen(panel, on: screen)
  }

  @MainActor
  private func enterUndockedFullScreen(_ panel: NSPanel, on screen: NSScreen) {
    restoredFrameAfterFullScreen = panel.frame
    lastUndockedFrame = panel.frame
    isUndockedFullScreen = true
    panel.hasShadow = false
    updateWindowInteractionState(for: panel, isUndocked: true, isUndockedFullScreen: true)
    panel.setFrame(screen.frame, display: true, animate: true)
    refreshContentView()
  }

  @MainActor
  private func exitUndockedFullScreen(_ panel: NSPanel) {
    let restoredFrame = restoredFrameAfterFullScreen ?? lastUndockedFrame ?? panel.frame
    restoredFrameAfterFullScreen = nil
    isUndockedFullScreen = false
    panel.setFrame(restoredFrame, display: true, animate: true)
    panel.hasShadow = true
    updateWindowInteractionState(for: panel, isUndocked: true, isUndockedFullScreen: false)
    refreshContentView()
  }

  @MainActor
  private func refreshContentView() {
    guard let panel, let currentScript, let hostingView else { return }
    let screen = panel.screen ?? builtInScreen
    let notchSize = isUndocked ? .zero : Self.notchSize(for: screen)
    updateWindowInteractionState(for: panel)
    hostingView.rootView = makeContentView(for: currentScript, notchSize: notchSize)
  }

  @MainActor
  private func updateWindowInteractionState(
    for panel: NSPanel,
    isUndocked: Bool? = nil,
    isUndockedFullScreen: Bool? = nil
  ) {
    let resolvedIsUndocked = isUndocked ?? self.isUndocked
    let resolvedIsUndockedFullScreen = isUndockedFullScreen ?? self.isUndockedFullScreen
    let canMoveOrResize = resolvedIsUndocked && !resolvedIsUndockedFullScreen

    panel.isMovableByWindowBackground = canMoveOrResize
    panel.minSize = canMoveOrResize ? undockedMinimumSize : .zero
    panel.contentMinSize = canMoveOrResize ? undockedMinimumSize : .zero
    if canMoveOrResize {
      panel.styleMask.insert(.resizable)
      let clampedFrame = CGRect(
        x: panel.frame.minX,
        y: panel.frame.maxY - max(panel.frame.height, undockedMinimumSize.height),
        width: max(panel.frame.width, undockedMinimumSize.width),
        height: max(panel.frame.height, undockedMinimumSize.height)
      )
      if clampedFrame.size != panel.frame.size {
        panel.setFrame(clampedFrame, display: true)
      }
    } else {
      panel.styleMask.remove(.resizable)
    }
  }

  @MainActor
  private func resizeUndocked(edge: FloatingResizeEdge, translation: CGSize) {
    guard let panel, isUndocked, !isUndockedFullScreen else { return }

    let frame = resizeStartFrame ?? panel.frame
    if resizeStartFrame == nil {
      resizeStartFrame = frame
    }

    var newFrame = frame

    if edge.affectsLeft {
      let proposedWidth = frame.width - translation.width
      let clampedWidth = max(undockedMinimumSize.width, proposedWidth)
      let consumed = frame.width - clampedWidth
      newFrame.origin.x += consumed
      newFrame.size.width = clampedWidth
    }

    if edge.affectsRight {
      newFrame.size.width = max(undockedMinimumSize.width, frame.width + translation.width)
    }

    if edge.affectsTop {
      newFrame.size.height = max(undockedMinimumSize.height, frame.height - translation.height)
    }

    if edge.affectsBottom {
      let proposedHeight = frame.height + translation.height
      let clampedHeight = max(undockedMinimumSize.height, proposedHeight)
      let consumed = clampedHeight - frame.height
      newFrame.origin.y -= consumed
      newFrame.size.height = clampedHeight
    }

    lastUndockedFrame = newFrame
    panel.setFrame(newFrame, display: true)
  }

  @MainActor
  func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
    guard
      sender === panel,
      isUndocked,
      !isUndockedFullScreen
    else {
      return frameSize
    }

    return NSSize(
      width: max(frameSize.width, undockedMinimumSize.width),
      height: max(frameSize.height, undockedMinimumSize.height)
    )
  }

  @MainActor
  func windowDidResize(_ notification: Notification) {
    guard
      let panel,
      notification.object as? NSWindow === panel,
      isUndocked,
      !isUndockedFullScreen
    else {
      return
    }

    let clampedFrame = CGRect(
      x: panel.frame.minX,
      y: panel.frame.maxY - max(panel.frame.height, undockedMinimumSize.height),
      width: max(panel.frame.width, undockedMinimumSize.width),
      height: max(panel.frame.height, undockedMinimumSize.height)
    )

    if clampedFrame != panel.frame {
      panel.setFrame(clampedFrame, display: true)
    }
    lastUndockedFrame = panel.frame
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

enum FloatingResizeEdge {
  case topLeading
  case top
  case topTrailing
  case leading
  case trailing
  case bottomLeading
  case bottom
  case bottomTrailing

  var affectsLeft: Bool {
    switch self {
    case .topLeading, .leading, .bottomLeading:
      return true
    default:
      return false
    }
  }

  var affectsRight: Bool {
    switch self {
    case .topTrailing, .trailing, .bottomTrailing:
      return true
    default:
      return false
    }
  }

  var affectsTop: Bool {
    switch self {
    case .topLeading, .top, .topTrailing:
      return true
    default:
      return false
    }
  }

  var affectsBottom: Bool {
    switch self {
    case .bottomLeading, .bottom, .bottomTrailing:
      return true
    default:
      return false
    }
  }
}
