import AppKit
import Combine
import QuartzCore
import SwiftUI

struct PrompterContentView: View {
  let script: Script
  let appearance: OverlayAppearance
  let countdownDuration: Int
  let topContentInset: CGFloat
  let allowsOverlayWheelInput: Bool
  let usesOverlayWheelDeduplication: Bool
  let usesStrictActiveAppWheelSourceRouting: Bool
  let voiceSyncEnabled: Bool
  let spokenWordHighlightingEnabled: Bool
  let pauseOnHoverEnabled: Bool
  let autoScrollWPM: Double
  @ObservedObject var playheadCoordinator: SessionPlayheadCoordinator
  @ObservedObject var scrollCoordinator: SessionScrollCoordinator
  let reportsPrimaryMetrics: Bool
  let scrollPresentation: PrompterScrollPresentation
  let showsEmbeddedAudioIndicator: Bool
  let embeddedAudioIndicatorUsesReservedLane: Bool
  let syncsSessionScroll: Bool
  let manualAutoScrollEnabled: Bool
  let textExitFadeHeight: CGFloat
  let voiceSyncMode: VoiceSyncMode
  @ObservedObject var voiceSync: VoiceSyncEngine
  @ObservedObject var audioMonitor: AudioLevelMonitor
  let launchTrace: SessionLaunchTrace?

  @State private var sessionStarted: Bool = false
  @State private var isPointerInsideOverlay: Bool = false
  @State private var displayedScrollOffset: CGFloat = 0
  @State private var contentHeight: CGFloat = 0
  @State private var viewportHeight: CGFloat = 0
  @State private var viewportWidth: CGFloat = 0
  @State private var layoutSnapshot: OverlayTextLayoutSnapshot = .empty
  @State private var visibleWordRange: Range<Int>?
  @State private var cinematicController = CinematicScrollController()
  @State private var manualScrollDriver = ManualScrollDriver()
  @State private var deferredVoiceStartupTask: Task<Void, Never>?

  private let embeddedAudioIndicatorLaneHeight: CGFloat = 44
  private let embeddedAudioIndicatorTopGap: CGFloat = 10

  init(
    script: Script,
    appearance: OverlayAppearance,
    countdownDuration: Int,
    topContentInset: CGFloat = 0,
    allowsOverlayWheelInput: Bool = true,
    usesOverlayWheelDeduplication: Bool = true,
    usesStrictActiveAppWheelSourceRouting: Bool = false,
    voiceSyncEnabled: Bool = true,
    spokenWordHighlightingEnabled: Bool = false,
    pauseOnHoverEnabled: Bool = true,
    autoScrollWPM: Double = 0,
    playheadCoordinator: SessionPlayheadCoordinator,
    scrollCoordinator: SessionScrollCoordinator,
    reportsPrimaryMetrics: Bool = false,
    scrollPresentation: PrompterScrollPresentation = .topAnchored,
    showsEmbeddedAudioIndicator: Bool = true,
    embeddedAudioIndicatorUsesReservedLane: Bool = false,
    syncsSessionScroll: Bool = false,
    manualAutoScrollEnabled: Bool = true,
    textExitFadeHeight: CGFloat = 0,
    voiceSyncMode: VoiceSyncMode = .voice,
    voiceSync: VoiceSyncEngine,
    audioMonitor: AudioLevelMonitor,
    launchTrace: SessionLaunchTrace? = nil
  ) {
    self.script = script
    self.appearance = appearance
    self.countdownDuration = countdownDuration
    self.topContentInset = topContentInset
    self.allowsOverlayWheelInput = allowsOverlayWheelInput
    self.usesOverlayWheelDeduplication = usesOverlayWheelDeduplication
    self.usesStrictActiveAppWheelSourceRouting = usesStrictActiveAppWheelSourceRouting
    self.voiceSyncEnabled = voiceSyncEnabled
    self.spokenWordHighlightingEnabled = spokenWordHighlightingEnabled
    self.pauseOnHoverEnabled = pauseOnHoverEnabled
    self.autoScrollWPM = autoScrollWPM
    self.playheadCoordinator = playheadCoordinator
    self.scrollCoordinator = scrollCoordinator
    self.reportsPrimaryMetrics = reportsPrimaryMetrics
    self.scrollPresentation = scrollPresentation
    self.showsEmbeddedAudioIndicator = showsEmbeddedAudioIndicator
    self.embeddedAudioIndicatorUsesReservedLane = embeddedAudioIndicatorUsesReservedLane
    self.syncsSessionScroll = syncsSessionScroll
    self.manualAutoScrollEnabled = manualAutoScrollEnabled
    self.textExitFadeHeight = textExitFadeHeight
    self.voiceSyncMode = voiceSyncMode
    self.voiceSync = voiceSync
    self.audioMonitor = audioMonitor
    self.launchTrace = launchTrace
  }

  private var ownsSynchronizedScroll: Bool {
    !syncsSessionScroll || reportsPrimaryMetrics
  }

  private var participatesInSessionPlayhead: Bool {
    syncsSessionScroll
  }

  private var usesSessionPlayheadForManualScroll: Bool {
    sessionStarted && !voiceSyncEnabled && syncsSessionScroll && ownsSynchronizedScroll
  }

  private var followsSessionPlayheadForManualScroll: Bool {
    sessionStarted && !voiceSyncEnabled && syncsSessionScroll && !ownsSynchronizedScroll
  }

  private var usesDirectPlayheadRendering: Bool {
    usesSessionPlayheadForManualScroll
      || followsSessionPlayheadForManualScroll
      || (sessionStarted && voiceSyncEnabled)
  }

  private var usesWordTrackingScroll: Bool {
    voiceSyncEnabled && voiceSync.voiceScrollMode == .wordTracking
  }

  private var usesSoundBasedScroll: Bool {
    voiceSyncEnabled && voiceSync.voiceScrollMode == .soundBased
  }

  private var usesLegacyLineSyncForVoice: Bool {
    false
  }

  private var sharedPauseBlocksAutomaticMotion: Bool {
    OverlayPausePolicy.sharedPauseBlocksAutomaticMotion(
      syncsSessionScroll: syncsSessionScroll,
      voiceSyncEnabled: voiceSyncEnabled,
      isPausedByUser: voiceSync.isPausedByUser
    )
  }

  private var publishesSharedPauseState: Bool {
    OverlayPausePolicy.publishesSharedPauseState(
      syncsSessionScroll: syncsSessionScroll,
      ownsSynchronizedScroll: ownsSynchronizedScroll
    )
  }

  private var isVoiceMotionActive: Bool {
    audioMonitor.isSpeaking && !sharedPauseBlocksAutomaticMotion
  }

  private var shouldRunVoiceMotion: Bool {
    ownsSynchronizedScroll && sessionStarted && usesSoundBasedScroll && isVoiceMotionActive
      && !isHoverPauseActive
  }

  private var isHoverPauseActive: Bool {
    OverlayHoverPausePolicy.isActive(
      pointerInsideOverlay: isPointerInsideOverlay,
      pauseOnHoverEnabled: pauseOnHoverEnabled
    )
  }

  private var renderedScrollOffset: CGFloat {
    usesDirectPlayheadRendering ? CGFloat(playheadCoordinator.progress) : displayedScrollOffset
  }

