import SwiftUI

enum NotchOverlayGeometry {
  static let outerCornerRadius: CGFloat = 10
  static let minimumSideOverscan: CGFloat = 0.0
  static let proportionalSideOverscan: CGFloat = 0.05
  static let maximumSideOverscan: CGFloat = 0.0
  static let sideWallSeamCompensation: CGFloat = 0.5
  static let evenWidthLeftWallSeamCompensation: CGFloat = 1.0

  static func fallbackPath(in rect: CGRect) -> Path {
    var path = Path()
    let radius = min(outerCornerRadius, rect.width / 2, rect.height / 2)

    path.move(to: CGPoint(x: 0, y: 0))
    path.addLine(to: CGPoint(x: rect.width, y: 0))
    path.addLine(to: CGPoint(x: rect.width, y: rect.height - radius))
    path.addQuadCurve(
      to: CGPoint(x: rect.width - radius, y: rect.height),
      control: CGPoint(x: rect.width, y: rect.height)
    )
    path.addLine(to: CGPoint(x: radius, y: rect.height))
    path.addQuadCurve(
      to: CGPoint(x: 0, y: rect.height - radius),
      control: CGPoint(x: 0, y: rect.height)
    )
    path.closeSubpath()

    return path
  }

  static func cutoutDepth(for notchHeight: CGFloat) -> CGFloat {
    max(notchHeight - min(1.0, notchHeight * 0.08), 0)
  }

  static func sideOverscan(for notchWidth: CGFloat) -> CGFloat {
    // The cutout must align exactly with the physical notch edges. Keep the
    // effective side overscan clamped to zero even if proportional tuning changes.
    min(max(minimumSideOverscan, notchWidth * proportionalSideOverscan), maximumSideOverscan)
  }

  static func leftSideWallSeamCompensation(in rect: CGRect, notchWidth: CGFloat) -> CGFloat {
    let physicalLeftWall = rect.midX - notchWidth / 2
    let baseCompensation =
      physicalLeftWall == physicalLeftWall.rounded()
      ? evenWidthLeftWallSeamCompensation : sideWallSeamCompensation
    return min(baseCompensation, notchWidth * 0.5)
  }

  static func rightSideWallSeamCompensation(notchWidth: CGFloat) -> CGFloat {
    min(sideWallSeamCompensation, notchWidth * 0.5)
  }

  static func overlayPath(in rect: CGRect, notchSize: CGSize) -> Path {
    let nW = notchSize.width
    let nH = notchSize.height

    guard nW > 0, nH > 0 else {
      return fallbackPath(in: rect)
    }

    let cutoutDepth = cutoutDepth(for: nH)
    let ir: CGFloat = cutoutDepth * 0.3
    let outerRadius: CGFloat = outerCornerRadius

    let sideOverscan = sideOverscan(for: nW)
    let leftSideWallCompensation = leftSideWallSeamCompensation(in: rect, notchWidth: nW)
    let rightSideWallCompensation = rightSideWallSeamCompensation(notchWidth: nW)
    let nL = rect.midX - nW / 2 - sideOverscan + leftSideWallCompensation
    let nR = rect.midX + nW / 2 + sideOverscan - rightSideWallCompensation

    var path = Path()
    path.move(to: CGPoint(x: 0, y: 0))
    path.addLine(to: CGPoint(x: nL, y: 0))
    path.addLine(to: CGPoint(x: nL, y: cutoutDepth - ir))
    path.addQuadCurve(
      to: CGPoint(x: nL + ir, y: cutoutDepth),
      control: CGPoint(x: nL, y: cutoutDepth)
    )
    path.addLine(to: CGPoint(x: nR - ir, y: cutoutDepth))
    path.addQuadCurve(
      to: CGPoint(x: nR, y: cutoutDepth - ir),
      control: CGPoint(x: nR, y: cutoutDepth)
    )
    path.addLine(to: CGPoint(x: nR, y: 0))
    path.addLine(to: CGPoint(x: rect.width, y: 0))
    path.addLine(to: CGPoint(x: rect.width, y: rect.height - outerRadius))
    path.addQuadCurve(
      to: CGPoint(x: rect.width - outerRadius, y: rect.height),
      control: CGPoint(x: rect.width, y: rect.height)
    )
    path.addLine(to: CGPoint(x: outerRadius, y: rect.height))
    path.addQuadCurve(
      to: CGPoint(x: 0, y: rect.height - outerRadius),
      control: CGPoint(x: 0, y: rect.height)
    )
    path.addLine(to: CGPoint(x: 0, y: cutoutDepth))
    path.closeSubpath()

    return path
  }
}

