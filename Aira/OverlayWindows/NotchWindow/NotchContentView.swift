import SwiftUI

enum NotchOverlayGeometry {
  static let outerCornerRadius: CGFloat = 10
  static let minimumSideOverscan: CGFloat = 2.0
  static let proportionalSideOverscan: CGFloat = 0.05
  static let maximumSideOverscan: CGFloat = 8.0

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
    min(max(minimumSideOverscan, notchWidth * proportionalSideOverscan), maximumSideOverscan)
  }

  static func overlayPath(in rect: CGRect, notchSize: CGSize) -> Path {
    let nW = notchSize.width
    let nH = notchSize.height

    guard nW > 0, nH > 0 else {
      return fallbackPath(in: rect)
    }

    let cutoutDepth = cutoutDepth(for: nH)
    let ir: CGFloat = cutoutDepth * 0.5
    let outerRadius: CGFloat = outerCornerRadius

    let sideOverscan = sideOverscan(for: nW)
    let nL = rect.midX - nW / 2 - sideOverscan
    let nR = rect.midX + nW / 2 + sideOverscan

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
  let autoScrollWPM: Double
  let playheadCoordinator: SessionPlayheadCoordinator
  let scrollCoordinator: SessionScrollCoordinator
  let reportsPrimaryMetrics: Bool
  let notchSize: CGSize  // physical notch dimensions in screen points
  let voiceSyncMode: VoiceSyncMode
  @ObservedObject var voiceSync: VoiceSyncEngine
  @ObservedObject var audioMonitor: AudioLevelMonitor
  let onEndSession: () -> Void
  let onAppearanceChange: (OverlayAppearance) -> Void
  let onResize: (NotchResizeEdge, CGSize) -> Void
  let onResizeEnd: () -> Void
  let onResetDefaultSize: () -> Void

  @State private var currentAppearance: OverlayAppearance
  @State private var showAppearancePopover: Bool = false

  init(
    script: Script, appearance: OverlayAppearance, countdownDuration: Int,
    voiceSyncEnabled: Bool = true, autoScrollWPM: Double = 0,
    playheadCoordinator: SessionPlayheadCoordinator,
    scrollCoordinator: SessionScrollCoordinator, reportsPrimaryMetrics: Bool = true,
    notchSize: CGSize, voiceSyncMode: VoiceSyncMode = .voice, voiceSync: VoiceSyncEngine,
    audioMonitor: AudioLevelMonitor,
    defaultAppearance: OverlayAppearance? = nil,
    onEndSession: @escaping () -> Void,
    onAppearanceChange: @escaping (OverlayAppearance) -> Void = { _ in },
    onResize: @escaping (NotchResizeEdge, CGSize) -> Void = { _, _ in },
    onResizeEnd: @escaping () -> Void = {},
    onResetDefaultSize: @escaping () -> Void = {}
  ) {
    self.script = script
    self.appearance = appearance
    self.defaultAppearance = defaultAppearance ?? appearance
    self.countdownDuration = countdownDuration
    self.voiceSyncEnabled = voiceSyncEnabled
    self.autoScrollWPM = autoScrollWPM
    self.playheadCoordinator = playheadCoordinator
    self.scrollCoordinator = scrollCoordinator
    self.reportsPrimaryMetrics = reportsPrimaryMetrics
    self.notchSize = notchSize
    self.voiceSyncMode = voiceSyncMode
    self.voiceSync = voiceSync
    self.audioMonitor = audioMonitor
    self.onEndSession = onEndSession
    self.onAppearanceChange = onAppearanceChange
    self.onResize = onResize
    self.onResizeEnd = onResizeEnd
    self.onResetDefaultSize = onResetDefaultSize
    _currentAppearance = State(initialValue: appearance)
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        PrompterContentView(
          script: script,
          appearance: currentAppearance,
          countdownDuration: countdownDuration,
          topContentInset: notchSize.height,
          voiceSyncEnabled: voiceSyncEnabled,
          autoScrollWPM: autoScrollWPM,
          playheadCoordinator: playheadCoordinator,
          scrollCoordinator: scrollCoordinator,
          reportsPrimaryMetrics: reportsPrimaryMetrics,
          scrollPresentation: .bottomEntry,
          showsEmbeddedAudioIndicator: false,
          syncsSessionScroll: true,
          textExitFadeHeight: NotchTextFadeGeometry.fadeHeight(
            availableHeight: max(geometry.size.height - notchSize.height, 0),
            notchHeight: notchSize.height
          ),
          voiceSyncMode: voiceSyncMode,
          voiceSync: voiceSync,
          audioMonitor: audioMonitor
        )
        .clipShape(NotchOverlayShape(notchSize: notchSize))

        if notchSize.width > 0, notchSize.height > 0 {
          NotchCornerWaveIndicators(
            level: audioMonitor.level,
            containerWidth: geometry.size.width,
            notchSize: notchSize
          )
          .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
          .allowsHitTesting(false)
        }

        NotchResizeHandles(onResize: onResize, onResizeEnd: onResizeEnd)
      }
      .contextMenu {
        Button("Appearance…") { showAppearancePopover = true }
        Button("Reset to Defaults") { currentAppearance = defaultAppearance }
        Button("Reset to Default Size") { onResetDefaultSize() }
        Divider()
        Button("End Session") { onEndSession() }
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

  var body: some View {
    let gap: CGFloat = 8
    let baselineY: CGFloat = 2
    let notchLeadingX = (containerWidth / 2) - (notchSize.width / 2)
    let notchTrailingX = (containerWidth / 2) + (notchSize.width / 2)

    ZStack(alignment: .topLeading) {
      NotchCornerArcWave(level: level, side: .left)
        .offset(
          x: notchLeadingX - gap - NotchCornerArcWave.size.width,
          y: baselineY
        )

      NotchCornerArcWave(level: level, side: .right)
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

  var body: some View {
    Canvas { context, size in
      let strokeColor = Color("colorPrimary")
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