  private var shouldRestoreRunningSession: Bool {
    PrompterSessionRestorePolicy.shouldRestoreRunningSession(
      sharedSessionStarted: playheadCoordinator.isSessionStarted,
      voiceSyncState: voiceSync.state
    )
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .bottom) {
        Color(hex: appearance.backgroundColor)
          .opacity(appearance.opacity)

        if sessionStarted {
          VStack(spacing: 0) {
            if readableTopInset > 0 {
              Color.clear
                .frame(height: readableTopInset)
            }

            GeometryReader { textGeometry in
              VStack(alignment: .leading, spacing: 0) {
                scrollableContent(readableHeight: textGeometry.size.height)
                Spacer(minLength: 0)
              }
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .offset(
                y: baseContentOffset(for: textGeometry.size.height)
                  - scrollDistance(for: textGeometry.size.height)
              )
              .animation(
                usesWordTrackingScroll ? .spring(response: 0.8, dampingFraction: 0.82) : nil,
                value: renderedScrollOffset
              )
              .clipped()
              .mask(alignment: .top) {
                textExitFadeMask(readableHeight: textGeometry.size.height)
              }
              .onAppear {
                viewportHeight = textGeometry.size.height
                viewportWidth = textGeometry.size.width
                refreshRenderedLayout(width: textGeometry.size.width)
                refreshContentHeight(readableHeight: textGeometry.size.height)
                updatePrimaryMetrics()
                updatePlayheadSnapshot()
                updateVisibleWordTrackingWindow()
              }
              .onChange(of: textGeometry.size) { _, newSize in
                viewportHeight = newSize.height
                viewportWidth = newSize.width
                refreshRenderedLayout(width: newSize.width)
                refreshContentHeight(readableHeight: newSize.height)
                updatePrimaryMetrics()
                updatePlayheadSnapshot()
                updateVisibleWordTrackingWindow()
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsEmbeddedAudioIndicator {
              if embeddedAudioIndicatorUsesReservedLane {
                embeddedAudioIndicatorLane
              } else {
                VisualBeamView(
                  level: audioMonitor.level,
                  barColor: Color(hex: appearance.textColor)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
              }
            }
          }
        }

        if !sessionStarted {
          CountdownView(
            duration: countdownDuration,
            appearance: appearance
          ) {
            sessionStarted = true
            playheadCoordinator.markSessionStarted()
            startVoiceSubsystemIfNeeded()
            startAutoScrollIfNeeded()
          }
        }
      }
      .background(
        ZStack {
          ManualScrollDisplayLinkHost(driver: manualScrollDriver)
          ScrollWheelInterceptor(
            isEnabled: allowsOverlayWheelInput,
            usesEventDeduplication: usesOverlayWheelDeduplication,
            usesStrictActiveAppWheelSourceRouting: usesStrictActiveAppWheelSourceRouting,
            onScroll: { deltaY in
              guard sessionStarted else { return }
              manualScroll(deltaY: deltaY)
            }
          )
        }
      )
      .onChange(of: voiceSync.currentWordIndex) { _, newIndex in
        handleWordIndexUpdate(newIndex)
        updateVisibleWordTrackingWindow()
      }
      .onChange(of: voiceSync.isHumanSpeechActive) { _, speaking in
        guard sessionStarted, usesSoundBasedScroll else { return }
        guard ownsSynchronizedScroll else {
          cinematicController.setSpeaking(false)
          return
        }
        cinematicController.setSpeaking(shouldRunVoiceMotion)
      }
      .onChange(of: audioMonitor.isSpeaking) { _, _ in
        guard sessionStarted, usesSoundBasedScroll else { return }
        guard ownsSynchronizedScroll else {
          cinematicController.setSpeaking(false)
          return
        }
        cinematicController.setSpeaking(shouldRunVoiceMotion)
      }
      .onChange(of: voiceSync.manualLineNudgeID) { _, _ in
        guard sessionStarted else { return }
        guard
          OverlayScrollShortcutPolicy.respondsToManualLineNudges(
            syncsSessionScroll: syncsSessionScroll,
            ownsSynchronizedScroll: ownsSynchronizedScroll
          )
        else { return }
        applyManualLineNudge(direction: voiceSync.manualLineNudgeDirection)
      }
      .onHover { hovered in
        let wasHoverPauseActive = isHoverPauseActive
        isPointerInsideOverlay = hovered
        manualScrollDriver.setAutoScrollSuppressed(isHoverPauseActive)
        if usesSoundBasedScroll {
          cinematicController.setSpeaking(shouldRunVoiceMotion)
        }
        if wasHoverPauseActive && !isHoverPauseActive && !usesDirectPlayheadRendering {
          displayedScrollOffset = fallbackDisplayedScrollOffset()
        }
      }
      .onAppear {
        launchTrace?.mark("prompter.onAppear")
        if shouldRestoreRunningSession {
          sessionStarted = true
          playheadCoordinator.markSessionStarted()
        }

        voiceSync.setRecognitionDrivesScroll(usesWordTrackingScroll)

        if sessionStarted && spokenWordHighlightingEnabled {
          voiceSync.enableRecognitionIfNeeded()
        }

        if !usesDirectPlayheadRendering {
          displayedScrollOffset = fallbackDisplayedScrollOffset()
        }
        refreshRenderedLayout(width: viewportWidth)
        launchTrace?.mark("prompter.afterFirstLayout")
        updatePrimaryMetrics()
        updateVisibleWordTrackingWindow()

        cinematicController.configure(
          pointsPerSecond: autoScrollWPM,
          contentHeight: contentHeight,
          viewportHeight: viewportHeight
        )
        cinematicController.setInitialOffset(renderedScrollOffset)
        cinematicController.onScrollTick = { newOffset in
          if usesSoundBasedScroll {
            playheadCoordinator.updateProgress(Double(newOffset))
          } else {
            displayedScrollOffset = newOffset
            if usesLegacyLineSyncForVoice {
              publishCurrentLineIndex()
            }
          }
          syncVoiceTrackingOffset(newOffset)
        }
        manualScrollDriver.onScrollTick = { newOffset in
          if usesSessionPlayheadForManualScroll {
            playheadCoordinator.updateProgress(Double(newOffset))
          } else {
            displayedScrollOffset = newOffset
            if usesLegacyLineSyncForVoice {
              publishCurrentLineIndex()
            }
            syncVoiceTrackingOffset(newOffset)
          }
        }
        manualScrollDriver.setCurrentOffset(renderedScrollOffset)
        manualScrollDriver.setAutoScrollSuppressed(isHoverPauseActive)
        updateManualScrollDriver()

        if shouldRestoreRunningSession {
          startAutoScrollIfNeeded()
        } else if countdownDuration == 0 {
          sessionStarted = true
          playheadCoordinator.markSessionStarted()
          if PrompterVoiceStartupPolicy.shouldDeferVoiceStartup(
            countdownDuration: countdownDuration)
          {
            startVoiceSubsystemAfterFirstRenderTurnIfNeeded()
          } else {
            startVoiceSubsystemIfNeeded()
          }
          startAutoScrollIfNeeded()
        }
      }
      .onDisappear {
        deferredVoiceStartupTask?.cancel()
        deferredVoiceStartupTask = nil
        cinematicController.stop()
        manualScrollDriver.stop()
        manualScrollDriver.onScrollTick = nil
        if reportsPrimaryMetrics {
          scrollCoordinator.clearPrimaryMetrics()
        }
      }
      .onChange(of: script.id) { _, _ in
        displayedScrollOffset = 0
        sessionStarted = countdownDuration == 0
        manualScrollDriver.reset(to: 0)
        playheadCoordinator.updateProgress(0)
        if usesLegacyLineSyncForVoice && ownsSynchronizedScroll {
          scrollCoordinator.updateSynchronizedLineIndex(0)
        }
        refreshRenderedLayout(width: viewportWidth)
        refreshContentHeight(readableHeight: viewportHeight)
        updatePrimaryMetrics()
        cinematicController.stop()
        updateManualScrollDriver()
        updateVisibleWordTrackingWindow()
      }
      .onChange(of: script.body) { _, _ in
        refreshRenderedLayout(width: viewportWidth)
        refreshContentHeight(readableHeight: viewportHeight)
        updatePrimaryMetrics()
        updateManualScrollDriver()
        updateVisibleWordTrackingWindow()
      }
      .onChange(of: appearance) { _, _ in
        refreshRenderedLayout(width: viewportWidth)
        refreshContentHeight(readableHeight: viewportHeight)
        updatePrimaryMetrics()
        updateManualScrollDriver()
        updateVisibleWordTrackingWindow()
      }
      .onChange(of: sessionStarted) { _, _ in
        updateManualScrollDriver()
      }
      .onChange(of: autoScrollWPM) { _, _ in
        updateManualScrollDriver()
      }
      .onChange(of: voiceSyncEnabled) { _, _ in
        voiceSync.setRecognitionDrivesScroll(usesWordTrackingScroll)
        updateManualScrollDriver()
        updateVisibleWordTrackingWindow()
      }
      .onChange(of: spokenWordHighlightingEnabled) { _, isEnabled in
        if sessionStarted && isEnabled {
          voiceSync.enableRecognitionIfNeeded()
        }
      }
      .onChange(of: voiceSync.isPausedByUser) { _, isPausedByUser in
        if publishesSharedPauseState {
          playheadCoordinator.setPaused(isPausedByUser)
        }
        cinematicController.setSpeaking(shouldRunVoiceMotion)
        updateManualScrollDriver()
      }
      .onChange(of: scrollCoordinator.synchronizedLineIndex) { _, newLineIndex in
        guard usesLegacyLineSyncForVoice else { return }
        guard !followsSessionPlayheadForManualScroll else { return }
        guard !ownsSynchronizedScroll else { return }
        guard newLineIndex >= 0, newLineIndex < layoutSnapshot.lineMetrics.count else { return }
        let maxOffset = max(contentHeight - viewportHeight, 0)
        guard maxOffset > 0 else { return }
        let targetLine = layoutSnapshot.lineMetrics[newLineIndex]
        let newOffset = min(targetLine.y / maxOffset, 1.0)
        guard abs(displayedScrollOffset - newOffset) > 0.001 else { return }
        displayedScrollOffset = newOffset
      }
      .onChange(of: viewportHeight) { _, _ in
        updatePlayheadSnapshot()
        updateManualScrollDriver()
        updateVisibleWordTrackingWindow()
      }
      .onChange(of: playheadCoordinator.progress) { _, newProgress in
        guard
          usesSessionPlayheadForManualScroll || followsSessionPlayheadForManualScroll
            || sessionStarted && voiceSyncEnabled
        else { return }
        let newOffset = CGFloat(newProgress)
        manualScrollDriver.setCurrentOffset(newOffset)
        if usesSoundBasedScroll && ownsSynchronizedScroll {
          cinematicController.setInitialOffset(newOffset)
        }
        if usesSessionPlayheadForManualScroll {
          if usesLegacyLineSyncForVoice {
            publishCurrentLineIndex()
            syncVoiceTrackingOffset(newOffset)
          }
        } else if usesSoundBasedScroll && (ownsSynchronizedScroll || !syncsSessionScroll) {
          syncVoiceTrackingOffset(newOffset)
        }
        updateVisibleWordTrackingWindow()
      }
      .onChange(of: displayedScrollOffset) { _, newOffset in
        guard !usesDirectPlayheadRendering else { return }
        manualScrollDriver.setCurrentOffset(newOffset)
        updatePlayheadSnapshot(progressOnly: true)
        updateVisibleWordTrackingWindow()
      }
    }
  }

  // MARK: - Voice-Sync Scrolling

  private func handleWordIndexUpdate(_ newIndex: Int?) {
    guard sessionStarted else { return }
    guard !isHoverPauseActive else { return }
    guard usesWordTrackingScroll else { return }
    guard !voiceSync.isPausedByUser else { return }
    guard ownsSynchronizedScroll else { return }
    guard let idx = newIndex, !layoutSnapshot.lineMetrics.isEmpty else { return }

    guard
      let exactNormalized = PrompterScrollMath.wordTrackingProgress(
        currentWordIndex: idx,
        lineMetrics: layoutSnapshot.lineMetrics,
        contentHeight: contentHeight,
        viewportHeight: viewportHeight,
        baseContentOffset: baseContentOffset(for: viewportHeight)
      )
    else {
      playheadCoordinator.updateProgress(Double(voiceSync.scrollOffset))
      manualScrollDriver.setCurrentOffset(voiceSync.scrollOffset)
      return
    }
    playheadCoordinator.updateProgress(Double(exactNormalized))
    manualScrollDriver.setCurrentOffset(CGFloat(exactNormalized))
  }

  // MARK: - Manual Scroll (trackpad / mouse wheel)

  private func manualScroll(deltaY: CGFloat) {
    let maxOffset = max(contentHeight - viewportHeight, 0)
    guard maxOffset > 0 else {
      AiraLogger.shared.info(
        "wheel manualScroll dropped reason=noScrollableRange deltaY=\(deltaY) contentHeight=\(contentHeight) viewportHeight=\(viewportHeight)",
        category: "overlay-wheel"
      )
      return
    }
    guard !syncsSessionScroll || ownsSynchronizedScroll else {
      AiraLogger.shared.info(
        "wheel manualScroll dropped reason=syncFollower deltaY=\(deltaY) syncsSessionScroll=\(syncsSessionScroll) ownsSynchronizedScroll=\(ownsSynchronizedScroll)",
        category: "overlay-wheel"
      )
      return
    }
    let normalizedDelta = deltaY / maxOffset
    AiraLogger.shared.info(
      "wheel manualScroll accepted deltaY=\(deltaY) normalizedDelta=\(normalizedDelta) maxOffset=\(maxOffset) voiceSyncEnabled=\(voiceSyncEnabled) usesSessionPlayheadForManualScroll=\(usesSessionPlayheadForManualScroll)",
      category: "overlay-wheel"
    )
    if voiceSyncEnabled {
      let updated = min(max(CGFloat(playheadCoordinator.progress) - normalizedDelta, 0), 1)
      AiraLogger.shared.info(
        "wheel manualScroll path=voice progressBefore=\(playheadCoordinator.progress) progressAfter=\(updated)",
        category: "overlay-wheel"
      )
      playheadCoordinator.updateProgress(Double(updated))
      voiceSync.nudgeScroll(to: updated, resetSpokenTracking: false)
      if ownsSynchronizedScroll {
        cinematicController.setInitialOffset(updated)
      }
    } else if usesSessionPlayheadForManualScroll {
      AiraLogger.shared.info(
        "wheel manualScroll path=sessionPlayhead progressBefore=\(playheadCoordinator.progress) delta=\(-normalizedDelta)",
        category: "overlay-wheel"
      )
      playheadCoordinator.nudgeProgress(by: Double(-normalizedDelta))
    } else {
      AiraLogger.shared.info(
        "wheel manualScroll path=localDriver enqueueDelta=\(-normalizedDelta)",
        category: "overlay-wheel"
      )
      manualScrollDriver.enqueueNormalizedDelta(-normalizedDelta)
    }
  }

  private func applyManualLineNudge(direction: CGFloat) {
    guard direction != 0 else { return }
    let delta = scrollCoordinator.lineNudgeOffset()
    guard delta > 0 else { return }
    guard !syncsSessionScroll || ownsSynchronizedScroll else { return }
    if voiceSyncEnabled {
      let updated = min(max(CGFloat(playheadCoordinator.progress) + (delta * direction), 0), 1)
      playheadCoordinator.updateProgress(Double(updated))
      voiceSync.nudgeScroll(to: updated, resetSpokenTracking: false)
      if ownsSynchronizedScroll {
        cinematicController.setInitialOffset(updated)
      }
    } else if usesSessionPlayheadForManualScroll {
      playheadCoordinator.nudgeProgress(by: Double(delta * direction))
    } else {
      manualScrollDriver.enqueueNormalizedDelta(delta * direction)
    }
  }

  private func syncVoiceTrackingOffset(_ offset: CGFloat) {
    if usesSoundBasedScroll {
      // Passive voice-driven scroll updates should not clear spoken-word visuals.
      // Explicit user scroll/nudge paths still call nudgeScroll directly.
      voiceSync.nudgeScroll(to: offset, resetSpokenTracking: false)
    }
  }

  // MARK: - Auto-Scroll (point-based, when voice sync is off)

  /// Computes normalized playhead velocity from a fixed physical distance per
  /// second so scroll speed stays identical across short and long scripts.
  private func manualAutoScrollVelocityPerSecond() -> CGFloat {
    CGFloat(
      PrompterScrollMath.manualAutoScrollVelocity(
        scrollableRange: Double(max(contentHeight - viewportHeight, 0)),
        pointsPerSecond: autoScrollWPM
      )
    )
  }

  private func startAutoScrollIfNeeded() {
    updateManualScrollDriver()
    updatePlayheadSnapshot()
  }

  private func startVoiceSubsystemIfNeeded() {
    if voiceSync.voiceScrollMode.usesSpeechRecognition(
      spokenWordHighlightingEnabled: spokenWordHighlightingEnabled)
    {
      voiceSync.start()
    } else if voiceSync.voiceScrollMode.usesSoundBasedMotion {
      voiceSync.startAudioMonitoring()
    }
  }

  private func startVoiceSubsystemAfterFirstRenderTurnIfNeeded() {
    deferredVoiceStartupTask?.cancel()
    deferredVoiceStartupTask = Task { @MainActor in
      await Task.yield()
      guard !Task.isCancelled else { return }
      startVoiceSubsystemIfNeeded()
    }
  }

  private func scrollDistance(for vpHeight: CGFloat) -> CGFloat {
    let maxOffset = max(contentHeight - vpHeight, 0)
    return maxOffset * renderedScrollOffset
  }

  private var readableTopInset: CGFloat {
    guard scrollPresentation == .bottomEntry else { return 0 }
    return topContentInset + 12
  }

  @ViewBuilder
  private func scrollableContent(readableHeight: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      startMarker
        .padding(.bottom, 8)

      OverlayStyledTextView(
        attributedText: liveAttributedText,
        width: overlayTextWidth,
        highlightedWordRange: visibleHighlightWordRange,
        currentWordIndex: visibleCurrentWordIndex,
        highlightColor: (NSColor(Color(hex: appearance.textColor)).usingColorSpace(.sRGB) ?? .white)
          .withAlphaComponent(0.58),
        underlineColor: NSColor(Color(hex: appearance.textColor)).usingColorSpace(.sRGB) ?? .white,
        onWordClick: sessionStarted && spokenWordHighlightingEnabled
          ? { clickedWordIndex in
            voiceSync.reseedHighlight(to: clickedWordIndex)
          }
          : nil
      )
      .fixedSize(horizontal: false, vertical: true)
      .frame(
        width: overlayTextWidth,
        height: layoutSnapshot.textHeight,
        alignment: textFrameAlignment
      )
      .frame(maxWidth: .infinity, alignment: textFrameAlignment)
      .padding(.horizontal, appearance.contentPadding)
      .padding(
        .top,
        scrollPresentation == .topAnchored
          ? topContentInset + 12 + appearance.contentPadding
          : 0
      )
      .padding(.bottom, trailingReadablePadding(for: readableHeight) + appearance.contentPadding)
      .shadow(
        color: OverlayTextStyle.shadowColor(for: appearance),
        radius: appearance.textShadow,
        y: OverlayTextStyle.shadowYOffset(for: appearance)
      )
    }
  }

