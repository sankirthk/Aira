import SwiftUI

enum PillPrompterBehavior {
  static func pauseOnHoverEnabled(
    mode: PillContentMode,
    requested: Bool
  ) -> Bool {
    false
  }

  static func spokenWordHighlightingEnabled(
    mode: PillContentMode,
    requested: Bool
  ) -> Bool {
    switch mode {
    case .voiceSync:
      return requested
    case .manual:
      return false
    }
  }
}

enum PillChromeBadge {
  case voice
  case sync
  case manual

  var systemImageName: String {
    switch self {
    case .voice:
      return "waveform"
    case .sync:
      return "link"
    case .manual:
      return "hand.point.up"
    }
  }
}

enum PillChromePolicy {
  static func badge(
    mode: PillContentMode,
    voiceSyncEnabled: Bool
  ) -> PillChromeBadge {
    switch mode {
    case .manual:
      return .manual
    case .voiceSync:
      return voiceSyncEnabled ? .voice : .sync
    }
  }

  static func showsEmbeddedAudioIndicator(
    mode: PillContentMode,
    voiceSyncEnabled: Bool
  ) -> Bool {
    switch mode {
    case .manual:
      return false
    case .voiceSync:
      return voiceSyncEnabled
    }
  }
}

struct PillContentView: View {
  let script: Script
  let appearance: OverlayAppearance
  let defaultAppearance: OverlayAppearance
  let countdownDuration: Int
  let voiceSyncEnabled: Bool
  let spokenWordHighlightingEnabled: Bool
  let pauseOnHoverEnabled: Bool
  let autoScrollWPM: Double
  let playheadCoordinator: SessionPlayheadCoordinator
  let scrollCoordinator: SessionScrollCoordinator
  let reportsPrimaryMetrics: Bool
  let mode: PillContentMode
  let isFullScreen: Bool
  let voiceSyncMode: VoiceSyncMode
  @ObservedObject var voiceSync: VoiceSyncEngine
  @ObservedObject var audioMonitor: AudioLevelMonitor
  let onClose: () -> Void
  let onAppearanceChange: (OverlayAppearance) -> Void
  let onSwapWithNotch: (() -> Void)?
  let onFullscreenToggle: () -> Void
  let onResetDefaultSize: () -> Void

  @State private var currentAppearance: OverlayAppearance
  @State private var showAppearancePopover: Bool = false
  @State private var showModeIndicator: Bool = false
  @State private var showHoverControls: Bool = false
  @State private var pillWindow: NSWindow?
  @State private var fullscreenEnabled: Bool = false

  init(
    script: Script, appearance: OverlayAppearance, countdownDuration: Int,
    voiceSyncEnabled: Bool = true,
    spokenWordHighlightingEnabled: Bool = false,
    pauseOnHoverEnabled: Bool = true,
    autoScrollWPM: Double = 0,
    playheadCoordinator: SessionPlayheadCoordinator,
    scrollCoordinator: SessionScrollCoordinator,
    reportsPrimaryMetrics: Bool = false,
    mode: PillContentMode,
    isFullScreen: Bool = false,
    voiceSyncMode: VoiceSyncMode = .voice, voiceSync: VoiceSyncEngine,
    audioMonitor: AudioLevelMonitor,
    onClose: @escaping () -> Void,
    onAppearanceChange: @escaping (OverlayAppearance) -> Void = { _ in },
    onSwapWithNotch: (() -> Void)? = nil,
    onFullscreenToggle: @escaping () -> Void = {},
    defaultAppearance: OverlayAppearance = .default,
    onResetDefaultSize: @escaping () -> Void = {}
  ) {
    self.script = script
    self.appearance = appearance
    self.defaultAppearance = defaultAppearance
    self.countdownDuration = countdownDuration
    self.voiceSyncEnabled = voiceSyncEnabled
    self.spokenWordHighlightingEnabled = spokenWordHighlightingEnabled
    self.pauseOnHoverEnabled = pauseOnHoverEnabled
    self.autoScrollWPM = autoScrollWPM
    self.playheadCoordinator = playheadCoordinator
    self.scrollCoordinator = scrollCoordinator
    self.reportsPrimaryMetrics = reportsPrimaryMetrics
    self.mode = mode
    self.isFullScreen = isFullScreen
    self.voiceSyncMode = voiceSyncMode
    self.voiceSync = voiceSync
    self.audioMonitor = audioMonitor
    self.onClose = onClose
    self.onAppearanceChange = onAppearanceChange
    self.onSwapWithNotch = onSwapWithNotch
    self.onFullscreenToggle = onFullscreenToggle
    self.onResetDefaultSize = onResetDefaultSize
    _currentAppearance = State(initialValue: appearance)
  }

