import AppKit
import Combine
import QuartzCore
import SwiftUI

struct PrompterContentView: View {
  let script: Script
  let appearance: OverlayAppearance
  let countdownDuration: Int
  let topContentInset: CGFloat
  let voiceSyncEnabled: Bool
  let autoScrollWPM: Double
  @ObservedObject var playheadCoordinator: SessionPlayheadCoordinator
  @ObservedObject var scrollCoordinator: SessionScrollCoordinator
  let reportsPrimaryMetrics: Bool
  let scrollPresentation: PrompterScrollPresentation
  let showsEmbeddedAudioIndicator: Bool
  let syncsSessionScroll: Bool
  let manualAutoScrollEnabled: Bool
  let textExitFadeHeight: CGFloat
  let voiceSyncMode: VoiceSyncMode
  @ObservedObject var voiceSync: VoiceSyncEngine
  @ObservedObject var audioMonitor: AudioLevelMonitor

  @State private var sessionStarted: Bool = false
  @State private var isHovered: Bool = false
  @State private var displayedScrollOffset: CGFloat = 0
  @State private var contentHeight: CGFloat = 0
  @State private var viewportHeight: CGFloat = 0
  @State private var viewportWidth: CGFloat = 0
  @State private var lineMetrics: [LineMetric] = []
  @State private var renderedPrompterText: Text = Text("")
  @State private var cinematicController = CinematicScrollController()
  @State private var manualScrollDriver = ManualScrollDriver()