  private func baseContentOffset(for readableHeight: CGFloat) -> CGFloat {
    guard scrollPresentation == .bottomEntry else { return 0 }
    return max(
      readableHeight * 0.34,
      PrompterScrollMath.lineHeight(
        fontSize: appearance.fontSize,
        lineSpacing: appearance.lineSpacing
      ) * 1.6
    )
  }

  private func trailingReadablePadding(for readableHeight: CGFloat) -> CGFloat {
    let minimumReadableTail =
      PrompterScrollMath.lineHeight(
        fontSize: appearance.fontSize,
        lineSpacing: appearance.lineSpacing
      ) * 3.5

    switch scrollPresentation {
    case .topAnchored:
      return max(readableHeight * 0.38, minimumReadableTail)
    case .bottomEntry:
      let reservedIndicatorGap =
        showsEmbeddedAudioIndicator && embeddedAudioIndicatorUsesReservedLane
        ? embeddedAudioIndicatorTopGap : 0
      return max(readableHeight * 0.58, minimumReadableTail) + reservedIndicatorGap
    }
  }

  @ViewBuilder
  private var embeddedAudioIndicatorLane: some View {
    VStack(spacing: 0) {
      Color.clear
        .frame(height: embeddedAudioIndicatorTopGap)

      VisualBeamView(
        level: audioMonitor.level,
        barColor: Color(hex: appearance.textColor)
      )
      .frame(maxWidth: .infinity)
      .frame(height: embeddedAudioIndicatorLaneHeight - embeddedAudioIndicatorTopGap)
    }
    .frame(maxWidth: .infinity)
    .frame(height: embeddedAudioIndicatorLaneHeight)
    .background(
      Color(hex: appearance.backgroundColor)
    )
  }