  var body: some View {
    let effectiveVoiceSyncEnabled = mode == .voiceSync ? voiceSyncEnabled : false
    let effectiveSpokenWordHighlightingEnabled = PillPrompterBehavior.spokenWordHighlightingEnabled(
      mode: mode,
      requested: spokenWordHighlightingEnabled
    )
    let effectivePauseOnHoverEnabled = PillPrompterBehavior.pauseOnHoverEnabled(
      mode: mode,
      requested: pauseOnHoverEnabled
    )
    let pillChromeBadge = PillChromePolicy.badge(
      mode: mode,
      voiceSyncEnabled: effectiveVoiceSyncEnabled
    )
    let showsEmbeddedAudioIndicator = PillChromePolicy.showsEmbeddedAudioIndicator(
      mode: mode,
      voiceSyncEnabled: effectiveVoiceSyncEnabled
    )

    ZStack(alignment: .topLeading) {
      PrompterContentView(
        script: script,
        appearance: currentAppearance,
        countdownDuration: mode == .voiceSync ? countdownDuration : 0,
        allowsOverlayWheelInput: OverlayWheelInputPolicy.allowsOverlayWheelInput(
          isNotchWindow: false,
          voiceSyncEnabled: effectiveVoiceSyncEnabled,
          spokenWordHighlightingEnabled: effectiveSpokenWordHighlightingEnabled
        ),
        usesOverlayWheelDeduplication:
          OverlayWheelDeduplicationPolicy.usesEventDeduplication(
            isNotchWindow: false,
            voiceSyncEnabled: effectiveVoiceSyncEnabled,
            spokenWordHighlightingEnabled: effectiveSpokenWordHighlightingEnabled
          ),
        usesStrictActiveAppWheelSourceRouting:
          OverlayWheelRoutingPolicy.usesStrictActiveAppWheelSourceRouting(
            isNotchWindow: false,
            voiceSyncEnabled: effectiveVoiceSyncEnabled,
            spokenWordHighlightingEnabled: effectiveSpokenWordHighlightingEnabled
          ),
        voiceSyncEnabled: effectiveVoiceSyncEnabled,
        spokenWordHighlightingEnabled: effectiveSpokenWordHighlightingEnabled,
        pauseOnHoverEnabled: effectivePauseOnHoverEnabled,
        autoScrollWPM: autoScrollWPM,
        playheadCoordinator: playheadCoordinator,
        scrollCoordinator: scrollCoordinator,
        reportsPrimaryMetrics: reportsPrimaryMetrics,
        showsEmbeddedAudioIndicator: showsEmbeddedAudioIndicator,
        embeddedAudioIndicatorUsesReservedLane: showsEmbeddedAudioIndicator,
        syncsSessionScroll: mode == .voiceSync,
        manualAutoScrollEnabled: mode == .voiceSync,
        voiceSyncMode: voiceSyncMode,
        voiceSync: voiceSync,
        audioMonitor: audioMonitor,
        launchTrace: nil
      )
      .clipShape(RoundedRectangle(cornerRadius: 16))

      // Content mode indicator badge (top-left, hover only)
      ContentModeIndicator(
        systemImageName: pillChromeBadge.systemImageName,
        isVisible: showModeIndicator
      )
      .padding(6)

      PillHoverChrome(
        isVisible: showHoverControls,
        onSwapWithNotch: onSwapWithNotch,
        swapEnabled: mode != .voiceSync,
        fullscreenEnabled: fullscreenEnabled,
        onFullscreenToggle: onFullscreenToggle,
        onClose: onClose
      )
      .padding(6)

      if !isFullScreen {
        PillResizeHandles(window: pillWindow)
      }
    }
    .background(
      PillWindowAccessor { window in
        pillWindow = window
        refreshFullscreenAvailability(for: window)
      }
    )
    .onHover { hovered in
      withAnimation(.easeInOut(duration: 0.15)) {
        showModeIndicator = hovered
        showHoverControls = hovered
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeScreenNotification)) {
      notification in
      guard let window = notification.object as? NSWindow, window === pillWindow else { return }
      refreshFullscreenAvailability(for: window)
    }
    .popover(isPresented: $showAppearancePopover) {
      OverlayAppearancePopover(
        appearance: $currentAppearance,
        defaultAppearance: defaultAppearance,
        windowTitle: "Pill Window"
      )
    }
    .onAppear {
      onAppearanceChange(currentAppearance)
    }
    .onChange(of: currentAppearance) { _, newAppearance in
      onAppearanceChange(newAppearance)
    }
  }

  private func refreshFullscreenAvailability(for window: NSWindow?) {
    fullscreenEnabled = PillWindowController.fullScreenAllowed(for: window?.screen)
  }
}

private struct PillHoverChrome: View {
  let isVisible: Bool
  let onSwapWithNotch: (() -> Void)?
  let swapEnabled: Bool
  let fullscreenEnabled: Bool
  let onFullscreenToggle: () -> Void
  let onClose: () -> Void