enum NotchTextFadeGeometry {
  static let minimumFadeHeight: CGFloat = 28
  static let maximumFadeHeight: CGFloat = 72

  static func fadeHeight(availableHeight: CGFloat, notchHeight: CGFloat) -> CGFloat {
    min(
      availableHeight,
      maximumFadeHeight,
      max(minimumFadeHeight, notchHeight * 0.95 + 18)
    )
  }
}

struct NotchContentView: View {
  let script: Script
  let appearance: OverlayAppearance
  let defaultAppearance: OverlayAppearance
  let countdownDuration: Int
  let voiceSyncEnabled: Bool
  let spokenWordHighlightingEnabled: Bool
  let showScriptProgress: Bool
  let pauseOnHoverEnabled: Bool
  let autoScrollWPM: Double
  let playheadCoordinator: SessionPlayheadCoordinator
  let scrollCoordinator: SessionScrollCoordinator
  let reportsPrimaryMetrics: Bool
  let isDocked: Bool
  let canUndock: Bool
  let isFullScreen: Bool
  let notchSize: CGSize  // physical notch dimensions in screen points
  let frostedGlassEnabled: Bool
  let voiceSyncMode: VoiceSyncMode
  @ObservedObject var voiceSync: VoiceSyncEngine
  @ObservedObject var audioMonitor: AudioLevelMonitor
  let launchTrace: SessionLaunchTrace?
  let onDockToggle: () -> Void
  let onFullscreenToggle: () -> Void
  let onPauseToggle: () -> Void
  let onMicrophoneToggle: () -> Void
  let onEndSession: () -> Void
  let onAppearanceChange: (OverlayAppearance) -> Void
  let onResize: (NotchResizeEdge, CGSize) -> Void
  let onFloatingResize: (FloatingResizeEdge, CGSize) -> Void
  let onResizeEnd: () -> Void
  let onResetDefaultSize: () -> Void

  @State private var currentAppearance: OverlayAppearance
  @State private var showAppearancePopover: Bool = false
  @State private var showHoverControls: Bool = false

  init(
    script: Script, appearance: OverlayAppearance, countdownDuration: Int,
    voiceSyncEnabled: Bool = true, spokenWordHighlightingEnabled: Bool = false,
    showScriptProgress: Bool = false,
    pauseOnHoverEnabled: Bool = true, autoScrollWPM: Double = 0,
    playheadCoordinator: SessionPlayheadCoordinator,
    scrollCoordinator: SessionScrollCoordinator, reportsPrimaryMetrics: Bool = true,
    isDocked: Bool = true,
    canUndock: Bool = true,
    isFullScreen: Bool = false,
    notchSize: CGSize, frostedGlassEnabled: Bool = false, voiceSyncMode: VoiceSyncMode = .voice,
    voiceSync: VoiceSyncEngine,
    audioMonitor: AudioLevelMonitor,
    launchTrace: SessionLaunchTrace? = nil,
    defaultAppearance: OverlayAppearance? = nil,
    onDockToggle: @escaping () -> Void = {},
    onFullscreenToggle: @escaping () -> Void = {},
    onPauseToggle: @escaping () -> Void = {},
    onMicrophoneToggle: @escaping () -> Void = {},
    onEndSession: @escaping () -> Void,
    onAppearanceChange: @escaping (OverlayAppearance) -> Void = { _ in },
    onResize: @escaping (NotchResizeEdge, CGSize) -> Void = { _, _ in },
    onFloatingResize: @escaping (FloatingResizeEdge, CGSize) -> Void = { _, _ in },
    onResizeEnd: @escaping () -> Void = {},
    onResetDefaultSize: @escaping () -> Void = {}
  ) {
    self.script = script
    self.appearance = appearance
    self.defaultAppearance = defaultAppearance ?? appearance
    self.countdownDuration = countdownDuration
    self.voiceSyncEnabled = voiceSyncEnabled
    self.spokenWordHighlightingEnabled = spokenWordHighlightingEnabled
    self.showScriptProgress = showScriptProgress
    self.pauseOnHoverEnabled = pauseOnHoverEnabled
    self.autoScrollWPM = autoScrollWPM
    self.playheadCoordinator = playheadCoordinator
    self.scrollCoordinator = scrollCoordinator
    self.reportsPrimaryMetrics = reportsPrimaryMetrics
    self.isDocked = isDocked
    self.canUndock = canUndock
    self.isFullScreen = isFullScreen
    self.notchSize = notchSize
    self.frostedGlassEnabled = frostedGlassEnabled
    self.voiceSyncMode = voiceSyncMode
    self.voiceSync = voiceSync
    self.audioMonitor = audioMonitor
    self.launchTrace = launchTrace
    self.onDockToggle = onDockToggle
    self.onFullscreenToggle = onFullscreenToggle
    self.onPauseToggle = onPauseToggle
    self.onMicrophoneToggle = onMicrophoneToggle
    self.onEndSession = onEndSession
    self.onAppearanceChange = onAppearanceChange
    self.onResize = onResize
    self.onFloatingResize = onFloatingResize
    self.onResizeEnd = onResizeEnd
    self.onResetDefaultSize = onResetDefaultSize
    _currentAppearance = State(initialValue: appearance)
  }