  init(
    script: Script,
    appearance: OverlayAppearance,
    countdownDuration: Int,
    topContentInset: CGFloat = 0,
    voiceSyncEnabled: Bool = true,
    autoScrollWPM: Double = 0,
    playheadCoordinator: SessionPlayheadCoordinator,
    scrollCoordinator: SessionScrollCoordinator,
    reportsPrimaryMetrics: Bool = false,
    scrollPresentation: PrompterScrollPresentation = .topAnchored,
    showsEmbeddedAudioIndicator: Bool = true,
    syncsSessionScroll: Bool = false,
    manualAutoScrollEnabled: Bool = true,
    textExitFadeHeight: CGFloat = 0,
    voiceSyncMode: VoiceSyncMode = .voice,
    voiceSync: VoiceSyncEngine,
    audioMonitor: AudioLevelMonitor
  ) {
    self.script = script
    self.appearance = appearance
    self.countdownDuration = countdownDuration
    self.topContentInset = topContentInset
    self.voiceSyncEnabled = voiceSyncEnabled
    self.autoScrollWPM = autoScrollWPM
    self.playheadCoordinator = playheadCoordinator
    self.scrollCoordinator = scrollCoordinator
    self.reportsPrimaryMetrics = reportsPrimaryMetrics
    self.scrollPresentation = scrollPresentation
    self.showsEmbeddedAudioIndicator = showsEmbeddedAudioIndicator
    self.syncsSessionScroll = syncsSessionScroll
    self.manualAutoScrollEnabled = manualAutoScrollEnabled
    self.textExitFadeHeight = textExitFadeHeight
    self.voiceSyncMode = voiceSyncMode
    self.voiceSync = voiceSync
    self.audioMonitor = audioMonitor
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

  private var usesLegacyLineSyncForVoice: Bool {
    false
  }

  private var isVoiceMotionActive: Bool {
    (audioMonitor.isSpeaking || voiceSync.isHumanSpeechActive) && !voiceSync.isPausedByUser
  }

  private var shouldRunVoiceMotion: Bool {
    ownsSynchronizedScroll && sessionStarted && voiceSyncEnabled && isVoiceMotionActive
      && !isHovered
  }

  private var renderedScrollOffset: CGFloat {
    usesDirectPlayheadRendering ? CGFloat(playheadCoordinator.progress) : displayedScrollOffset
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
                  .background(
                    GeometryReader { contentGeometry in
                      Color.clear
                        .preference(
                          key: PrompterContentHeightPreferenceKey.self,
                          value: contentGeometry.size.height
                        )
                    }
                  )
                Spacer(minLength: 0)
              }
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .offset(
                y: baseContentOffset(for: textGeometry.size.height)
                  - scrollDistance(for: textGeometry.size.height)
              )
              .clipped()
              .mask(alignment: .top) {
                textExitFadeMask(readableHeight: textGeometry.size.height)
              }
              .onAppear {
                viewportHeight = textGeometry.size.height
                viewportWidth = textGeometry.size.width
                updatePrimaryMetrics()
                updateLineMetrics(width: textGeometry.size.width)
                updatePlayheadSnapshot()
              }
              .onChange(of: textGeometry.size) { _, newSize in
                viewportHeight = newSize.height
                viewportWidth = newSize.width
                updatePrimaryMetrics()
                updateLineMetrics(width: newSize.width)
                updatePlayheadSnapshot()
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onPreferenceChange(PrompterContentHeightPreferenceKey.self) { newHeight in
              contentHeight = newHeight
              updatePrimaryMetrics()
            }

            if showsEmbeddedAudioIndicator {
              VisualBeamView(level: audioMonitor.level)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
          }
        }

        if !sessionStarted {
          CountdownView(
            duration: countdownDuration,
            appearance: appearance
          ) {
            sessionStarted = true
            startVoiceSubsystemIfNeeded()
            startAutoScrollIfNeeded()
          }
        }
      }
      .background(
        ZStack {
          ManualScrollDisplayLinkHost(driver: manualScrollDriver)
          ScrollWheelInterceptor(
            onScroll: { deltaY in
              guard sessionStarted else { return }
              manualScroll(deltaY: deltaY)
            }
          )
        }
      )
      .onChange(of: voiceSync.currentWordIndex) { _, newIndex in
        handleWordIndexUpdate(newIndex)
      }
      .onChange(of: voiceSync.isHumanSpeechActive) { _, speaking in
        guard sessionStarted, voiceSyncEnabled else { return }
        guard ownsSynchronizedScroll else {
          cinematicController.setSpeaking(false)
          return
        }
        cinematicController.setSpeaking(shouldRunVoiceMotion)
      }
      .onChange(of: audioMonitor.isSpeaking) { _, _ in
        guard sessionStarted, voiceSyncEnabled else { return }
        guard ownsSynchronizedScroll else {
          cinematicController.setSpeaking(false)
          return
        }
        cinematicController.setSpeaking(shouldRunVoiceMotion)
      }
      .onChange(of: voiceSync.manualLineNudgeID) { _, _ in
        guard sessionStarted else { return }
        guard ownsSynchronizedScroll else { return }
        applyManualLineNudge(direction: voiceSync.manualLineNudgeDirection)
      }
      .onHover { hovered in
        isHovered = hovered
        manualScrollDriver.setAutoScrollSuppressed(hovered)
        if voiceSyncEnabled {
          cinematicController.setSpeaking(shouldRunVoiceMotion)
        }
        if hovered == false && !usesDirectPlayheadRendering {
          displayedScrollOffset = fallbackDisplayedScrollOffset()
        }
      }
      .onAppear {
        if !usesDirectPlayheadRendering {
          displayedScrollOffset = fallbackDisplayedScrollOffset()
        }
        updatePrimaryMetrics()
        updateLineMetrics(width: viewportWidth)
        updateRenderedPrompterText()

        cinematicController.configure(
          wpm: autoScrollWPM,
          contentHeight: contentHeight,
          viewportHeight: viewportHeight,
          fontSize: appearance.fontSize,
          pointsPerWord: pointsPerWordFromRenderedLines()
        )
        cinematicController.setInitialOffset(renderedScrollOffset)
        cinematicController.onScrollTick = { newOffset in
          if voiceSyncEnabled {
            playheadCoordinator.updateProgress(Double(newOffset))
          } else {
            displayedScrollOffset = newOffset
            if usesLegacyLineSyncForVoice {
              publishCurrentLineIndex()
            }
          }
          voiceSync.nudgeScroll(to: newOffset)
        }
        manualScrollDriver.onScrollTick = { newOffset in
          if usesSessionPlayheadForManualScroll {
            playheadCoordinator.updateProgress(Double(newOffset))
          } else {
            displayedScrollOffset = newOffset
            if usesLegacyLineSyncForVoice {
              publishCurrentLineIndex()
            }
            voiceSync.nudgeScroll(to: newOffset)
          }
        }
        manualScrollDriver.setCurrentOffset(renderedScrollOffset)
        manualScrollDriver.setAutoScrollSuppressed(isHovered)
        updateManualScrollDriver()

        if countdownDuration == 0 {
          sessionStarted = true
          startVoiceSubsystemIfNeeded()
          startAutoScrollIfNeeded()
        }
      }
      .onDisappear {
        manualScrollDriver.stop()
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
        updateLineMetrics(width: viewportWidth)
        updateRenderedPrompterText()
        cinematicController.stop()
        updateManualScrollDriver()
      }
      .onChange(of: script.body) { _, _ in
        updateLineMetrics(width: viewportWidth)
        updateRenderedPrompterText()
        updateManualScrollDriver()
      }
      .onChange(of: appearance) { _, _ in
        updateLineMetrics(width: viewportWidth)
        updateRenderedPrompterText()
        updateManualScrollDriver()
      }
      .onChange(of: sessionStarted) { _, _ in
        updateManualScrollDriver()
      }
      .onChange(of: autoScrollWPM) { _, _ in
        updateManualScrollDriver()
      }
      .onChange(of: voiceSyncEnabled) { _, _ in
        updateManualScrollDriver()
      }
      .onChange(of: voiceSync.isPausedByUser) { _, isPausedByUser in
        playheadCoordinator.setPaused(isPausedByUser)
        cinematicController.setSpeaking(shouldRunVoiceMotion)
        updateManualScrollDriver()
      }
      .onChange(of: scrollCoordinator.synchronizedLineIndex) { _, newLineIndex in
        guard usesLegacyLineSyncForVoice else { return }
        guard !followsSessionPlayheadForManualScroll else { return }
        guard !ownsSynchronizedScroll else { return }
        guard newLineIndex >= 0, newLineIndex < lineMetrics.count else { return }
        let maxOffset = max(contentHeight - viewportHeight, 0)
        guard maxOffset > 0 else { return }
        let targetLine = lineMetrics[newLineIndex]
        let newOffset = min(targetLine.y / maxOffset, 1.0)
        guard abs(displayedScrollOffset - newOffset) > 0.001 else { return }
        displayedScrollOffset = newOffset
      }
      .onChange(of: contentHeight) { _, _ in
        updatePlayheadSnapshot()
        updateManualScrollDriver()
      }
      .onChange(of: viewportHeight) { _, _ in
        updatePlayheadSnapshot()
        updateManualScrollDriver()
      }
      .onChange(of: playheadCoordinator.progress) { _, newProgress in
        guard
          usesSessionPlayheadForManualScroll || followsSessionPlayheadForManualScroll
            || sessionStarted && voiceSyncEnabled
        else { return }
        let newOffset = CGFloat(newProgress)
        manualScrollDriver.setCurrentOffset(newOffset)
        if voiceSyncEnabled && ownsSynchronizedScroll {
          cinematicController.setInitialOffset(newOffset)
        }
        if usesSessionPlayheadForManualScroll {
          if usesLegacyLineSyncForVoice {
            publishCurrentLineIndex()
            voiceSync.nudgeScroll(to: newOffset)
          }
        } else if voiceSyncEnabled && (ownsSynchronizedScroll || !syncsSessionScroll) {
          voiceSync.nudgeScroll(to: newOffset)
        }
      }
      .onChange(of: displayedScrollOffset) { _, newOffset in
        guard !usesDirectPlayheadRendering else { return }
        manualScrollDriver.setCurrentOffset(newOffset)
        updatePlayheadSnapshot(progressOnly: true)
      }
    }
  }

  // MARK: - Voice-Sync Scrolling

  private func handleWordIndexUpdate(_ newIndex: Int?) {
    guard sessionStarted else { return }
    guard isHovered == false else { return }
    guard voiceSyncEnabled else { return }
    guard !voiceSync.isPausedByUser else { return }
    guard ownsSynchronizedScroll else { return }
    guard let idx = newIndex, !lineMetrics.isEmpty else { return }

    guard let lineIndex = lineMetrics.firstIndex(where: { $0.wordRange.contains(idx) }) else {
      return
    }

    let maxOffset = max(contentHeight - viewportHeight, 0)
    guard maxOffset > 0 else { return }

    let trueAnchorLine = lineMetrics[lineIndex]

    // If blank lines follow this line, advance the anchor to the first speakable
    // line after the gap (≥3 blank lines). The cinematic controller's aggressive
    // catch-up will then traverse the gap quickly once speech resumes.
    var anchorY = trueAnchorLine.y
    let lookahead = lineMetrics[(lineIndex + 1)...]
    if let nextSpeakableIdx = lookahead.firstIndex(where: { !$0.wordRange.isEmpty }),
      nextSpeakableIdx - lineIndex >= 2
    {
      anchorY = lineMetrics[nextSpeakableIdx].y
    }

    let exactNormalized = min(anchorY / maxOffset, 1.0)
    cinematicController.setAnchorOffset(exactNormalized)
  }

  // MARK: - Manual Scroll (trackpad / mouse wheel)

  private func manualScroll(deltaY: CGFloat) {
    let maxOffset = max(contentHeight - viewportHeight, 0)
    guard maxOffset > 0 else { return }
    guard !syncsSessionScroll || ownsSynchronizedScroll else { return }
    let normalizedDelta = deltaY / maxOffset
    if voiceSyncEnabled {
      let updated = min(max(CGFloat(playheadCoordinator.progress) - normalizedDelta, 0), 1)
      playheadCoordinator.updateProgress(Double(updated))
      voiceSync.nudgeScroll(to: updated)
      if ownsSynchronizedScroll {
        cinematicController.setInitialOffset(updated)
      }
    } else if usesSessionPlayheadForManualScroll {
      playheadCoordinator.nudgeProgress(by: Double(-normalizedDelta))
    } else {
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
      voiceSync.nudgeScroll(to: updated)
      if ownsSynchronizedScroll {
        cinematicController.setInitialOffset(updated)
      }
    } else if usesSessionPlayheadForManualScroll {
      playheadCoordinator.nudgeProgress(by: Double(delta * direction))
    } else {
      manualScrollDriver.enqueueNormalizedDelta(delta * direction)
    }
  }

  // MARK: - Auto-Scroll (WPM-based, when voice sync is off)

  private func pointsPerWordFromRenderedLines() -> Double {
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

  /// Computes normalized playhead velocity from rendered line density instead of
  /// total document duration so longer scripts keep the same perceived pace.
  private func manualAutoScrollVelocityPerSecond() -> CGFloat {
    CGFloat(
      PrompterScrollMath.manualAutoScrollVelocity(
        pointsPerWord: pointsPerWordFromRenderedLines(),
        scrollableRange: Double(max(contentHeight - viewportHeight, 0)),
        autoScrollWPM: autoScrollWPM
      )
    )
  }

  private func startAutoScrollIfNeeded() {
    updateManualScrollDriver()
    updatePlayheadSnapshot()
  }

  private func startVoiceSubsystemIfNeeded() {
    if voiceSyncEnabled {
      voiceSync.start()
    } else {
      voiceSync.startAudioMonitoring()
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

      prompterText
        .lineSpacing(6)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)
        .padding(.top, scrollPresentation == .topAnchored ? topContentInset + 12 : 0)
        .padding(.bottom, trailingReadablePadding(for: readableHeight))
    }
  }

  private func baseContentOffset(for readableHeight: CGFloat) -> CGFloat {
    guard scrollPresentation == .bottomEntry else { return 0 }
    return max(
      readableHeight * 0.34, PrompterScrollMath.lineHeight(fontSize: appearance.fontSize) * 1.6)
  }

  private func trailingReadablePadding(for readableHeight: CGFloat) -> CGFloat {
    let minimumReadableTail = PrompterScrollMath.lineHeight(fontSize: appearance.fontSize) * 3.5

    switch scrollPresentation {
    case .topAnchored:
      return max(readableHeight * 0.38, minimumReadableTail)
    case .bottomEntry:
      return max(readableHeight * 0.58, minimumReadableTail)
    }
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
      lineHeight: PrompterScrollMath.lineHeight(fontSize: appearance.fontSize)
    )

    cinematicController.configure(
      wpm: autoScrollWPM,
      contentHeight: contentHeight,
      viewportHeight: viewportHeight,
      fontSize: appearance.fontSize,
      pointsPerWord: pointsPerWordFromRenderedLines()
    )
    updatePlayheadSnapshot()
    updateManualScrollDriver()
  }

  private func updatePlayheadSnapshot(progressOnly: Bool = false) {
    if !progressOnly, participatesInSessionPlayhead && ownsSynchronizedScroll {
      playheadCoordinator.updateVelocity(Double(manualAutoScrollVelocityPerSecond()))
      playheadCoordinator.setPaused(voiceSync.isPausedByUser)
    }

    let progress = Double(renderedScrollOffset)
    if participatesInSessionPlayhead && ownsSynchronizedScroll {
      playheadCoordinator.updateProgress(progress)
    }
  }

  private func updateLineMetrics(width: CGFloat) {
    guard width > 0 else { return }
    let nsFont =
      NSFont(name: appearance.fontName, size: appearance.fontSize)
      ?? .systemFont(ofSize: appearance.fontSize)
    lineMetrics = PrompterTextMetrics.calculateLines(
      text: PrompterDisplayText.normalizedDisplayBody(from: script.body),
      font: nsFont,
      width: width - 32  // padding(.horizontal, 16) applied at line 278
    )
  }

  /// Publishes the current reading line index to the sync coordinator.
  private func publishCurrentLineIndex() {
    guard syncsSessionScroll, ownsSynchronizedScroll else { return }
    let maxOffset = max(contentHeight - viewportHeight, 0)
    guard maxOffset > 0 else { return }
    let currentY = maxOffset * renderedScrollOffset
    // Find the line closest to the current scroll position
    var bestIndex = 0
    for (i, metric) in lineMetrics.enumerated() {
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
    guard idx >= 0, idx < lineMetrics.count else { return 0 }
    let maxOffset = max(contentHeight - viewportHeight, 0)
    guard maxOffset > 0 else { return 0 }
    return min(lineMetrics[idx].y / maxOffset, 1.0)
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

  private var prompterText: Text {
    renderedPrompterText
  }

  private func updateRenderedPrompterText() {
    renderedPrompterText = PrompterDisplayText.renderedText(
      from: script.body,
      appearance: appearance
    )
  }

  private var startMarker: some View {
    Image(systemName: "triangle.fill")
      .font(.system(size: 9, weight: .bold))
      .foregroundStyle(Color(hex: appearance.textColor).opacity(0.78))
      .rotationEffect(.degrees(180))
      .frame(maxWidth: .infinity)
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
        && !voiceSync.isPausedByUser && ownsSynchronizedScroll
    )
    manualScrollDriver.setAutoScrollSuppressed(isHovered)
  }
}