  @ViewBuilder
  private func textExitFadeMask(readableHeight: CGFloat) -> some View {
    let fadeHeight = min(textExitFadeHeight, readableHeight)

    if fadeHeight <= 0 {
      Rectangle()
        .fill(Color.white)
    } else {
      VStack(spacing: 0) {
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0),
            .init(color: .white, location: 1),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: fadeHeight)

        Rectangle()
          .fill(Color.white)
      }
    }
  }

  private func updatePrimaryMetrics() {
    guard reportsPrimaryMetrics else { return }
    scrollCoordinator.updatePrimaryMetrics(
      contentHeight: contentHeight,
      viewportHeight: viewportHeight,
      lineHeight: PrompterScrollMath.lineHeight(
        fontSize: appearance.fontSize,
        lineSpacing: appearance.lineSpacing
      )
    )

    cinematicController.configure(
      pointsPerSecond: autoScrollWPM,
      contentHeight: contentHeight,
      viewportHeight: viewportHeight
    )
    updatePlayheadSnapshot()
    updateManualScrollDriver()
  }

  private func updatePlayheadSnapshot(progressOnly: Bool = false) {
    if !progressOnly, participatesInSessionPlayhead && ownsSynchronizedScroll {
      playheadCoordinator.updateVelocity(Double(manualAutoScrollVelocityPerSecond()))
      if publishesSharedPauseState {
        playheadCoordinator.setPaused(voiceSync.isPausedByUser)
      }
    }

    let progress = Double(renderedScrollOffset)
    if participatesInSessionPlayhead && ownsSynchronizedScroll {
      playheadCoordinator.updateProgress(progress)
    }
  }

  private func updateLineMetrics(width: CGFloat) {
    _ = width
  }

  private func refreshRenderedLayout(width: CGFloat) {
    let normalized = PrompterDisplayText.normalizedDisplayBody(from: script.body)
    let measuredWidth = max(width - (appearance.contentPadding * 2), 1)
    let snapshot = OverlayTextStyle.layoutSnapshot(
      for: normalized,
      width: measuredWidth,
      appearance: appearance
    )
    layoutSnapshot = adjustedLayoutSnapshot(snapshot)
  }

  /// Publishes the current reading line index to the sync coordinator.
  private func publishCurrentLineIndex() {
    guard syncsSessionScroll, ownsSynchronizedScroll else { return }
    let maxOffset = max(contentHeight - viewportHeight, 0)
    guard maxOffset > 0 else { return }
    let currentY = maxOffset * renderedScrollOffset
    // Find the line closest to the current scroll position
    var bestIndex = 0
    for (i, metric) in layoutSnapshot.lineMetrics.enumerated() {
      if metric.y <= currentY {
        bestIndex = i
      } else {
        break
      }
    }
    scrollCoordinator.updateSynchronizedLineIndex(bestIndex)
  }

  /// Converts the shared synchronized line index into a local offset for this follower window.
  private func syncedFollowerOffset() -> CGFloat {
    let idx = scrollCoordinator.synchronizedLineIndex
    guard idx >= 0, idx < layoutSnapshot.lineMetrics.count else { return 0 }
    let maxOffset = max(contentHeight - viewportHeight, 0)
    guard maxOffset > 0 else { return 0 }
    return min(layoutSnapshot.lineMetrics[idx].y / maxOffset, 1.0)
  }

  private func fallbackDisplayedScrollOffset() -> CGFloat {
    if syncsSessionScroll && !ownsSynchronizedScroll {
      return syncedFollowerOffset()
    }

    if voiceSyncEnabled {
      return voiceSync.scrollOffset
    }

    return displayedScrollOffset
  }

  private var textFrameAlignment: Alignment {
    OverlayTextStyle.frameAlignment(for: appearance)
  }

  private var overlayTextWidth: CGFloat {
    layoutSnapshot.width
  }

  private var liveAttributedText: NSAttributedString {
    OverlayTextStyle.makeAttributedString(
      layoutSnapshot.string,
      appearance: appearance
    )
  }

  private var visibleHighlightWordRange: Range<Int>? {
    guard spokenWordHighlightingEnabled else { return nil }
    return PrompterHighlightWindow.clampedHighlightRange(
      voiceSync.visualHighlightedWordRange,
      toVisibleWordRange: visibleWordRange
    )
  }

  private var visibleCurrentWordIndex: Int? {
    guard spokenWordHighlightingEnabled else { return nil }
    return PrompterHighlightWindow.clampedCurrentWordIndex(
      voiceSync.visualCurrentWordIndex,
      toVisibleWordRange: visibleWordRange
    )
  }

  private var startMarkerHeight: CGFloat {
    9
  }

  private var startMarkerBottomPadding: CGFloat {
    8
  }

  private func adjustedLayoutSnapshot(_ snapshot: OverlayTextLayoutSnapshot)
    -> OverlayTextLayoutSnapshot
  {
    let yOffset = contentLeadingInset
    guard yOffset > 0, !snapshot.lineMetrics.isEmpty else { return snapshot }

    let adjustedMetrics = snapshot.lineMetrics.map { metric in
      LineMetric(
        y: metric.y + yOffset,
        height: metric.height,
        wordRange: metric.wordRange,
        text: metric.text
      )
    }

    return OverlayTextLayoutSnapshot(
      string: snapshot.string,
      attributedText: snapshot.attributedText,
      width: snapshot.width,
      textHeight: snapshot.textHeight,
      lineMetrics: adjustedMetrics,
      pointsPerWord: PrompterScrollMath.pointsPerWord(lineMetrics: adjustedMetrics)
    )
  }

  private var contentLeadingInset: CGFloat {
    let textTopInset =
      scrollPresentation == .topAnchored ? topContentInset + 12 + appearance.contentPadding : 0
    return startMarkerHeight + startMarkerBottomPadding + textTopInset
  }

  private func contentTrailingInset(for readableHeight: CGFloat) -> CGFloat {
    trailingReadablePadding(for: readableHeight) + appearance.contentPadding
  }

  private func computedContentHeight(for readableHeight: CGFloat) -> CGFloat {
    contentLeadingInset + layoutSnapshot.textHeight + contentTrailingInset(for: readableHeight)
  }

  private var startMarker: some View {
    Image(systemName: "triangle.fill")
      .font(.system(size: 9, weight: .bold))
      .foregroundStyle(Color(hex: appearance.textColor).opacity(0.78))
      .rotationEffect(.degrees(180))
      .frame(maxWidth: .infinity)
  }

  private func updateVisibleWordTrackingWindow() {
    guard
      voiceSyncEnabled || spokenWordHighlightingEnabled,
      viewportHeight > 0,
      !layoutSnapshot.lineMetrics.isEmpty
    else { return }

    let visibleTop = max(
      scrollDistance(for: viewportHeight) - baseContentOffset(for: viewportHeight), 0)
    let visibleBottom = visibleTop + viewportHeight
    let visibleLines = layoutSnapshot.lineMetrics.filter { metric in
      let lineBottom = metric.y + metric.height
      return lineBottom > visibleTop && metric.y < visibleBottom
    }

    guard
      let firstVisibleWord = visibleLines.first(where: { !$0.wordRange.isEmpty })?.wordRange
        .lowerBound,
      let lastVisibleWord = visibleLines.last(where: { !$0.wordRange.isEmpty })?.wordRange
        .upperBound
    else {
      visibleWordRange = nil
      return
    }

    let range = firstVisibleWord..<lastVisibleWord
    visibleWordRange = range
    voiceSync.updateVisibleWordRange(range)
  }

  private func updateManualScrollDriver() {
    let scrollable = max(contentHeight - viewportHeight, 0)
    let velocity = manualAutoScrollVelocityPerSecond()
    manualScrollDriver.configure(
      maxOffset: scrollable,
      normalizedVelocityPerSecond: velocity
    )
    manualScrollDriver.autoScrollStep = nil
    manualScrollDriver.setCurrentOffset(renderedScrollOffset)
    manualScrollDriver.setAutoScrollEnabled(
      sessionStarted && !voiceSyncEnabled && manualAutoScrollEnabled && autoScrollWPM > 0
        && !sharedPauseBlocksAutomaticMotion && ownsSynchronizedScroll
    )
    manualScrollDriver.setAutoScrollSuppressed(isHoverPauseActive)
  }

  private func refreshContentHeight(readableHeight: CGFloat) {
    let newHeight = computedContentHeight(for: readableHeight)
    guard abs(contentHeight - newHeight) > 0.5 else { return }
    contentHeight = newHeight
    updatePrimaryMetrics()
    updatePlayheadSnapshot()
    updateManualScrollDriver()
  }
}

