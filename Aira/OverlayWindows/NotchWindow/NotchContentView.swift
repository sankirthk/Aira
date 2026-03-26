import SwiftUI

struct NotchContentView: View {
    let script: Script
    let appearance: OverlayAppearance
    let countdownDuration: Int
    let voiceSyncEnabled: Bool
    let autoScrollWPM: Double
    let playheadCoordinator: SessionPlayheadCoordinator
    let scrollCoordinator: SessionScrollCoordinator
    let reportsPrimaryMetrics: Bool
    let notchSize: CGSize          // physical notch dimensions in screen points
    let voiceSyncMode: VoiceSyncMode
    @ObservedObject var voiceSync: VoiceSyncEngine
    @ObservedObject var audioMonitor: AudioLevelMonitor
    let onEndSession: () -> Void

    @State private var currentAppearance: OverlayAppearance
    @State private var showAppearancePopover: Bool = false

    init(script: Script, appearance: OverlayAppearance, countdownDuration: Int,
         voiceSyncEnabled: Bool = true, autoScrollWPM: Double = 0,
         playheadCoordinator: SessionPlayheadCoordinator,
         scrollCoordinator: SessionScrollCoordinator, reportsPrimaryMetrics: Bool = true,
         notchSize: CGSize, voiceSyncMode: VoiceSyncMode = .voice, voiceSync: VoiceSyncEngine, audioMonitor: AudioLevelMonitor,
         onEndSession: @escaping () -> Void) {
        self.script = script
        self.appearance = appearance
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
            }
            .contextMenu {
                Button("Appearance…") { showAppearancePopover = true }
                Button("Reset to Defaults") { currentAppearance = appearance }
                Divider()
                Button("End Session") { onEndSession() }
            }
            .popover(isPresented: $showAppearancePopover) {
                OverlayAppearancePopover(
                    appearance: $currentAppearance,
                    defaultAppearance: appearance,
                    windowTitle: "Notch Window"
                )
            }
        }
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
        let nW = notchSize.width
        let nH = notchSize.height

        // Non-notched Mac: render as a plain rounded rectangle.
        guard nW > 0, nH > 0 else {
            return Path(roundedRect: rect, cornerRadius: 10)
        }

        // Pull the visible cutout upward slightly so the overlay tucks under the
        // physical notch corners instead of leaving a hairline seam.
        let cutoutDepth = max(nH - min(1.5, nH * 0.08), 0)

        // Inner corner radius at the bottom of the notch cutout.
        // The MacBook notch has gently rounded inner corners where the camera housing
        // meets the display. Using 25% of the notch height gives a physically plausible
        // curve that scales correctly across Mac models without hardcoding.
        let ir: CGFloat = cutoutDepth * 0.25
        let or_: CGFloat = 10         // outer panel corner radius

        let sideOverscan = min(1.0, max(0.5, nW * 0.004))
        let nL = rect.midX - nW / 2 - sideOverscan   // notch left edge in panel coords
        let nR = rect.midX + nW / 2 + sideOverscan   // notch right edge in panel coords

        var path = Path()

        // Start at the left edge of the panel at the notch-bottom level and
        // draw clockwise (in screen coordinates) around the entire visible boundary.
        // Going through the notch opening and back creates the cutout automatically
        // using SwiftUI's non-zero winding fill rule.

        path.move(to: CGPoint(x: 0, y: cutoutDepth))

        // ── Left edge upward ──────────────────────────────────────────────────
        path.addLine(to: CGPoint(x: 0, y: or_))
        // Top-left outer corner
        path.addQuadCurve(to: CGPoint(x: or_, y: 0), control: CGPoint(x: 0, y: 0))

        // ── Top edge to notch ──────────────────────────────────────────────────
        path.addLine(to: CGPoint(x: nL, y: 0))

        // ── Down notch left inner edge ────────────────────────────────────────
        path.addLine(to: CGPoint(x: nL, y: cutoutDepth - ir))
        // Inner bottom-left corner
        path.addQuadCurve(to: CGPoint(x: nL + ir, y: cutoutDepth),
                          control: CGPoint(x: nL, y: cutoutDepth))

        // ── Notch bottom ──────────────────────────────────────────────────────
        path.addLine(to: CGPoint(x: nR - ir, y: cutoutDepth))
        // Inner bottom-right corner
        path.addQuadCurve(to: CGPoint(x: nR, y: cutoutDepth - ir),
                          control: CGPoint(x: nR, y: cutoutDepth))

        // ── Up notch right inner edge ─────────────────────────────────────────
        path.addLine(to: CGPoint(x: nR, y: 0))

        // ── Top edge to right side ────────────────────────────────────────────
        path.addLine(to: CGPoint(x: rect.width - or_, y: 0))
        // Top-right outer corner
        path.addQuadCurve(to: CGPoint(x: rect.width, y: or_),
                          control: CGPoint(x: rect.width, y: 0))

        // ── Right edge downward ───────────────────────────────────────────────
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - or_))
        // Bottom-right outer corner
        path.addQuadCurve(to: CGPoint(x: rect.width - or_, y: rect.height),
                          control: CGPoint(x: rect.width, y: rect.height))

        // ── Bottom edge ───────────────────────────────────────────────────────
        path.addLine(to: CGPoint(x: or_, y: rect.height))
        // Bottom-left outer corner
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.height - or_),
                          control: CGPoint(x: 0, y: rect.height))

        // ── Left edge back to start ───────────────────────────────────────────
        path.addLine(to: CGPoint(x: 0, y: cutoutDepth))
        path.closeSubpath()

        return path
    }
}