  var body: some View {
    GeometryReader { geometry in
      let usesFrostedGlass = isDocked && frostedGlassEnabled
      let contentShape: AnyNotchShape =
        isDocked ? .notch(notchSize: notchSize) : .roundedRectangle

      ZStack(alignment: .topLeading) {
        if usesFrostedGlass {
          OverlayFrostedGlassBackground(appearance: currentAppearance)
            .clipShape(contentShape)
        }

        PrompterContentView(
          script: script,
          appearance: currentAppearance,
          countdownDuration: countdownDuration,
          topContentInset: isDocked ? notchSize.height : 0,
          allowsOverlayWheelInput: OverlayWheelInputPolicy.allowsOverlayWheelInput(
            isNotchWindow: true,
            voiceSyncEnabled: voiceSyncEnabled,
            spokenWordHighlightingEnabled: spokenWordHighlightingEnabled
          ),
          usesOverlayWheelDeduplication:
            OverlayWheelDeduplicationPolicy.usesEventDeduplication(
              isNotchWindow: true,
              voiceSyncEnabled: voiceSyncEnabled,
              spokenWordHighlightingEnabled: spokenWordHighlightingEnabled
            ),
          usesStrictActiveAppWheelSourceRouting:
            OverlayWheelRoutingPolicy.usesStrictActiveAppWheelSourceRouting(
              isNotchWindow: true,
              voiceSyncEnabled: voiceSyncEnabled,
              spokenWordHighlightingEnabled: spokenWordHighlightingEnabled
            ),
          voiceSyncEnabled: voiceSyncEnabled,
          spokenWordHighlightingEnabled: spokenWordHighlightingEnabled,
          showScriptProgress: showScriptProgress,
          pauseOnHoverEnabled: pauseOnHoverEnabled,
          autoScrollWPM: autoScrollWPM,
          drawsBackground: !usesFrostedGlass,
          playheadCoordinator: playheadCoordinator,
          scrollCoordinator: scrollCoordinator,
          reportsPrimaryMetrics: reportsPrimaryMetrics,
          scrollPresentation: .bottomEntry,
          showsEmbeddedAudioIndicator: !isDocked
            && (voiceSyncEnabled || spokenWordHighlightingEnabled),
          embeddedAudioIndicatorUsesReservedLane: !isDocked
            && (voiceSyncEnabled || spokenWordHighlightingEnabled),
          syncsSessionScroll: true,
          textExitFadeHeight: isDocked
            ? NotchTextFadeGeometry.fadeHeight(
              availableHeight: max(geometry.size.height - notchSize.height, 0),
              notchHeight: notchSize.height
            )
            : 0,
          voiceSyncMode: voiceSyncMode,
          voiceSync: voiceSync,
          audioMonitor: audioMonitor,
          launchTrace: launchTrace
        )
        .clipShape(contentShape)

        if isDocked, notchSize.width > 0, notchSize.height > 0,
          voiceSyncEnabled || spokenWordHighlightingEnabled
        {
          NotchCornerWaveIndicators(
            level: audioMonitor.level,
            containerWidth: geometry.size.width,
            notchSize: notchSize,
            strokeColor: Color(hex: currentAppearance.textColor)
          )
          .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
          .allowsHitTesting(false)
        }

        if !isDocked && !isFullScreen {
          FloatingResizeHandles(onResize: onFloatingResize, onResizeEnd: onResizeEnd)
        }

        NotchHoverChrome(
          isVisible: showHoverControls,
          isDocked: isDocked,
          canUndock: canUndock,
          isFullScreen: isFullScreen,
          showsMicrophoneToggle: voiceSyncEnabled || spokenWordHighlightingEnabled,
          showsDockSidePauseButton: NotchHoverChromePolicy.showsDockSidePauseButton(
            voiceScrollMode: voiceSync.voiceScrollMode,
            spokenWordHighlightingEnabled: spokenWordHighlightingEnabled
          ),
          onDockToggle: onDockToggle,
          onFullscreenToggle: onFullscreenToggle,
          isPaused: voiceSync.isPausedByUser,
          isMicrophoneMuted: voiceSync.isMicrophoneMutedByUser,
          onPauseToggle: onPauseToggle,
          onMicrophoneToggle: onMicrophoneToggle,
          onEndSession: onEndSession
        )
      }
      .onHover { hovered in
        withAnimation(.easeInOut(duration: 0.15)) {
          showHoverControls = hovered
        }
      }
      .popover(isPresented: $showAppearancePopover) {
        OverlayAppearancePopover(
          appearance: $currentAppearance,
          defaultAppearance: defaultAppearance,
          windowTitle: "Notch Window"
        )
      }
      .onAppear {
        onAppearanceChange(currentAppearance)
      }
      .onChange(of: currentAppearance) { _, newAppearance in
        onAppearanceChange(newAppearance)
      }
    }
  }
}