enum OverlayWheelInputPolicy {
  static func allowsOverlayWheelInput(
    isNotchWindow: Bool,
    voiceSyncEnabled: Bool,
    spokenWordHighlightingEnabled: Bool
  ) -> Bool {
    true
  }
}

enum OverlayHoverPausePolicy {
  static func isActive(pointerInsideOverlay: Bool, pauseOnHoverEnabled: Bool) -> Bool {
    pointerInsideOverlay && pauseOnHoverEnabled
  }
}

enum OverlayPausePolicy {
  static func sharedPauseBlocksAutomaticMotion(
    syncsSessionScroll: Bool,
    voiceSyncEnabled: Bool,
    isPausedByUser: Bool
  ) -> Bool {
    guard isPausedByUser else { return false }
    return syncsSessionScroll || voiceSyncEnabled
  }

  static func publishesSharedPauseState(
    syncsSessionScroll: Bool,
    ownsSynchronizedScroll: Bool
  ) -> Bool {
    syncsSessionScroll && ownsSynchronizedScroll
  }
}

enum OverlayScrollShortcutPolicy {
  static func respondsToManualLineNudges(
    syncsSessionScroll: Bool,
    ownsSynchronizedScroll: Bool
  ) -> Bool {
    syncsSessionScroll && ownsSynchronizedScroll
  }
}

enum PrompterSessionRestorePolicy {
  static func shouldRestoreRunningSession(
    sharedSessionStarted: Bool,
    voiceSyncState: VoiceSyncEngine.EngineState
  ) -> Bool {
    sharedSessionStarted || voiceSyncState != .idle
  }
}

