import SwiftUI

struct PillContentView: View {
    let script: Script
    let appearance: OverlayAppearance
    let defaultAppearance: OverlayAppearance
    let countdownDuration: Int
    let voiceSyncEnabled: Bool
    let autoScrollWPM: Double
    let playheadCoordinator: SessionPlayheadCoordinator
    let scrollCoordinator: SessionScrollCoordinator
    let reportsPrimaryMetrics: Bool
    let mode: PillContentMode
    let voiceSyncMode: VoiceSyncMode
    @ObservedObject var voiceSync: VoiceSyncEngine
    @ObservedObject var audioMonitor: AudioLevelMonitor
    let onClose: () -> Void
    let onAppearanceChange: (OverlayAppearance) -> Void
    let onSwapWithNotch: (() -> Void)?
    let onResetDefaultSize: () -> Void

    @State private var currentAppearance: OverlayAppearance
    @State private var showAppearancePopover: Bool = false
    @State private var showModeIndicator: Bool = false
    @State private var pillWindow: NSWindow?

    init(script: Script, appearance: OverlayAppearance, countdownDuration: Int,
         voiceSyncEnabled: Bool = true,
         autoScrollWPM: Double = 0,
         playheadCoordinator: SessionPlayheadCoordinator,
         scrollCoordinator: SessionScrollCoordinator,
         reportsPrimaryMetrics: Bool = false,
         mode: PillContentMode, voiceSyncMode: VoiceSyncMode = .voice, voiceSync: VoiceSyncEngine, audioMonitor: AudioLevelMonitor,
         onClose: @escaping () -> Void,
         onAppearanceChange: @escaping (OverlayAppearance) -> Void = { _ in },
         onSwapWithNotch: (() -> Void)? = nil,
         defaultAppearance: OverlayAppearance = .default,
         onResetDefaultSize: @escaping () -> Void = { }) {
        self.script = script
        self.appearance = appearance
        self.defaultAppearance = defaultAppearance
        self.countdownDuration = countdownDuration
        self.voiceSyncEnabled = voiceSyncEnabled
        self.autoScrollWPM = autoScrollWPM
        self.playheadCoordinator = playheadCoordinator
        self.scrollCoordinator = scrollCoordinator
        self.reportsPrimaryMetrics = reportsPrimaryMetrics
        self.mode = mode
        self.voiceSyncMode = voiceSyncMode
        self.voiceSync = voiceSync
        self.audioMonitor = audioMonitor
        self.onClose = onClose
        self.onAppearanceChange = onAppearanceChange
        self.onSwapWithNotch = onSwapWithNotch
        self.onResetDefaultSize = onResetDefaultSize
        _currentAppearance = State(initialValue: appearance)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PrompterContentView(
                script: script,
                appearance: currentAppearance,
                countdownDuration: mode == .voiceSync ? countdownDuration : 0,
                voiceSyncEnabled: mode == .voiceSync ? voiceSyncEnabled : false,
                autoScrollWPM: autoScrollWPM,
                playheadCoordinator: playheadCoordinator,
                scrollCoordinator: scrollCoordinator,
                reportsPrimaryMetrics: reportsPrimaryMetrics,
                syncsSessionScroll: mode == .voiceSync,
                manualAutoScrollEnabled: mode == .voiceSync,
                voiceSyncMode: voiceSyncMode,
                voiceSync: voiceSync,
                audioMonitor: audioMonitor
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Content mode indicator badge (top-left, hover only)
            ContentModeIndicator(mode: mode, isVisible: showModeIndicator)
                .padding(6)

            PillResizeHandles(window: pillWindow)
        }
        .background(
            PillWindowAccessor { window in
                pillWindow = window
            }
        )
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.15)) {
                showModeIndicator = hovered
            }
        }
        .contextMenu {
            Button("Appearance…") { showAppearancePopover = true }
            Button("Reset to Defaults") { currentAppearance = defaultAppearance }
            Button("Reset to Default Size") { onResetDefaultSize() }
            if mode != .voiceSync, let onSwapWithNotch {
                Button("Swap Script with Notch") { onSwapWithNotch() }
            }
            Divider()
            Button("Close Pill") { onClose() }
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
                    .position(x: geometry.size.width - cornerSize / 2, y: geometry.size.height - cornerSize / 2)
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