  var body: some View {
    HStack {
      Spacer()

      HStack(spacing: 4) {
        if let onSwapWithNotch {
          overlayButton(
            help: swapEnabled ? "Swap Pill Script" : "Swap unavailable for sync pill",
            action: onSwapWithNotch,
            isEnabled: swapEnabled
          ) {
            OverlaySwapIcon()
          }
        }

        overlayButton(
          help: fullscreenEnabled
            ? "Fullscreen Pill Window"
            : "Fullscreen available only on secondary displays",
          action: onFullscreenToggle,
          isEnabled: fullscreenEnabled
        ) {
          OverlayFullscreenIcon()
        }

        overlayButton(help: "Close Pill Window", action: onClose) {
          OverlayCloseIcon()
        }
      }
    }
    .opacity(isVisible ? 1 : 0)
    .allowsHitTesting(isVisible)
  }

  @ViewBuilder
  private func overlayButton<Label: View>(
    help: String,
    action: (() -> Void)? = nil,
    isEnabled: Bool = true,
    @ViewBuilder label: () -> Label
  ) -> some View {
    Button(action: { action?() }) {
      label()
    }
    .buttonStyle(OverlayChromeIconButtonStyle())
    .disabled(!isEnabled)
    .help(action == nil ? "\(help) (not wired yet)" : help)
  }
}

private struct PillWindowAccessor: NSViewRepresentable {
  let onResolve: (NSWindow?) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    Task { @MainActor in
      onResolve(view.window)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    Task { @MainActor in
      onResolve(nsView.window)
    }
  }
}

private struct PillResizeHandles: View {
  weak var window: NSWindow?
  @State private var resizeStartFrame: CGRect?

  private let handleThickness: CGFloat = 12
  private let cornerSize: CGFloat = 18
  private let minimumSize = CGSize(width: 360, height: 120)

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        resizeHandle(.topLeading)
          .frame(width: cornerSize, height: cornerSize)
          .position(x: cornerSize / 2, y: cornerSize / 2)
        resizeHandle(.top)
          .frame(maxWidth: .infinity)
          .frame(height: handleThickness)
          .position(x: geometry.size.width / 2, y: handleThickness / 2)
        resizeHandle(.topTrailing)
          .frame(width: cornerSize, height: cornerSize)
          .position(x: geometry.size.width - cornerSize / 2, y: cornerSize / 2)

        resizeHandle(.leading)
          .frame(width: handleThickness)
          .frame(maxHeight: .infinity)
          .position(x: handleThickness / 2, y: geometry.size.height / 2)
        resizeHandle(.trailing)
          .frame(width: handleThickness)
          .frame(maxHeight: .infinity)
          .position(x: geometry.size.width - handleThickness / 2, y: geometry.size.height / 2)

        resizeHandle(.bottomLeading)
          .frame(width: cornerSize, height: cornerSize)
          .position(x: cornerSize / 2, y: geometry.size.height - cornerSize / 2)
        resizeHandle(.bottom)
          .frame(maxWidth: .infinity)
          .frame(height: handleThickness)
          .position(x: geometry.size.width / 2, y: geometry.size.height - handleThickness / 2)
        resizeHandle(.bottomTrailing)
          .frame(width: cornerSize, height: cornerSize)
          .position(
            x: geometry.size.width - cornerSize / 2, y: geometry.size.height - cornerSize / 2)
      }
    }
    .allowsHitTesting(true)
  }

  @ViewBuilder
  private func resizeHandle(_ edge: PillResizeEdge) -> some View {
    Color.clear
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            resizeWindow(edge: edge, translation: value.translation)
          }
          .onEnded { _ in
            resizeStartFrame = nil
          }
      )
  }

  private func resizeWindow(edge: PillResizeEdge, translation: CGSize) {
    guard let window else { return }

    let frame = resizeStartFrame ?? window.frame
    if resizeStartFrame == nil {
      resizeStartFrame = frame
    }
    var newFrame = frame

    if edge.affectsLeft {
      let proposedWidth = frame.width - translation.width
      let clampedWidth = max(minimumSize.width, proposedWidth)
      let consumed = frame.width - clampedWidth
      newFrame.origin.x += consumed
      newFrame.size.width = clampedWidth
    }

    if edge.affectsRight {
      newFrame.size.width = max(minimumSize.width, frame.width + translation.width)
    }

    if edge.affectsTop {
      newFrame.size.height = max(minimumSize.height, frame.height - translation.height)
    }

    if edge.affectsBottom {
      let proposedHeight = frame.height + translation.height
      let clampedHeight = max(minimumSize.height, proposedHeight)
      let consumed = clampedHeight - frame.height
      newFrame.origin.y -= consumed
      newFrame.size.height = clampedHeight
    }

    window.setFrame(newFrame, display: true)
  }
}

private enum PillResizeEdge {
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