enum PrompterVoiceStartupPolicy {
  static func shouldDeferVoiceStartup(countdownDuration: Int) -> Bool {
    countdownDuration == 0
  }
}

enum OverlayWheelRoutingPolicy {
  static func usesStrictActiveAppWheelSourceRouting(
    isNotchWindow: Bool,
    voiceSyncEnabled: Bool,
    spokenWordHighlightingEnabled: Bool
  ) -> Bool {
    isNotchWindow && !voiceSyncEnabled && spokenWordHighlightingEnabled
  }
}

enum OverlayWheelDeduplicationPolicy {
  static func usesEventDeduplication(
    isNotchWindow: Bool,
    voiceSyncEnabled: Bool,
    spokenWordHighlightingEnabled: Bool
  ) -> Bool {
    true
  }
}

enum PrompterHighlightWindow {
  static func clampedHighlightRange(
    _ highlightRange: Range<Int>?,
    toVisibleWordRange visibleWordRange: Range<Int>?
  ) -> Range<Int>? {
    // Guardrail: keep classic/manual highlight rendering bounded to visible words.
    // Regressions that pass a full spoken prefix here can repaint large off-screen
    // ranges and make scroll look jerky without any actual scroll-math bug.
    guard let highlightRange, let visibleWordRange else { return nil }
    let lowerBound = max(highlightRange.lowerBound, visibleWordRange.lowerBound)
    let upperBound = min(highlightRange.upperBound, visibleWordRange.upperBound)
    guard lowerBound < upperBound else { return nil }
    return lowerBound..<upperBound
  }

  static func clampedCurrentWordIndex(
    _ currentWordIndex: Int?,
    toVisibleWordRange visibleWordRange: Range<Int>?
  ) -> Int? {
    guard let currentWordIndex, let visibleWordRange else { return nil }
    guard visibleWordRange.contains(currentWordIndex) else { return nil }
    return currentWordIndex
  }
}

enum PrompterScrollPresentation {
  case topAnchored
  case bottomEntry
}

private enum PrompterDisplayText {
  private static let normalizedBodyCache = NSCache<NSString, NSString>()

  static func normalizedDisplayBody(from body: String) -> String {
    if let cached = normalizedBodyCache.object(forKey: body as NSString) {
      return cached as String
    }

    let normalizedNewlines =
      body
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")

    let paragraphs =
      normalizedNewlines
      .components(separatedBy: "\n\n")
      .map { paragraph in
        paragraph
          .split(separator: "\n", omittingEmptySubsequences: true)
          .map { line in
            collapsedWhitespace(String(line)).trimmingCharacters(in: .whitespacesAndNewlines)
          }
          .filter { !$0.isEmpty }
          .joined(separator: " ")
      }
      .filter { !$0.isEmpty }

    let normalized = paragraphs.joined(separator: "\n\n")
    normalizedBodyCache.setObject(normalized as NSString, forKey: body as NSString)
    return normalized
  }

  private static func collapsedWhitespace(_ value: String) -> String {
    value.components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }
}

@MainActor
final class SessionScrollCoordinator: ObservableObject {
  private struct Metrics {
    let contentHeight: CGFloat
    let viewportHeight: CGFloat
    let lineHeight: CGFloat

    var maxOffset: CGFloat {
      max(contentHeight - viewportHeight, 0)
    }
  }

  private var primaryMetrics: Metrics?
  @Published var synchronizedLineIndex: Int = 0

  func updatePrimaryMetrics(contentHeight: CGFloat, viewportHeight: CGFloat, lineHeight: CGFloat) {
    primaryMetrics = Metrics(
      contentHeight: contentHeight,
      viewportHeight: viewportHeight,
      lineHeight: lineHeight
    )
  }

  func clearPrimaryMetrics() {
    primaryMetrics = nil
    synchronizedLineIndex = 0
  }

  func updateSynchronizedLineIndex(_ index: Int) {
    synchronizedLineIndex = max(index, 0)
  }

  func lineNudgeOffset() -> CGFloat {
    guard let primaryMetrics else { return 0 }
    return PrompterScrollMath.lineNudgeOffset(
      maxOffset: primaryMetrics.maxOffset,
      lineHeight: primaryMetrics.lineHeight
    )
  }
}

enum PrompterScrollMath {
  static func lineHeight(fontSize: CGFloat, lineSpacing: CGFloat) -> CGFloat {
    max(fontSize + OverlayLineSpacingConfiguration.clamped(lineSpacing), 1)
  }

  static func lineNudgeOffset(maxOffset: CGFloat, lineHeight: CGFloat) -> CGFloat {
    guard maxOffset > 0 else { return 0 }
    return min(lineHeight / maxOffset, 1)
  }

  static func manualAutoScrollVelocity(
    scrollableRange: Double,
    pointsPerSecond: Double
  ) -> Double {
    guard scrollableRange > 0, pointsPerSecond > 0 else { return 0 }

    return pointsPerSecond / scrollableRange
  }

  static func pointsPerWord(lineMetrics: [LineMetric]) -> Double {
    let speakableLines = lineMetrics.filter { !$0.wordRange.isEmpty }
    guard !speakableLines.isEmpty else { return 0 }

    let totalSpeakableLineHeight = speakableLines.reduce(0.0) { partial, line in
      partial + Double(line.height)
    }
    let totalSpeakableWords = speakableLines.reduce(0) { partial, line in
      partial + (line.wordRange.upperBound - line.wordRange.lowerBound)
    }

    guard totalSpeakableLineHeight > 0, totalSpeakableWords > 0 else { return 0 }
    return totalSpeakableLineHeight / Double(totalSpeakableWords)
  }

  static func wordTrackingProgress(
    currentWordIndex: Int,
    lineMetrics: [LineMetric],
    contentHeight: CGFloat,
    viewportHeight: CGFloat,
    baseContentOffset: CGFloat
  ) -> CGFloat? {
    guard
      let lineIndex = lineMetrics.firstIndex(where: { $0.wordRange.contains(currentWordIndex) })
    else { return nil }

    let maxOffset = max(contentHeight - viewportHeight, 0)
    guard maxOffset > 0 else { return nil }

    let currentLine = lineMetrics[lineIndex]
    let nextSpeakableIndex =
      lineIndex + 1 < lineMetrics.endIndex
      ? lineMetrics[(lineIndex + 1)...].firstIndex(where: { !$0.wordRange.isEmpty })
      : nil
    var anchorY = currentLine.y
    var usesUpperReadingBand = false

    if let nextSpeakableIndex,
      currentWordIndex >= currentLine.wordRange.upperBound - 1
    {
      anchorY = lineMetrics[nextSpeakableIndex].y
      usesUpperReadingBand = true
    } else if let nextSpeakableIndex,
      baseContentOffset + currentLine.y - maxOffset > viewportHeight * 0.68
    {
      anchorY = lineMetrics[nextSpeakableIndex].y
      usesUpperReadingBand = true
    }

    let targetOffset: CGFloat
    if usesUpperReadingBand {
      let upperReadingBandY = viewportHeight * 0.2
      targetOffset = anchorY + baseContentOffset - upperReadingBandY
    } else {
      targetOffset = anchorY
    }

    return min(max(targetOffset / maxOffset, 0), 1.0)
  }
}

@MainActor
final class ManualScrollDriver: NSObject {
  var onScrollTick: ((CGFloat) -> Void)?
  var autoScrollStep: ((CGFloat, CGFloat) -> CGFloat)?

  private weak var hostView: NSView?
  private var displayLink: CADisplayLink?
  private var currentOffset: CGFloat = 0
  private var maxOffset: CGFloat = 0
  private var normalizedVelocityPerSecond: CGFloat = 0
  private var pendingNormalizedDelta: CGFloat = 0
  private var autoScrollEnabled: Bool = false
  private var autoScrollSuppressed: Bool = false