enum PrompterScrollPresentation {
  case topAnchored
  case bottomEntry
}

private struct PrompterContentHeightPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

private struct PrompterDisplayToken: Equatable {
  let text: String
  let wordIndex: Int?
}

private enum PrompterDisplayText {
  static func renderedText(
    from body: String,
    appearance: OverlayAppearance
  ) -> Text {
    let displayBody = normalizedDisplayBody(from: body)
    var attributed = AttributedString()

    for token in tokens(from: displayBody) {
      attributed.append(
        segmentText(
          for: token,
          appearance: appearance
        )
      )
    }

    return Text(attributed)
  }

  static func normalizedDisplayBody(from body: String) -> String {
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

    return paragraphs.joined(separator: "\n\n")
  }

  static func tokens(from body: String) -> [PrompterDisplayToken] {
    let nsBody = body as NSString
    let regex = try? NSRegularExpression(pattern: "\\s+|\\S+")
    let matches = regex?.matches(in: body, range: NSRange(location: 0, length: nsBody.length)) ?? []
    var nextWordIndex = 0

    return matches.map { match in
      let fragment = nsBody.substring(with: match.range)
      if fragment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return PrompterDisplayToken(text: fragment, wordIndex: nil)
      }

      let wordIndex: Int?
      if VoiceSyncMatching.normalizeToken(fragment) == nil {
        wordIndex = nil
      } else {
        wordIndex = nextWordIndex
        nextWordIndex += 1
      }

      return PrompterDisplayToken(text: fragment, wordIndex: wordIndex)
    }
  }

  private static func segmentText(
    for token: PrompterDisplayToken,
    appearance: OverlayAppearance
  ) -> AttributedString {
    var segment = AttributedString(token.text)
    segment.font = Font.custom(appearance.fontName, size: appearance.fontSize)
    segment.foregroundColor = Color(hex: appearance.textColor)

    return segment
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
  static let lineSpacing: CGFloat = 6

  static func lineHeight(fontSize: CGFloat) -> CGFloat {
    max(fontSize + lineSpacing, 1)
  }

  static func lineNudgeOffset(maxOffset: CGFloat, lineHeight: CGFloat) -> CGFloat {
    guard maxOffset > 0 else { return 0 }
    return min(lineHeight / maxOffset, 1)
  }

  static func manualAutoScrollVelocity(
    pointsPerWord: Double,
    scrollableRange: Double,
    autoScrollWPM: Double
  ) -> Double {
    guard pointsPerWord > 0, scrollableRange > 0, autoScrollWPM > 0 else { return 0 }

    let absolutePixelSpeed = (autoScrollWPM / 60.0) * pointsPerWord
    return absolutePixelSpeed / scrollableRange
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
  let onScroll: (CGFloat) -> Void

  func makeNSView(context: Context) -> ScrollWheelNSView {
    let view = ScrollWheelNSView()
    view.onScroll = onScroll
    return view
  }

  func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
    nsView.onScroll = onScroll
  }
}