private struct NotchHoverChrome: View {
  let isVisible: Bool
  let isDocked: Bool
  let canUndock: Bool
  let isFullScreen: Bool
  let showsMicrophoneToggle: Bool
  let showsDockSidePauseButton: Bool
  let onDockToggle: () -> Void
  let onFullscreenToggle: () -> Void
  let isPaused: Bool
  let isMicrophoneMuted: Bool
  let onPauseToggle: () -> Void
  let onMicrophoneToggle: () -> Void
  let onEndSession: () -> Void

  var body: some View {
    HStack(alignment: .top) {
      HStack(spacing: 4) {
        overlayButton(
          help: isDocked ? "Undock Notch Window" : "Dock Notch Window",
          action: onDockToggle,
          isEnabled: isDocked ? canUndock : true
        ) {
          OverlayDockArrowIcon(pointsDown: isDocked)
        }

        if showsDockSidePauseButton {
          overlayButton(
            help: isPaused ? "Resume Session" : "Pause Session",
            action: onPauseToggle
          ) {
            if isPaused {
              OverlayResumeIcon()
            } else {
              OverlayPauseIcon()
            }
          }
        }

        if !isDocked {
          overlayButton(
            help: isFullScreen ? "Exit Fullscreen" : "Fullscreen Notch Window",
            action: onFullscreenToggle
          ) {
            OverlayFullscreenIcon()
          }
        }
      }

      Spacer()

      HStack(spacing: 4) {
        if showsMicrophoneToggle || !showsDockSidePauseButton {
          overlayButton(
            help: showsMicrophoneToggle
              ? (isMicrophoneMuted ? "Turn Microphone On" : "Turn Microphone Off")
              : (isPaused ? "Resume Session" : "Pause Session"),
            action: NotchHoverChromePolicy.rightSideActionShowsMicrophone(
              showsMicrophoneToggle: showsMicrophoneToggle
            )
              ? onMicrophoneToggle : onPauseToggle
          ) {
            if showsMicrophoneToggle {
              OverlayVoiceMicIcon(isMuted: isMicrophoneMuted)
            } else {
              if isPaused {
                OverlayResumeIcon()
              } else {
                OverlayPauseIcon()
              }
            }
          }
        }

        overlayButton(help: "Close Notch Window", action: onEndSession) {
          OverlayCloseIcon()
        }
      }
    }
    .padding(.horizontal, 6)
    .padding(.top, 4)
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

enum NotchHoverChromePolicy {
  static func rightSideActionShowsMicrophone(showsMicrophoneToggle: Bool) -> Bool {
    showsMicrophoneToggle
  }

  static func showsDockSidePauseButton(
    voiceScrollMode: VoiceScrollMode,
    spokenWordHighlightingEnabled: Bool
  ) -> Bool {
    voiceScrollMode == .classicScroll && spokenWordHighlightingEnabled
  }
}

private enum AnyNotchShape: Shape {
  case notch(notchSize: CGSize)
  case roundedRectangle

  func path(in rect: CGRect) -> Path {
    switch self {
    case .notch(let notchSize):
      return NotchOverlayShape(notchSize: notchSize).path(in: rect)
    case .roundedRectangle:
      return RoundedRectangle(cornerRadius: 16).path(in: rect)
    }
  }
}

private struct NotchResizeHandles: View {
  let onResize: (NotchResizeEdge, CGSize) -> Void
  let onResizeEnd: () -> Void

  private let handleThickness: CGFloat = 12
  private let cornerSize: CGFloat = 18

  var body: some View {
    GeometryReader { geometry in
      ZStack {
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
  private func resizeHandle(_ edge: NotchResizeEdge) -> some View {
    Color.clear
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            onResize(edge, value.translation)
          }
          .onEnded { _ in
            onResizeEnd()
          }
      )
  }
}

private struct NotchCornerWaveIndicators: View {
  let level: Float
  let containerWidth: CGFloat
  let notchSize: CGSize
  let strokeColor: Color

  var body: some View {
    let gap: CGFloat = 8
    let baselineY: CGFloat = 2
    let notchLeadingX = (containerWidth / 2) - (notchSize.width / 2)
    let notchTrailingX = (containerWidth / 2) + (notchSize.width / 2)

    ZStack(alignment: .topLeading) {
      NotchCornerArcWave(level: level, side: .left, strokeColor: strokeColor)
        .offset(
          x: notchLeadingX - gap - NotchCornerArcWave.size.width,
          y: baselineY
        )

      NotchCornerArcWave(level: level, side: .right, strokeColor: strokeColor)
        .offset(
          x: notchTrailingX + gap,
          y: baselineY
        )
    }
  }
}

private struct NotchCornerArcWave: View {
  enum Side {
    case left
    case right
  }

  static let size = CGSize(width: 48, height: 36)
  let level: Float
  let side: Side
  let strokeColor: Color

  var body: some View {
    Canvas { context, size in
      let origin = CGPoint(
        x: side == .left ? size.width - 6 : 6,
        y: 6
      )

      let radius = 10.0 + Double(level) * 16.0
      var path = Path()
      path.addArc(
        center: origin,
        radius: radius,
        startAngle: side == .left ? .degrees(92) : .degrees(-10),
        endAngle: side == .left ? .degrees(190) : .degrees(88),
        clockwise: false
      )
      context.stroke(
        path,
        with: .color(strokeColor),
        lineWidth: 2.5
      )
    }
    .frame(width: Self.size.width, height: Self.size.height)
    .animation(.easeInOut(duration: 0.1), value: level)
  }
}

private struct OverlayVoiceMicIcon: View {
  let isMuted: Bool

  var body: some View {
    ZStack {
      Canvas { context, size in
        let strokeColor = NSColor(Color("colorText"))
        let signalColor = NSColor(Color("colorSecondary"))

        func stroke(
          _ path: Path,
          color: NSColor,
          width: CGFloat,
          opacity: CGFloat = 1,
          dash: [CGFloat] = []
        ) {
          context.stroke(
            path,
            with: .color(Color(nsColor: color).opacity(opacity)),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash)
          )
        }

        let outerLeft = Path { path in
          path.move(to: CGPoint(x: 3, y: 12))
          path.addQuadCurve(to: CGPoint(x: 6, y: 5), control: CGPoint(x: 3, y: 7))
        }
        let outerRight = Path { path in
          path.move(to: CGPoint(x: 21, y: 12))
          path.addQuadCurve(to: CGPoint(x: 18, y: 5), control: CGPoint(x: 21, y: 7))
        }
        let midLeft = Path { path in
          path.move(to: CGPoint(x: 6, y: 12))
          path.addQuadCurve(to: CGPoint(x: 8, y: 7), control: CGPoint(x: 6, y: 8))
        }
        let midRight = Path { path in
          path.move(to: CGPoint(x: 18, y: 12))
          path.addQuadCurve(to: CGPoint(x: 16, y: 7), control: CGPoint(x: 18, y: 8))
        }
        let innerLeft = Path { path in
          path.move(to: CGPoint(x: 8, y: 12))
          path.addQuadCurve(to: CGPoint(x: 9.5, y: 9), control: CGPoint(x: 8, y: 9.5))
        }
        let innerRight = Path { path in
          path.move(to: CGPoint(x: 16, y: 12))
          path.addQuadCurve(to: CGPoint(x: 14.5, y: 9), control: CGPoint(x: 16, y: 9.5))
        }

        stroke(outerLeft, color: signalColor, width: 1.6, opacity: 0.2, dash: [2.2, 1.8])
        stroke(outerRight, color: signalColor, width: 1.6, opacity: 0.2, dash: [2.2, 1.8])
        stroke(midLeft, color: signalColor, width: 1.6, opacity: 0.35, dash: [1.8, 1.4])
        stroke(midRight, color: signalColor, width: 1.6, opacity: 0.35, dash: [1.8, 1.4])
        stroke(innerLeft, color: signalColor, width: 1.6, opacity: 0.5, dash: [1.6, 1.1])
        stroke(innerRight, color: signalColor, width: 1.6, opacity: 0.5, dash: [1.6, 1.1])

        let body = Path(roundedRect: CGRect(x: 9, y: 5, width: 6, height: 8), cornerRadius: 3)
        context.fill(body, with: .color(Color(nsColor: signalColor).opacity(0.9)))
        stroke(body, color: signalColor, width: 1.2)

        let grill = [
          Path(CGRect(x: 10.2, y: 6.7, width: 3.6, height: 0.1)),
          Path(CGRect(x: 10.2, y: 8.5, width: 3.6, height: 0.1)),
          Path(CGRect(x: 10.2, y: 10.3, width: 3.6, height: 0.1)),
        ]
        for line in grill {
          stroke(line, color: .white, width: 1, opacity: 0.35)
        }

        let holder = Path { path in
          path.move(to: CGPoint(x: 8, y: 13))
          path.addQuadCurve(to: CGPoint(x: 10, y: 15), control: CGPoint(x: 8, y: 15))
          path.move(to: CGPoint(x: 16, y: 13))
          path.addQuadCurve(to: CGPoint(x: 14, y: 15), control: CGPoint(x: 16, y: 15))
          path.move(to: CGPoint(x: 12, y: 13))
          path.addLine(to: CGPoint(x: 12, y: 17))
          path.addQuadCurve(to: CGPoint(x: 9.5, y: 19), control: CGPoint(x: 12, y: 19))
          path.addLine(to: CGPoint(x: 14.5, y: 19))
        }
        stroke(holder, color: strokeColor, width: 1.6)

        if isMuted {
          let slash = Path { path in
            path.move(to: CGPoint(x: 5, y: 20))
            path.addLine(to: CGPoint(x: 19, y: 4))
          }
          stroke(slash, color: .black, width: 3.8, opacity: 0.7)
          stroke(slash, color: .white, width: 2.2, opacity: 0.96)
        }
      }
      .frame(width: 24, height: 24)
    }
  }
}

private struct FloatingResizeHandles: View {
  let onResize: (FloatingResizeEdge, CGSize) -> Void
  let onResizeEnd: () -> Void

  private let handleThickness: CGFloat = 12
  private let cornerSize: CGFloat = 18

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
  private func resizeHandle(_ edge: FloatingResizeEdge) -> some View {
    Color.clear
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            onResize(edge, value.translation)
          }
          .onEnded { _ in
            onResizeEnd()
          }
      )
  }
}

/// Clips the notch overlay panel to the correct shape: a rounded rectangle with the
/// physical camera-notch area cut out of the top centre.
///
/// All dimensions come from the actual screen geometry rather than hardcoded proportions,
/// so the shape fits flush against the physical notch on every Mac model.
private struct NotchOverlayShape: Shape {
  let notchSize: CGSize  // physical notch width and height in screen points

  func path(in rect: CGRect) -> Path {
    NotchOverlayGeometry.overlayPath(in: rect, notchSize: notchSize)
  }
}