  func attach(to view: NSView) {
    guard hostView !== view || displayLink == nil else { return }
    stop()
    hostView = view
    let link = view.displayLink(target: self, selector: #selector(handleDisplayLink(_:)))
    link.add(to: .main, forMode: .common)
    link.isPaused = false
    displayLink = link
  }

  func configure(maxOffset: CGFloat, normalizedVelocityPerSecond: CGFloat) {
    self.maxOffset = maxOffset
    self.normalizedVelocityPerSecond = normalizedVelocityPerSecond
  }

  func setCurrentOffset(_ offset: CGFloat) {
    currentOffset = min(max(offset, 0), 1)
  }

  func setAutoScrollEnabled(_ enabled: Bool) {
    autoScrollEnabled = enabled
  }

  func setAutoScrollSuppressed(_ suppressed: Bool) {
    autoScrollSuppressed = suppressed
  }

  func enqueueNormalizedDelta(_ delta: CGFloat) {
    pendingNormalizedDelta += delta
  }

  func reset(to offset: CGFloat) {
    pendingNormalizedDelta = 0
    currentOffset = min(max(offset, 0), 1)
    onScrollTick?(currentOffset)
  }

  func stop() {
    displayLink?.invalidate()
    displayLink = nil
    hostView = nil
    pendingNormalizedDelta = 0
    autoScrollEnabled = false
  }

  @objc private func handleDisplayLink(_ displayLink: CADisplayLink) {
    guard maxOffset > 0 else { return }

    let frameDuration =
      displayLink.targetTimestamp > displayLink.timestamp
      ? displayLink.targetTimestamp - displayLink.timestamp
      : displayLink.duration

    var nextOffset = currentOffset

    if pendingNormalizedDelta != 0 {
      nextOffset += pendingNormalizedDelta
      pendingNormalizedDelta = 0
    }

    if autoScrollEnabled && !autoScrollSuppressed && normalizedVelocityPerSecond > 0 {
      if let autoScrollStep {
        nextOffset = autoScrollStep(nextOffset, CGFloat(frameDuration))
      } else {
        nextOffset += normalizedVelocityPerSecond * CGFloat(frameDuration)
      }
    }

    let clampedOffset = min(max(nextOffset, 0), 1)
    guard clampedOffset != currentOffset else { return }

    currentOffset = clampedOffset
    onScrollTick?(clampedOffset)
  }
}

// MARK: - Scroll Wheel Interceptor (AppKit layer)

private struct ManualScrollDisplayLinkHost: NSViewRepresentable {
  let driver: ManualScrollDriver

  func makeNSView(context: Context) -> ManualScrollDisplayLinkNSView {
    let view = ManualScrollDisplayLinkNSView()
    view.driver = driver
    return view
  }

  func updateNSView(_ nsView: ManualScrollDisplayLinkNSView, context: Context) {
    nsView.driver = driver
    if nsView.window != nil {
      driver.attach(to: nsView)
    }
  }
}

private final class ManualScrollDisplayLinkNSView: NSView {
  weak var driver: ManualScrollDriver?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard let driver, window != nil else { return }
    driver.attach(to: self)
  }
}

/// Wraps an NSView whose sole purpose is to discover its enclosing NSWindow and
/// install scroll-wheel event monitors scoped to that window's frame. This is the
/// reliable path for capturing scroll in an overlay panel that runs while the app
/// is in `.accessory` activation policy.
private struct ScrollWheelInterceptor: NSViewRepresentable {
  let isEnabled: Bool
  let usesEventDeduplication: Bool
  let usesStrictActiveAppWheelSourceRouting: Bool
  let onScroll: (CGFloat) -> Void

  func makeNSView(context: Context) -> ScrollWheelNSView {
    let view = ScrollWheelNSView()
    view.onScroll = isEnabled ? onScroll : nil
    view.usesEventDeduplication = usesEventDeduplication
    view.usesStrictActiveAppWheelSourceRouting = usesStrictActiveAppWheelSourceRouting
    return view
  }

  func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
    nsView.onScroll = isEnabled ? onScroll : nil
    nsView.usesEventDeduplication = usesEventDeduplication
    nsView.usesStrictActiveAppWheelSourceRouting = usesStrictActiveAppWheelSourceRouting
    if let forwardingWindow = nsView.window as? OverlayScrollEventForwardingWindow {
      forwardingWindow.overlayScrollEventHandler = { [weak nsView] event in
        let signature = ScrollWheelEventSignature(event: event)
        AiraLogger.shared.info(
          "wheel bridge callback deltaY=\(event.scrollingDeltaY) pixelDeltaY=\(signature.pixelDeltaY)",
          category: "overlay-wheel"
        )
        nsView?.onScroll?(signature.pixelDeltaY)
      }
      forwardingWindow.overlayUsesEventDeduplication = usesEventDeduplication
      forwardingWindow.overlayUsesStrictActiveAppWheelSourceRouting =
        usesStrictActiveAppWheelSourceRouting
      forwardingWindow.refreshOverlayScrollMonitoring()
    }
  }
}

struct ScrollWheelEventSignature: Equatable {
  let eventNumber: Int?
  let timestamp: TimeInterval
  let pixelDeltaY: CGFloat
  let phaseRawValue: UInt
  let momentumPhaseRawValue: UInt

  init(
    eventNumber: Int? = nil,
    timestamp: TimeInterval,
    pixelDeltaY: CGFloat,
    phase: NSEvent.Phase,
    momentumPhase: NSEvent.Phase
  ) {
    self.eventNumber = eventNumber
    self.timestamp = timestamp
    self.pixelDeltaY = pixelDeltaY
    phaseRawValue = phase.rawValue
    momentumPhaseRawValue = momentumPhase.rawValue
  }

  init(event: NSEvent) {
    self.init(event: event, source: nil)
  }

  init(event: NSEvent, source: ScrollWheelMonitorSource?) {
    let delta = event.scrollingDeltaY
    let pixelDelta = event.hasPreciseScrollingDeltas ? delta : delta * 10
    self.init(
      eventNumber: nil,
      timestamp: event.timestamp,
      pixelDeltaY: pixelDelta,
      phase: event.phase,
      momentumPhase: event.momentumPhase
    )
  }

  private var stableEventNumber: Int? {
    guard let eventNumber, eventNumber > 0 else { return nil }
    return eventNumber
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    if let lhsEventNumber = lhs.stableEventNumber, let rhsEventNumber = rhs.stableEventNumber {
      return lhsEventNumber == rhsEventNumber
        && lhs.pixelDeltaY == rhs.pixelDeltaY
        && lhs.phaseRawValue == rhs.phaseRawValue
        && lhs.momentumPhaseRawValue == rhs.momentumPhaseRawValue
    }

    return lhs.timestamp == rhs.timestamp
      && lhs.pixelDeltaY == rhs.pixelDeltaY
      && lhs.phaseRawValue == rhs.phaseRawValue
      && lhs.momentumPhaseRawValue == rhs.momentumPhaseRawValue
  }
}

enum ScrollWheelMonitorSource {
  case directView
  case forwardedWindow
  case local
  case global

  var debugName: String {
    switch self {
    case .directView:
      return "directView"
    case .forwardedWindow:
      return "forwardedWindow"
    case .local:
      return "local"
    case .global:
      return "global"
    }
  }
}

protocol OverlayScrollEventForwardingWindow: AnyObject {
  var overlayScrollEventHandler: ((NSEvent) -> Void)? { get set }
  var overlayUsesEventDeduplication: Bool { get set }
  var overlayUsesStrictActiveAppWheelSourceRouting: Bool { get set }
  func refreshOverlayScrollMonitoring()
}