/// Installs both a local and global NSEvent scroll-wheel monitor to cover all
/// activation-policy states. Also attempts direct `scrollWheel(with:)` delivery
/// if AppKit routes the event to this view.
final class ScrollWheelNSView: NSView {
  var onScroll: ((CGFloat) -> Void)?
  private var localScrollMonitor: Any?
  private var globalScrollMonitor: Any?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    removeScrollMonitors()

    guard let window else { return }

    // Local monitor — fires when the app processes the event itself (panel
    // receives the scroll because the cursor is over it).
    localScrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
      [weak self] event in
      guard let self else { return event }
      self.handleMonitoredScroll(event, in: window)
      return event
    }

    // Global monitor — fires when another app is active but the cursor
    // is still over our panel (common in .accessory activation policy).
    globalScrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) {
      [weak self] event in
      guard let self else { return }
      self.handleMonitoredScroll(event, in: window)
    }
  }

  deinit {
    removeScrollMonitors()
  }

  override func scrollWheel(with event: NSEvent) {
    handleScroll(event)
  }

  private func handleMonitoredScroll(_ event: NSEvent, in window: NSWindow) {
    let mouseLocation = NSEvent.mouseLocation
    guard window.frame.contains(mouseLocation) else { return }
    handleScroll(event)
  }

  private func handleScroll(_ event: NSEvent) {
    let delta = event.scrollingDeltaY
    let pixelDelta = event.hasPreciseScrollingDeltas ? delta : delta * 10
    onScroll?(pixelDelta)
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
  }
}