final class OverlayScrollForwardingPanel: NSPanel, OverlayScrollEventForwardingWindow {
  var overlayScrollEventHandler: ((NSEvent) -> Void)?
  var overlayUsesEventDeduplication = true
  var overlayUsesStrictActiveAppWheelSourceRouting = false

  private var localScrollMonitor: Any?
  private var globalScrollMonitor: Any?
  private var lastHandledScrollDelivery:
    (
      signature: ScrollWheelEventSignature, source: ScrollWheelMonitorSource
    )?
  private var monitoringConfiguration: OverlayScrollMonitoringConfiguration?

  override var canBecomeKey: Bool { true }

  override var canBecomeMain: Bool { true }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .scrollWheel {
      AiraLogger.shared.info(
        "wheel panel sendEvent deltaY=\(event.scrollingDeltaY) phase=\(event.phase.rawValue) momentum=\(event.momentumPhase.rawValue) isKey=\(isKeyWindow) isMain=\(isMainWindow)",
        category: "overlay-wheel"
      )
    }
    super.sendEvent(event)
  }

  deinit {
    removeScrollMonitors()
  }

  func refreshOverlayScrollMonitoring() {
    let newConfiguration = OverlayScrollMonitoringConfiguration(
      usesEventDeduplication: overlayUsesEventDeduplication,
      usesStrictActiveAppWheelSourceRouting: overlayUsesStrictActiveAppWheelSourceRouting,
      hasHandler: overlayScrollEventHandler != nil
    )

    if monitoringConfiguration == newConfiguration,
      localScrollMonitor != nil,
      globalScrollMonitor != nil
    {
      return
    }

    removeScrollMonitors()
    monitoringConfiguration = newConfiguration
    AiraLogger.shared.info(
      "wheel panel refreshMonitoring dedupe=\(newConfiguration.usesEventDeduplication) strictRouting=\(newConfiguration.usesStrictActiveAppWheelSourceRouting) hasHandler=\(newConfiguration.hasHandler)",
      category: "overlay-wheel"
    )

    localScrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
      [weak self] event in
      guard let self else { return event }
      self.handleMonitoredScroll(event, source: .local)
      return event
    }

    globalScrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) {
      [weak self] event in
      self?.handleMonitoredScroll(event, source: .global)
    }
  }

  override func scrollWheel(with event: NSEvent) {
    AiraLogger.shared.info(
      "wheel panel direct deltaY=\(event.scrollingDeltaY) phase=\(event.phase.rawValue) momentum=\(event.momentumPhase.rawValue)",
      category: "overlay-wheel"
    )
    handleScroll(event, source: .forwardedWindow)
    super.scrollWheel(with: event)
  }

  private func handleMonitoredScroll(_ event: NSEvent, source: ScrollWheelMonitorSource) {
    let mouseLocation = NSEvent.mouseLocation
    let mouseInsideWindow = frame.contains(mouseLocation)
    let shouldHandle = ScrollWheelMonitorRouting.shouldHandle(
      source: source,
      usesStrictActiveAppWheelSourceRouting: overlayUsesStrictActiveAppWheelSourceRouting,
      appIsActive: NSApp.isActive,
      mouseIsInsideWindow: mouseInsideWindow
    )
    AiraLogger.shared.info(
      "wheel panel monitored source=\(source.debugName) accepted=\(shouldHandle) appIsActive=\(NSApp.isActive) mouseInside=\(mouseInsideWindow) deltaY=\(event.scrollingDeltaY)",
      category: "overlay-wheel"
    )
    guard shouldHandle else { return }

    handleScroll(event, source: source)
  }

  private func handleScroll(_ event: NSEvent, source: ScrollWheelMonitorSource) {
    guard let overlayScrollEventHandler else {
      AiraLogger.shared.info(
        "wheel panel dropped reason=noHandler source=\(source.debugName) deltaY=\(event.scrollingDeltaY)",
        category: "overlay-wheel"
      )
      return
    }

    guard overlayUsesEventDeduplication else {
      AiraLogger.shared.info(
        "wheel panel pass source=\(source.debugName) dedupe=off deltaY=\(event.scrollingDeltaY)",
        category: "overlay-wheel"
      )
      overlayScrollEventHandler(event)
      return
    }

    let signature = ScrollWheelEventSignature(event: event, source: source)
    let shouldDrop = ScrollWheelDeduplicationPolicy.shouldDrop(
      signature: signature,
      source: source,
      lastDelivery: lastHandledScrollDelivery
    )
    if shouldDrop {
      AiraLogger.shared.info(
        "wheel panel dropped reason=dedupe source=\(source.debugName) deltaY=\(signature.pixelDeltaY) eventNumber=\(String(describing: signature.eventNumber))",
        category: "overlay-wheel"
      )
      return
    }

    lastHandledScrollDelivery = (signature, source)
    AiraLogger.shared.info(
      "wheel panel pass source=\(source.debugName) deltaY=\(signature.pixelDeltaY) eventNumber=\(String(describing: signature.eventNumber))",
      category: "overlay-wheel"
    )
    overlayScrollEventHandler(event)
  }

  private func removeScrollMonitors() {
    if let localScrollMonitor {
      NSEvent.removeMonitor(localScrollMonitor)
      self.localScrollMonitor = nil
    }
    if let globalScrollMonitor {
      NSEvent.removeMonitor(globalScrollMonitor)
      self.globalScrollMonitor = nil
    }
    monitoringConfiguration = nil
  }
}

private struct OverlayScrollMonitoringConfiguration: Equatable {
  let usesEventDeduplication: Bool
  let usesStrictActiveAppWheelSourceRouting: Bool
  let hasHandler: Bool
}

enum ScrollWheelMonitorRouting {
  static func shouldHandle(
    source: ScrollWheelMonitorSource,
    usesStrictActiveAppWheelSourceRouting: Bool,
    appIsActive: Bool,
    mouseIsInsideWindow: Bool
  ) -> Bool {
    guard mouseIsInsideWindow else { return false }

    guard usesStrictActiveAppWheelSourceRouting else { return true }

    switch source {
    case .directView, .forwardedWindow:
      return true
    case .local:
      return appIsActive
    case .global:
      return !appIsActive
    }
  }
}

enum ScrollWheelDeduplicationPolicy {
  static func shouldDrop(
    signature: ScrollWheelEventSignature,
    source: ScrollWheelMonitorSource,
    lastDelivery: (signature: ScrollWheelEventSignature, source: ScrollWheelMonitorSource)?
  ) -> Bool {
    guard let lastDelivery else { return false }
    return signature == lastDelivery.signature && source != lastDelivery.source
  }
}

/// Installs both a local and global NSEvent scroll-wheel monitor to cover all
/// activation-policy states. Also attempts direct `scrollWheel(with:)` delivery
/// if AppKit routes the event to this view.
final class ScrollWheelNSView: NSView {
  var onScroll: ((CGFloat) -> Void)?
  var usesEventDeduplication = true
  var usesStrictActiveAppWheelSourceRouting = false

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if let forwardingWindow = window as? OverlayScrollEventForwardingWindow {
      forwardingWindow.overlayScrollEventHandler = { [weak self] event in
        let signature = ScrollWheelEventSignature(event: event)
        AiraLogger.shared.info(
          "wheel bridge attach callback deltaY=\(event.scrollingDeltaY) pixelDeltaY=\(signature.pixelDeltaY) eventNumber=\(String(describing: signature.eventNumber))",
          category: "overlay-wheel"
        )
        self?.onScroll?(signature.pixelDeltaY)
      }
      forwardingWindow.overlayUsesEventDeduplication = usesEventDeduplication
      forwardingWindow.overlayUsesStrictActiveAppWheelSourceRouting =
        usesStrictActiveAppWheelSourceRouting
      forwardingWindow.refreshOverlayScrollMonitoring()
    }
  }
}
