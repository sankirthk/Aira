import AVFoundation
import AppKit
import Testing

@testable import Aira

private final class ShortcutActionRecorder {
  private(set) var triggeredShortcuts: [String] = []

  func record(_ shortcut: String) {
    triggeredShortcuts.append(shortcut)
  }
}

@MainActor
private final class FakeSpeechRecognitionBackend: PartialSpeechRecognitionBackend {
  var onRecognizedWord: (@MainActor (SpokenWordToken) -> Void)?
  var onRecognizedWords: (@MainActor ([VoiceSyncMatching.RecognizedWord], Bool) -> Void)?
  var onProcessingChanged: (@MainActor (Bool) -> Void)?
  private(set) var prepareCallCount = 0
  private(set) var acceptedAudio: [[Float]] = []
  private(set) var stopCallCount = 0

  func prepare() async throws {
    prepareCallCount += 1
  }

  func acceptAudio(_ samples: [Float]) async {
    acceptedAudio.append(samples)
  }

  func stop() {
    stopCallCount += 1
  }

  func emit(_ word: String, timestamp: TimeInterval = 0, confidence: Float? = 0.9) {
    onRecognizedWord?(SpokenWordToken(word: word, timestamp: timestamp, confidence: confidence))
  }

  func emitPartial(_ words: [String], isFinal: Bool = false, confidence: Float = 0.9) {
    onRecognizedWords?(
      words.map { VoiceSyncMatching.RecognizedWord(token: $0, confidence: confidence) },
      isFinal
    )
  }
}

struct KeyboardShortcutDisplayTests {
  @Test func formatsCommandShiftLetterShortcut() {
    let shortcut = KeyboardShortcutDisplay.string(
      keyCode: 45,
      modifierFlags: [.command, .shift],
      charactersIgnoringModifiers: "n"
    )

    #expect(shortcut == "⌘⇧N")
  }

  @Test func formatsControlOptionSpecialKeyShortcut() {
    let shortcut = KeyboardShortcutDisplay.string(
      keyCode: 49,
      modifierFlags: [.control, .option],
      charactersIgnoringModifiers: " "
    )

    #expect(shortcut == "⌃⌥Space")
  }

  @Test func ignoresModifierOnlyKeys() {
    let shortcut = KeyboardShortcutDisplay.string(
      keyCode: 55,
      modifierFlags: [.command],
      charactersIgnoringModifiers: ""
    )

    #expect(shortcut == nil)
  }

  @Test func matchesStoredShortcutAgainstKeyComponents() {
    #expect(
      KeyboardShortcutDisplay.matches(
        keyCode: 45,
        modifierFlags: [.command, .shift],
        charactersIgnoringModifiers: "n",
        shortcut: "⌘⇧N"
      )
    )
    #expect(
      KeyboardShortcutDisplay.matches(
        keyCode: 45,
        modifierFlags: [.command, .shift],
        charactersIgnoringModifiers: "n",
        shortcut: "⌘⇧P"
      ) == false
    )
  }

  @Test func matchesBareArrowShortcuts() {
    #expect(
      KeyboardShortcutDisplay.matches(
        keyCode: 126,
        modifierFlags: [],
        charactersIgnoringModifiers: nil,
        shortcut: "↑"
      )
    )
    #expect(
      KeyboardShortcutDisplay.matches(
        keyCode: 125,
        modifierFlags: [],
        charactersIgnoringModifiers: nil,
        shortcut: "↓"
      )
    )
  }

  @Test @MainActor func managerShortcutCoordinatorBindsConfiguredShortcutActions() {
    let settings = AppSettings(
      shortcutToggleNotch: "⌘⌥N",
      shortcutTogglePill: "⌘⌥P"
    )
    let recorder = ShortcutActionRecorder()
    let bindings = ManagerShortcutCoordinator.bindings(
      for: settings,
      onToggleNotch: { recorder.record("notch") },
      onTogglePill: { recorder.record("pill") }
    )

    #expect(bindings.map { $0.shortcut } == ["⌘⌥N", "⌘⌥P"])

    for binding in bindings {
      binding.action()
    }

    #expect(recorder.triggeredShortcuts == ["notch", "pill"])
  }

  @Test @MainActor func voiceToggleRepeatSuppressionOnlyAppliesToBindingsThatOptIn() {
    let toggleBinding = KeyboardShortcutMonitor.Binding(
      shortcut: "⌘⇧Space",
      suppressAutoRepeat: true,
      action: {}
    )
    let scrollBinding = KeyboardShortcutMonitor.Binding(
      shortcut: "⌘↑",
      action: {}
    )

    #expect(!KeyboardShortcutMonitor.shouldTriggerBinding(toggleBinding, isAutoRepeat: true))
    #expect(KeyboardShortcutMonitor.shouldTriggerBinding(toggleBinding, isAutoRepeat: false))
    #expect(KeyboardShortcutMonitor.shouldTriggerBinding(scrollBinding, isAutoRepeat: true))
  }

  @Test @MainActor func sessionKeyboardMonitorUsesPassiveEventTapSoEscapeCanReachSystem() {
    #expect(KeyboardShortcutMonitor.eventTapOptions == .listenOnly)
  }

  @Test func lineNudgeMathUsesSingleRenderedLine() {
    let delta = PrompterScrollMath.lineNudgeOffset(
      maxOffset: 400,
      lineHeight: PrompterScrollMath.lineHeight(
        fontSize: 24,
        lineSpacing: OverlayLineSpacingConfiguration.default
      )
    )

    #expect(delta == 0.075)
    #expect(PrompterScrollMath.lineHeight(fontSize: 24, lineSpacing: 0) == 24)
    #expect(PrompterScrollMath.lineHeight(fontSize: 24, lineSpacing: 12) == 36)
    #expect(PrompterScrollMath.lineHeight(fontSize: 24, lineSpacing: -10) == 24)
  }

  @Test func manualVelocityMatchesPixelSpeedAcrossDocumentLengths() {
    let shortVelocity = PrompterScrollMath.manualAutoScrollVelocity(
      scrollableRange: 1_000,
      pointsPerSecond: 50
    )
    let longVelocity = PrompterScrollMath.manualAutoScrollVelocity(
      scrollableRange: 10_000,
      pointsPerSecond: 50
    )

    let shortPixelSpeed = shortVelocity * 1_000
    let longPixelSpeed = longVelocity * 10_000

    #expect(shortPixelSpeed == 50)
    #expect(longPixelSpeed == 50)
  }

  @Test func manualVelocityReturnsZeroForInvalidInputs() {
    #expect(
      PrompterScrollMath.manualAutoScrollVelocity(
        scrollableRange: 0,
        pointsPerSecond: 50
      ) == 0
    )
    #expect(
      PrompterScrollMath.manualAutoScrollVelocity(
        scrollableRange: 1_000,
        pointsPerSecond: 0
      ) == 0
    )
  }

  @Test func overlayTextMeasurementStaysScrollableWithReadabilitySpacing() {
    let text = Array(
      repeating:
        "This is a long teleprompter sentence that should wrap across multiple rendered lines.",
      count: 18
    ).joined(separator: " ")
    let width: CGFloat = 320

    let defaultHeight = OverlayTextStyle.measuredHeight(
      for: text,
      width: width,
      appearance: .default
    )

    let readabilityAppearance = OverlayAppearance(
      textColor: "#F5F2EC",
      backgroundColor: "#849688",
      opacity: 0.75,
      fontName: "CrimsonText-Regular",
      fontSize: 20,
      textAlignment: .justified,
      lineSpacing: 14,
      letterSpacing: 1.5,
      wordSpacing: 6,
      textShadow: 3,
      contentPadding: 24
    )
    let readabilityHeight = OverlayTextStyle.measuredHeight(
      for: text,
      width: width,
      appearance: readabilityAppearance
    )
    let attributed = OverlayTextStyle.makeAttributedString(text, appearance: readabilityAppearance)
    let lineMetrics = PrompterTextMetrics.calculateLines(
      text: text,
      attributedText: attributed,
      width: width
    )

    #expect(defaultHeight > readabilityAppearance.fontSize)
    #expect(readabilityHeight > readabilityAppearance.fontSize * 2)
    #expect(!lineMetrics.isEmpty)

    let renderedBottom = lineMetrics.map { $0.y + $0.height }.max() ?? 0
    #expect(renderedBottom > readabilityAppearance.fontSize * 2)
    #expect(readabilityHeight >= renderedBottom)
  }

  @Test func overlayLayoutSnapshotUnifiesGeometryAndPacingInputs() {
    let text = """
      First line carries words for pace.

      Second paragraph also carries readable tokens.
      """
    let appearance = OverlayAppearance(
      textColor: "#F5F2EC",
      backgroundColor: "#849688",
      opacity: 0.75,
      fontName: "CrimsonText-Regular",
      fontSize: 22,
      textAlignment: .justified,
      lineSpacing: 12,
      letterSpacing: 1.2,
      wordSpacing: 4,
      textShadow: 2,
      contentPadding: 20
    )

    let snapshot = OverlayTextStyle.layoutSnapshot(
      for: text,
      width: 360,
      appearance: appearance
    )

    #expect(snapshot.width == 360)
    #expect(snapshot.string == text)
    #expect(snapshot.textHeight > appearance.fontSize)
    #expect(!snapshot.lineMetrics.isEmpty)
    #expect(snapshot.pointsPerWord > 0)

    let renderedBottom = snapshot.lineMetrics.map { $0.y + $0.height }.max() ?? 0
    #expect(snapshot.textHeight >= renderedBottom)
    #expect(
      snapshot.pointsPerWord
        == PrompterScrollMath.pointsPerWord(lineMetrics: snapshot.lineMetrics)
    )
  }

  @Test func overlayLayoutSnapshotReusesCachedResultForIdenticalInputs() {
    let text = "Launch caching should reuse identical layout work across notch and pill overlays."
    let appearance = OverlayAppearance(
      textColor: "#F5F2EC",
      backgroundColor: "#849688",
      opacity: 0.75,
      fontName: "CrimsonText-Regular",
      fontSize: 22,
      textAlignment: .justified,
      lineSpacing: 12,
      letterSpacing: 1.2,
      wordSpacing: 4,
      textShadow: 2,
      contentPadding: 20
    )

    let first = OverlayTextStyle.layoutSnapshot(
      for: text,
      width: 360,
      appearance: appearance
    )
    let second = OverlayTextStyle.layoutSnapshot(
      for: text,
      width: 360,
      appearance: appearance
    )

    #expect(first.string == second.string)
    #expect(first.width == second.width)
    #expect(first.textHeight == second.textHeight)
    #expect(first.lineMetrics.count == second.lineMetrics.count)
    #expect(first.attributedText === second.attributedText)
  }

  @Test @MainActor func overlayStyledTextTemporaryHighlightDoesNotChangeMeasuredHeight() {
    let text = "alpha beta gamma delta epsilon"
    let attributed = OverlayTextStyle.makeAttributedString(text, appearance: .default)
    let view = OverlayStyledTextContainerView()

    view.configure(
      attributedText: attributed,
      width: 260,
      highlightedWordRange: nil,
      currentWordIndex: nil,
      highlightColor: .systemRed,
      underlineColor: .systemRed,
      onWordClick: nil
    )
    let baseHeight = view.intrinsicContentSize.height

    view.configure(
      attributedText: attributed,
      width: 260,
      highlightedWordRange: 2..<3,
      currentWordIndex: 2,
      highlightColor: .systemRed,
      underlineColor: .systemRed,
      onWordClick: nil
    )

    #expect(view.intrinsicContentSize.height == baseHeight)
  }

  @Test @MainActor func overlayStyledTextExpandedPrefixHighlightDoesNotChangeMeasuredHeight() {
    let text = "alpha beta gamma delta epsilon zeta"
    let attributed = OverlayTextStyle.makeAttributedString(text, appearance: .default)
    let view = OverlayStyledTextContainerView()

    view.configure(
      attributedText: attributed,
      width: 260,
      highlightedWordRange: 0..<2,
      currentWordIndex: 2,
      highlightColor: .systemRed,
      underlineColor: .systemRed,
      onWordClick: nil
    )
    let baseHeight = view.intrinsicContentSize.height

    view.configure(
      attributedText: attributed,
      width: 260,
      highlightedWordRange: 0..<5,
      currentWordIndex: 5,
      highlightColor: .systemRed,
      underlineColor: .systemRed,
      onWordClick: nil
    )

    #expect(view.intrinsicContentSize.height == baseHeight)
  }

  @Test @MainActor func overlayStyledTextKeepsDullColorWhenCurrentWordAdvancesIntoPrefix() throws {
    let text = "alpha beta gamma delta epsilon"
    let attributed = OverlayTextStyle.makeAttributedString(text, appearance: .default)
    let highlightColor = NSColor.systemRed
    let view = OverlayStyledTextContainerView()

    view.configure(
      attributedText: attributed,
      width: 260,
      highlightedWordRange: 0..<2,
      currentWordIndex: 2,
      highlightColor: highlightColor,
      underlineColor: .systemBlue,
      onWordClick: nil
    )

    view.configure(
      attributedText: attributed,
      width: 260,
      highlightedWordRange: 0..<3,
      currentWordIndex: 3,
      highlightColor: highlightColor,
      underlineColor: .systemBlue,
      onWordClick: nil
    )

    let textView = try #require(view.subviews.first as? NSTextView)
    let layoutManager = try #require(textView.layoutManager)
    let gammaLocation = (text as NSString).range(of: "gamma").location
    let color =
      layoutManager.temporaryAttribute(
        .foregroundColor,
        atCharacterIndex: gammaLocation,
        effectiveRange: nil
      ) as? NSColor

    #expect(color == highlightColor)
  }

  @Test func overlayStyledTextCurrentWordUnderlineAttributesStaySeparateFromHistory() {
    let underlineColor = NSColor.labelColor
    let attributes = OverlayStyledTextContainerView.currentWordTemporaryAttributes(
      underlineColor: underlineColor
    )

    #expect(
      (attributes[.underlineStyle] as? Int)
        == (NSUnderlineStyle.single.rawValue | NSUnderlineStyle.thick.rawValue)
    )
    #expect(attributes[.underlineColor] as? NSColor == underlineColor)
    #expect(attributes[.foregroundColor] == nil)
  }

  @Test func prompterHighlightWindowClampsVisualsToVisibleWords() {
    #expect(
      PrompterHighlightWindow.clampedHighlightRange(
        0..<20,
        toVisibleWordRange: 8..<12
      ) == 8..<12
    )
    #expect(
      PrompterHighlightWindow.clampedHighlightRange(
        0..<6,
        toVisibleWordRange: 8..<12
      ) == nil
    )
    #expect(
      PrompterHighlightWindow.clampedCurrentWordIndex(
        9,
        toVisibleWordRange: 8..<12
      ) == 9
    )
    #expect(
      PrompterHighlightWindow.clampedCurrentWordIndex(
        6,
        toVisibleWordRange: 8..<12
      ) == nil
    )
  }

  @Test func prompterHighlightWindowRequiresActiveScriptMatchWhenKnown() {
    let activeScriptID = UUID()
    let otherScriptID = UUID()

    #expect(
      PrompterHighlightWindow.isEnabledForScript(
        requested: true,
        scriptID: activeScriptID,
        activeScriptID: activeScriptID
      )
    )
    #expect(
      !PrompterHighlightWindow.isEnabledForScript(
        requested: true,
        scriptID: otherScriptID,
        activeScriptID: activeScriptID
      )
    )
    #expect(
      PrompterHighlightWindow.isEnabledForScript(
        requested: true,
        scriptID: otherScriptID,
        activeScriptID: nil
      )
    )
    #expect(
      !PrompterHighlightWindow.isEnabledForScript(
        requested: false,
        scriptID: activeScriptID,
        activeScriptID: activeScriptID
      )
    )
  }

  @Test func overlayScrollWheelSignatureDedupesDuplicateDeliveries() {
    let localSignature = ScrollWheelEventSignature(
      eventNumber: 17,
      timestamp: 42.0,
      pixelDeltaY: -12,
      phase: .changed,
      momentumPhase: []
    )
    let directSignature = ScrollWheelEventSignature(
      eventNumber: 17,
      timestamp: 42.0008,
      pixelDeltaY: -12,
      phase: .changed,
      momentumPhase: []
    )
    let nextGestureSignature = ScrollWheelEventSignature(
      eventNumber: 18,
      timestamp: 42.1,
      pixelDeltaY: -12,
      phase: .changed,
      momentumPhase: []
    )

    #expect(localSignature == directSignature)
    #expect(localSignature != nextGestureSignature)
  }

  @Test func overlayScrollWheelSignatureIgnoresZeroEventNumberForDeduping() {
    let firstSignature = ScrollWheelEventSignature(
      eventNumber: 0,
      timestamp: 42.0,
      pixelDeltaY: -12,
      phase: .changed,
      momentumPhase: []
    )
    let secondSignature = ScrollWheelEventSignature(
      eventNumber: 0,
      timestamp: 42.1,
      pixelDeltaY: -12,
      phase: .changed,
      momentumPhase: []
    )
    let duplicateByTimestamp = ScrollWheelEventSignature(
      eventNumber: 0,
      timestamp: 42.0,
      pixelDeltaY: -12,
      phase: .changed,
      momentumPhase: []
    )

    #expect(firstSignature != secondSignature)
    #expect(firstSignature == duplicateByTimestamp)
  }

  @Test func overlayScrollWheelDedupeKeepsRepeatedSameSourceEvents() {
    let signature = ScrollWheelEventSignature(
      eventNumber: 42,
      timestamp: 50.0,
      pixelDeltaY: -10,
      phase: .changed,
      momentumPhase: []
    )
    let lastDelivery = (signature, ScrollWheelMonitorSource.forwardedWindow)

    #expect(
      !ScrollWheelDeduplicationPolicy.shouldDrop(
        signature: signature,
        source: .forwardedWindow,
        lastDelivery: lastDelivery
      )
    )
    #expect(
      ScrollWheelDeduplicationPolicy.shouldDrop(
        signature: signature,
        source: .local,
        lastDelivery: lastDelivery
      )
    )
  }

  @Test func overlayScrollWheelMonitorRoutingPrefersLocalWhenAppActive() {
    #expect(
      ScrollWheelMonitorRouting.shouldHandle(
        source: .local,
        usesStrictActiveAppWheelSourceRouting: true,
        appIsActive: true,
        mouseIsInsideWindow: true
      )
    )
    #expect(
      !ScrollWheelMonitorRouting.shouldHandle(
        source: .global,
        usesStrictActiveAppWheelSourceRouting: true,
        appIsActive: true,
        mouseIsInsideWindow: true
      )
    )
  }

  @Test func overlayScrollWheelMonitorRoutingFallsBackToGlobalWhenAppInactive() {
    #expect(
      !ScrollWheelMonitorRouting.shouldHandle(
        source: .local,
        usesStrictActiveAppWheelSourceRouting: true,
        appIsActive: false,
        mouseIsInsideWindow: true
      )
    )
    #expect(
      ScrollWheelMonitorRouting.shouldHandle(
        source: .global,
        usesStrictActiveAppWheelSourceRouting: true,
        appIsActive: false,
        mouseIsInsideWindow: true
      )
    )
    #expect(
      !ScrollWheelMonitorRouting.shouldHandle(
        source: .global,
        usesStrictActiveAppWheelSourceRouting: true,
        appIsActive: false,
        mouseIsInsideWindow: false
      )
    )
  }

  @Test func overlayScrollWheelMonitorRoutingAllowsBothSourcesOutsideStrictGuard() {
    #expect(
      ScrollWheelMonitorRouting.shouldHandle(
        source: .local,
        usesStrictActiveAppWheelSourceRouting: false,
        appIsActive: true,
        mouseIsInsideWindow: true
      )
    )
    #expect(
      ScrollWheelMonitorRouting.shouldHandle(
        source: .global,
        usesStrictActiveAppWheelSourceRouting: false,
        appIsActive: true,
        mouseIsInsideWindow: true
      )
    )
  }

  @Test func overlayWheelInputRemainsEnabledForNotchAndManualPillModes() {
    #expect(
      OverlayWheelInputPolicy.allowsOverlayWheelInput(
        isNotchWindow: true,
        voiceSyncEnabled: false,
        spokenWordHighlightingEnabled: true
      )
    )
    #expect(
      OverlayWheelInputPolicy.allowsOverlayWheelInput(
        isNotchWindow: false,
        voiceSyncEnabled: false,
        spokenWordHighlightingEnabled: false
      )
    )
    #expect(
      OverlayWheelRoutingPolicy.usesStrictActiveAppWheelSourceRouting(
        isNotchWindow: true,
        voiceSyncEnabled: false,
        spokenWordHighlightingEnabled: true
      )
    )
    #expect(
      !OverlayWheelRoutingPolicy.usesStrictActiveAppWheelSourceRouting(
        isNotchWindow: false,
        voiceSyncEnabled: false,
        spokenWordHighlightingEnabled: false
      )
    )
  }

  @Test func overlayWheelDeduplicationStaysEnabledForNotchAndManualPillModes() {
    #expect(
      OverlayWheelDeduplicationPolicy.usesEventDeduplication(
        isNotchWindow: true,
        voiceSyncEnabled: false,
        spokenWordHighlightingEnabled: true
      )
    )
    #expect(
      OverlayWheelDeduplicationPolicy.usesEventDeduplication(
        isNotchWindow: false,
        voiceSyncEnabled: false,
        spokenWordHighlightingEnabled: false
      )
    )
  }

  @Test func hoverPauseRequiresBothPointerPresenceAndEnabledSetting() {
    #expect(
      OverlayHoverPausePolicy.isActive(
        pointerInsideOverlay: true,
        pauseOnHoverEnabled: true
      )
    )
    #expect(
      !OverlayHoverPausePolicy.isActive(
        pointerInsideOverlay: true,
        pauseOnHoverEnabled: false
      )
    )
    #expect(
      !OverlayHoverPausePolicy.isActive(
        pointerInsideOverlay: false,
        pauseOnHoverEnabled: true
      )
    )
  }

  @Test func manualPillDisablesSpokenWordHighlighting() {
    #expect(
      !PillPrompterBehavior.spokenWordHighlightingEnabled(
        mode: .manual(scriptId: UUID()),
        requested: true
      )
    )
    #expect(
      PillPrompterBehavior.spokenWordHighlightingEnabled(
        mode: .voiceSync,
        requested: true
      )
    )
  }

  @Test func pillWindowsIgnoreHoverPauseSetting() {
    #expect(
      !PillPrompterBehavior.pauseOnHoverEnabled(
        mode: .manual(scriptId: UUID()),
        requested: true
      )
    )
    #expect(
      !PillPrompterBehavior.pauseOnHoverEnabled(
        mode: .voiceSync,
        requested: true
      )
    )
    #expect(
      !PillPrompterBehavior.pauseOnHoverEnabled(
        mode: .voiceSync,
        requested: false
      )
    )
  }

  @Test func sharedPauseOnlyStopsAutomaticMotionForParticipatingOverlays() {
    #expect(
      OverlayPausePolicy.sharedPauseBlocksAutomaticMotion(
        syncsSessionScroll: true,
        voiceSyncEnabled: false,
        isPausedByUser: true
      )
    )
    #expect(
      OverlayPausePolicy.sharedPauseBlocksAutomaticMotion(
        syncsSessionScroll: false,
        voiceSyncEnabled: true,
        isPausedByUser: true
      )
    )
    #expect(
      !OverlayPausePolicy.sharedPauseBlocksAutomaticMotion(
        syncsSessionScroll: false,
        voiceSyncEnabled: false,
        isPausedByUser: true
      )
    )
    #expect(
      !OverlayPausePolicy.sharedPauseBlocksAutomaticMotion(
        syncsSessionScroll: true,
        voiceSyncEnabled: true,
        isPausedByUser: false
      )
    )
  }

  @Test func sharedPausePublishesOnlyFromPrimarySynchronizedOverlays() {
    #expect(
      OverlayPausePolicy.publishesSharedPauseState(
        syncsSessionScroll: true,
        ownsSynchronizedScroll: true
      )
    )
    #expect(
      !OverlayPausePolicy.publishesSharedPauseState(
        syncsSessionScroll: true,
        ownsSynchronizedScroll: false
      )
    )
    #expect(
      !OverlayPausePolicy.publishesSharedPauseState(
        syncsSessionScroll: false,
        ownsSynchronizedScroll: true
      )
    )
  }

  @Test func sessionScrollShortcutsOnlyNudgePrimarySynchronizedOverlays() {
    #expect(
      OverlayScrollShortcutPolicy.respondsToManualLineNudges(
        syncsSessionScroll: true,
        ownsSynchronizedScroll: true
      )
    )
    #expect(
      !OverlayScrollShortcutPolicy.respondsToManualLineNudges(
        syncsSessionScroll: true,
        ownsSynchronizedScroll: false
      )
    )
    #expect(
      !OverlayScrollShortcutPolicy.respondsToManualLineNudges(
        syncsSessionScroll: false,
        ownsSynchronizedScroll: true
      )
    )
  }

  @Test func syncClassicPillUsesSyncBadgeAndSuppressesVoiceLane() {
    #expect(
      PillChromePolicy.badge(
        mode: .voiceSync,
        voiceSyncEnabled: false
      ) == .sync
    )
    #expect(
      !PillChromePolicy.showsEmbeddedAudioIndicator(
        mode: .voiceSync,
        voiceSyncEnabled: false
      )
    )
    #expect(
      PillChromePolicy.badge(
        mode: .voiceSync,
        voiceSyncEnabled: true
      ) == .voice
    )
    #expect(
      PillChromePolicy.showsEmbeddedAudioIndicator(
        mode: .voiceSync,
        voiceSyncEnabled: true
      )
    )
  }

  @Test func manualPointsPerWordUsesSpeakableRenderedLines() {
    let lineMetrics = [
      LineMetric(y: 0, height: 24, wordRange: 0..<4, text: "one two three four"),
      LineMetric(y: 36, height: 24, wordRange: 4..<4, text: ""),
      LineMetric(y: 72, height: 24, wordRange: 4..<7, text: "five six seven"),
    ]

    let pointsPerWord = PrompterScrollMath.pointsPerWord(lineMetrics: lineMetrics)

    #expect(pointsPerWord == 48.0 / 7.0)
    #expect(pointsPerWord < 72.0 / 7.0)
    #expect(PrompterScrollMath.pointsPerWord(lineMetrics: []) == 0)
  }

  @Test func wordTrackingProgressAdvancesAtRenderedLineEnd() {
    let lineMetrics = [
      LineMetric(y: 0, height: 24, wordRange: 0..<3, text: "one two three"),
      LineMetric(y: 48, height: 24, wordRange: 3..<3, text: ""),
      LineMetric(y: 96, height: 24, wordRange: 3..<6, text: "four five six"),
    ]

    let progress = PrompterScrollMath.wordTrackingProgress(
      currentWordIndex: 2,
      lineMetrics: lineMetrics,
      contentHeight: 240,
      viewportHeight: 120,
      baseContentOffset: 40
    )
    let middleProgress = PrompterScrollMath.wordTrackingProgress(
      currentWordIndex: 1,
      lineMetrics: lineMetrics,
      contentHeight: 240,
      viewportHeight: 120,
      baseContentOffset: 40
    )

    #expect(progress == 14.0 / 15.0)
    #expect(middleProgress == 0)
  }

  @Test func wordTrackingProgressKeepsLineEndTargetInUpperReadingBand() {
    let lineMetrics = [
      LineMetric(y: 0, height: 24, wordRange: 0..<3, text: "one two three"),
      LineMetric(y: 48, height: 24, wordRange: 3..<3, text: ""),
      LineMetric(y: 96, height: 24, wordRange: 3..<6, text: "four five six"),
    ]

    let progress = PrompterScrollMath.wordTrackingProgress(
      currentWordIndex: 2,
      lineMetrics: lineMetrics,
      contentHeight: 240,
      viewportHeight: 120,
      baseContentOffset: 40
    )

    #expect(progress == 14.0 / 15.0)
  }

  @Test func wordTrackingProgressCanClampToRevealFinalParagraph() {
    let lineMetrics = [
      LineMetric(y: 0, height: 24, wordRange: 0..<4, text: "first paragraph ends here"),
      LineMetric(y: 56, height: 24, wordRange: 4..<4, text: ""),
      LineMetric(y: 132, height: 24, wordRange: 4..<7, text: "final paragraph starts"),
    ]

    let progress = PrompterScrollMath.wordTrackingProgress(
      currentWordIndex: 3,
      lineMetrics: lineMetrics,
      contentHeight: 240,
      viewportHeight: 120,
      baseContentOffset: 40
    )

    #expect(progress == 1.0)
  }

  @Test func monotonicWordTrackingProgressBlocksBackwardCorrectionUntilManualReseed() {
    let correction = PrompterScrollMath.monotonicWordTrackingProgress(
      exactProgress: 0.42,
      currentProgress: 0.50,
      highestProgress: 0.50,
      lastWordIndex: 8,
      currentWordIndex: 9
    )

    #expect(correction.targetProgress == 0.50)
    #expect(correction.highestProgress == 0.50)
    #expect(correction.lastWordIndex == 9)

    let reseed = PrompterScrollMath.monotonicWordTrackingProgress(
      exactProgress: 0.20,
      currentProgress: 0.50,
      highestProgress: 0.50,
      lastWordIndex: 9,
      currentWordIndex: 3
    )

    #expect(reseed.targetProgress == 0.20)
    #expect(reseed.highestProgress == 0.20)
    #expect(reseed.lastWordIndex == 3)
  }
}

struct VoiceSyncMatchingTests {
  @Test func tokenizeStripsPunctuationLowercasesAndSplits() {
    let tokens = VoiceSyncMatching.tokenize("Hello, WORLD!  This... is a test.")

    #expect(tokens == ["hello", "world", "this", "is", "a", "test"])
  }

  @Test func tokenizeHandlesEmptyString() {
    #expect(VoiceSyncMatching.tokenize("").isEmpty)
  }

  @Test func tokenizeSkipsCueAnnotations() {
    let tokens = VoiceSyncMatching.tokenize("Hello [pause] world [breath]")

    #expect(tokens == ["hello", "world"])
  }

  @Test func exactMatchAdvancesCursorToMatchedWindowEnd() {
    let scriptWords = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
    let spokenWindow = ["four", "five", "six", "seven", "eight", "nine"]

    let match = VoiceSyncMatching.findMatch(
      scriptWords: scriptWords,
      spokenWindow: spokenWindow,
      cursorIndex: 0
    )

    #expect(match == 9)
  }

  @Test func fuzzyMatchAdvancesToBestOverlapPosition() {
    let scriptWords = ["the", "team", "shares", "the", "latest", "numbers", "today"]
    let spokenWindow = ["team", "shares", "the", "greatest", "numbers"]

    let match = VoiceSyncMatching.findMatch(
      scriptWords: scriptWords,
      spokenWindow: spokenWindow,
      cursorIndex: 0
    )

    #expect(match == 6)
  }

  @Test func cursorOnlyMovesForward() {
    let scriptWords = ["alpha", "beta", "gamma", "beta", "gamma", "delta"]
    let spokenWindow = ["beta", "gamma", "delta"]

    let match = VoiceSyncMatching.findMatch(
      scriptWords: scriptWords,
      spokenWindow: spokenWindow,
      cursorIndex: 3
    )

    #expect(match == 6)
  }

  @Test func noMatchReturnsNil() {
    let match = VoiceSyncMatching.findMatch(
      scriptWords: ["alpha", "beta", "gamma"],
      spokenWindow: ["zeta", "eta", "theta"],
      cursorIndex: 0
    )

    #expect(match == nil)
  }

  @Test func scrollOffsetCanRemainProportionalWithoutLookahead() {
    let offset = VoiceSyncMatching.scrollOffset(
      cursorIndex: 25,
      totalWords: 100,
      lookaheadWords: 0
    )

    #expect(offset == 0.25)
  }

  @Test func scrollOffsetUsesBoundedOpticalLookaheadByDefault() {
    let offset = VoiceSyncMatching.scrollOffset(cursorIndex: 25, totalWords: 100)
    let endOffset = VoiceSyncMatching.scrollOffset(cursorIndex: 98, totalWords: 100)
    let shortScriptOffset = VoiceSyncMatching.scrollOffset(cursorIndex: 0, totalWords: 15)

    #expect(offset == 0.40)
    #expect(endOffset == 1.0)
    #expect(shortScriptOffset == 0)
  }

  @Test @MainActor func voiceSyncInputTapBufferSizeUsesLowerLatency128Frames() {
    #expect(VoiceSyncEngine.inputTapBufferSize == 128)
  }

  @Test @MainActor func speechRecognitionBackendFakeCanEmitStableWordTokens() async throws {
    let backend = FakeSpeechRecognitionBackend()
    var emitted: [SpokenWordToken] = []
    backend.onRecognizedWord = { token in
      emitted.append(token)
    }

    try await backend.prepare()
    await backend.acceptAudio([0.1, -0.1, 0.05])
    backend.emit("hello", timestamp: 1.25, confidence: 0.8)
    backend.stop()

    #expect(backend.prepareCallCount == 1)
    #expect(backend.acceptedAudio == [[0.1, -0.1, 0.05]])
    #expect(emitted == [SpokenWordToken(word: "hello", timestamp: 1.25, confidence: 0.8)])
    #expect(backend.stopCallCount == 1)
  }

  @Test @MainActor func recognizedWordTokenAdvancesOnlyWithinForwardSearchWindow() async throws {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    engine.loadScript(text: "the intro waits and then the actual cue begins", startingAt: 0.45)

    backend.emit("the", timestamp: 1, confidence: 0.9)

    #expect(engine.currentWordIndex == 5)
    #expect(engine.highlightedWordRange == 0..<5)
  }

  @Test @MainActor func classicScrollModeUpdatesHighlightWithoutChangingScrollOffset() async throws
  {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    engine.loadScript(text: "one two three four", startingAt: 0.25)
    engine.voiceScrollMode = .classicScroll

    backend.emitPartial(["two"])
    backend.emitPartial(["two", "three"])

    #expect(engine.scrollOffset == 0.25)
    #expect(engine.currentWordIndex == 2)
    #expect(engine.highlightedWordRange == 0..<2)
  }

  @Test @MainActor func wordTrackingModeMapsMatchedWordToScrollProgress() async throws {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    engine.loadScript(text: "one two three four", startingAt: 0)
    engine.voiceScrollMode = .wordTracking

    backend.emit("one")
    backend.emit("two")
    backend.emit("three")

    #expect(engine.currentWordIndex == 2)
    #expect(engine.scrollOffset == VoiceSyncMatching.scrollOffset(cursorIndex: 2, totalWords: 4))
  }

  @Test func sequentialMatcherAllowsSmallForwardWindowForContentWords() {
    let scriptWords = VoiceSyncMatching.tokenize("one two three four and five")

    #expect(
      VoiceSyncMatching.findSequentialMatch(
        scriptWords: scriptWords,
        spokenWord: "four",
        currentIndex: 0
      ) == nil
    )
    #expect(
      VoiceSyncMatching.findSequentialMatch(
        scriptWords: scriptWords,
        spokenWord: "three",
        currentIndex: 0
      ) == .init(startIndex: 2, overlap: 1)
    )
    #expect(
      VoiceSyncMatching.findSequentialMatch(
        scriptWords: scriptWords,
        spokenWord: "and",
        currentIndex: 2
      ) == nil
    )
    #expect(
      VoiceSyncMatching.findSequentialMatch(
        scriptWords: scriptWords,
        spokenWord: "and",
        currentIndex: 3
      ) == .init(startIndex: 4, overlap: 1)
    )
  }

  @Test @MainActor func userPauseMutesActiveRecognitionBackend() async throws {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(
      recognitionBackend: backend,
      microphonePermissionGranted: { false }
    )
    engine.loadScript(text: "one two three four", startingAt: 0)
    engine.enableRecognitionIfNeeded()
    await Task.yield()

    engine.state = .running
    engine.isHumanSpeechActive = true
    engine.togglePause()

    #expect(engine.isPausedByUser)
    #expect(engine.state == .paused)
    #expect(!engine.isHumanSpeechActive)
    #expect(backend.stopCallCount == 1)
  }

  @Test @MainActor func wordTrackingIgnoresLowConfidenceAndDuplicateOverlapTokens() async throws {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    engine.loadScript(
      text:
        "I started with clear words alpha beta gamma delta epsilon zeta eta theta I started later",
      startingAt: 0
    )
    engine.voiceScrollMode = .wordTracking

    backend.emit("(laughing)", confidence: 0.34)
    #expect(engine.currentWordIndex == nil)

    backend.emit("I", confidence: 0.81)
    backend.emit("started", confidence: 1.0)
    #expect(engine.currentWordIndex == 1)

    backend.emit("I", confidence: 0.81)
    #expect(engine.currentWordIndex == 1)

    backend.emit("with", confidence: 0.99)
    #expect(engine.currentWordIndex == 2)
    #expect(engine.scrollOffset == VoiceSyncMatching.scrollOffset(cursorIndex: 2, totalWords: 16))
  }

  @Test @MainActor func wordTrackingRecoveryRequiresPhraseForDeepJump() async throws {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    engine.loadScript(
      text:
        "one two three four five six seven eight alpha beta gamma delta epsilon zeta eta nine ten eleven after",
      startingAt: 0
    )
    engine.voiceScrollMode = .wordTracking

    backend.emit("one", confidence: 0.9)
    backend.emit("two", confidence: 0.42)
    backend.emit("three", confidence: 0.43)
    backend.emit("eleven", confidence: 0.9)

    #expect(engine.currentWordIndex == 0)
    #expect(engine.scrollOffset == 0)

    engine.reseedHighlight(to: 15)
    backend.emit("nine", confidence: 0.9)
    backend.emit("ten", confidence: 0.9)
    backend.emit("eleven", confidence: 0.9)

    #expect(engine.currentWordIndex == 17)
    #expect(engine.scrollOffset == VoiceSyncMatching.scrollOffset(cursorIndex: 17, totalWords: 19))
  }

  @Test @MainActor func wordTrackingPhraseRecoveryUsesVisibleForwardWindow() async throws {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    engine.loadScript(
      text:
        "start missed accent gap1 gap2 gap3 gap4 visible phrase target after hidden phrase target end",
      startingAt: 0
    )
    engine.voiceScrollMode = .wordTracking
    engine.updateVisibleWordRange(0..<12)

    backend.emit("start", confidence: 0.9)
    backend.emit("visible", confidence: 0.95)
    backend.emit("phrase", confidence: 0.95)

    #expect(engine.currentWordIndex == 8)
    #expect(engine.highlightedWordRange == 0..<8)
  }

  @Test @MainActor func wordTrackingPhraseRecoveryRejectsMatchesPastVisibleWindow() async throws {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    engine.loadScript(
      text:
        "start missed accent gap1 gap2 gap3 gap4 visible phrase target after hidden phrase target end",
      startingAt: 0
    )
    engine.voiceScrollMode = .wordTracking
    engine.updateVisibleWordRange(0..<12)

    backend.emit("start", confidence: 0.9)
    backend.emit("hidden", confidence: 0.95)
    backend.emit("phrase", confidence: 0.95)

    #expect(engine.currentWordIndex == 0)
    #expect(engine.scrollOffset == 0)
  }

  @Test @MainActor func wordTrackingPhraseRecoveryUsesFallbackBeforeVisibleMetrics() async throws {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    let gap = (1...70).map { "gap\($0)" }.joined(separator: " ")
    engine.loadScript(text: "start \(gap) far phrase target", startingAt: 0)
    engine.voiceScrollMode = .wordTracking

    backend.emit("start", confidence: 0.9)
    let offsetAfterStart = engine.scrollOffset
    backend.emit("far", confidence: 0.95)
    backend.emit("phrase", confidence: 0.95)

    #expect(engine.currentWordIndex == 0)
    #expect(engine.scrollOffset == offsetAfterStart)
  }

  @Test @MainActor func wordTrackingScrollOffsetDoesNotCorrectBackwardAfterOvershoot()
    async throws
  {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    engine.loadScript(text: "one two three four five six seven eight nine ten", startingAt: 0)
    engine.voiceScrollMode = .wordTracking
    engine.nudgeScroll(to: 0.7, resetSpokenTracking: false)
    engine.reseedHighlight(to: 0)

    backend.emit("one", confidence: 0.95)
    backend.emit("two", confidence: 0.95)

    #expect(engine.currentWordIndex == 1)
    #expect(engine.scrollOffset == 0.7)
  }

  @Test func robustMatcherRejectsDeepStopWordPhraseJump() {
    let scriptWords = VoiceSyncMatching.tokenize(
      "start anchor " + (1...24).map { "gap\($0)" }.joined(separator: " ")
        + " and then the real section"
    )

    let match = VoiceSyncMatching.findRobustMatch(
      scriptWords: scriptWords,
      recentSpokenWords: ["and", "then", "the"],
      currentIndex: 0,
      localLookAhead: 8,
      deepLookAhead: 80
    )

    #expect(match == nil)
  }

  @Test func robustMatcherRejectsDistantSingleTokenDuplicateInsideLocalWindow() {
    let scriptWords = VoiceSyncMatching.tokenize(
      "start one two three four five six seven eight target after"
    )

    let match = VoiceSyncMatching.findRobustMatch(
      scriptWords: scriptWords,
      recentSpokenWords: ["target"],
      currentIndex: 0,
      localLookAhead: 12,
      deepLookAhead: 80
    )

    #expect(match == nil)
  }

  @Test @MainActor func wordTrackingRecoveryDoesNotJumpToFarRepeatedFillerWords() async throws {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    engine.loadScript(
      text:
        "start alpha beta gamma delta epsilon zeta eta theta the iota kappa lambda and final",
      startingAt: 0
    )
    engine.voiceScrollMode = .wordTracking

    backend.emit("start", confidence: 0.9)
    backend.emit("missed", confidence: 0.42)
    backend.emit("accented", confidence: 0.43)
    backend.emit("the", confidence: 0.95)
    backend.emit("and", confidence: 0.95)

    #expect(engine.currentWordIndex == 0)
    #expect(engine.scrollOffset == 0)
  }

  @Test @MainActor func wordTrackingSingleTokenRecoveryStaysLocalButPhraseCanJumpDeep()
    async throws
  {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    engine.loadScript(
      text:
        "start alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi unique bridge target after",
      startingAt: 0
    )
    engine.voiceScrollMode = .wordTracking

    backend.emit("start", confidence: 0.9)
    backend.emit("missed", confidence: 0.42)
    backend.emit("accented", confidence: 0.43)
    backend.emit("target", confidence: 0.95)

    #expect(engine.currentWordIndex == 0)
    #expect(engine.scrollOffset == 0)

    engine.reseedHighlight(to: 15)
    backend.emit("unique", confidence: 0.95)
    backend.emit("bridge", confidence: 0.95)
    backend.emit("target", confidence: 0.95)

    #expect(engine.currentWordIndex == 17)
    #expect(engine.scrollOffset == VoiceSyncMatching.scrollOffset(cursorIndex: 17, totalWords: 19))
  }

  @Test @MainActor func manualReseedClearsWhisperPhraseContextBeforeNextToken() async throws {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    let gap = (1...24).map { "gap\($0)" }.joined(separator: " ")
    engine.loadScript(
      text: "old one start anchor \(gap) old one two after",
      startingAt: 0
    )
    engine.voiceScrollMode = .wordTracking

    backend.emit("old", confidence: 0.95)
    backend.emit("one", confidence: 0.95)
    engine.reseedHighlight(to: 28)
    backend.emit("old", confidence: 0.95)
    backend.emit("one", confidence: 0.95)
    backend.emit("two", confidence: 0.95)

    #expect(engine.currentWordIndex == 30)
    #expect(engine.highlightedWordRange == 0..<30)
  }

  @Test func whisperBackendUsesSlidingPhraseContextAndBoundedDeduplication() {
    #expect(WhisperSpeechRecognitionBackend.maximumContextSamples == 48_000)
    #expect(WhisperSpeechRecognitionBackend.transcriptionTriggerSamples == 8_000)
    #expect(WhisperSpeechRecognitionBackend.sampleRate == 16_000)
    #expect(WhisperSpeechRecognitionBackend.maximumEmittedTokenCacheSize == 500)
    #expect(WhisperSpeechRecognitionBackend.emittedTokenCacheTrimCount == 100)
    #expect(
      WhisperSpeechRecognitionBackend.preferredBundledModelNames.first == "openai_whisper-base.en")
    #expect(
      WhisperSpeechRecognitionBackend.preferredBundledModelNames.contains("openai_whisper-tiny.en"))
  }

  @Test @MainActor func soundBasedModeDoesNotScrollFromRecognizedWords() async throws {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    engine.loadScript(text: "one two three four", startingAt: 0)
    engine.voiceScrollMode = .soundBased

    backend.emitPartial(["one", "two", "three"])
    #expect(engine.scrollOffset == 0)

    engine.reseedHighlight(to: 0)
    engine.isHumanSpeechActive = true
    backend.emitPartial(["one", "two", "three"])

    #expect(engine.currentWordIndex == 2)
    #expect(engine.scrollOffset == 0)
  }

  @Test @MainActor func soundBasedPassiveScrollDoesNotMoveHighlightCursor() async throws {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    engine.loadScript(text: "one two three four five", startingAt: 0)
    engine.voiceScrollMode = .soundBased

    backend.emitPartial(["one"])
    engine.updatePassiveScrollOffset(to: 0.85)
    backend.emitPartial(["one", "two"])

    #expect(engine.currentWordIndex == 1)
    #expect(engine.highlightedWordRange == 0..<1)
    #expect(engine.scrollOffset == 0.85)
  }

  @Test @MainActor func passiveScrollOffsetDoesNotClearExistingHighlightState() async throws {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    engine.loadScript(text: "one two three four", startingAt: 0)
    engine.voiceScrollMode = .soundBased

    backend.emitPartial(["one", "two"])
    engine.updatePassiveScrollOffset(to: 0.5)

    #expect(engine.currentWordIndex == 1)
    #expect(engine.highlightedWordRange == 0..<1)
    #expect(engine.scrollOffset == 0.5)
  }

  @Test @MainActor func voiceRecognitionSourcePolicySplitsHighlightAndWordTrackingBackends()
    async throws
  {
    let wordTrackingBackend = FakeSpeechRecognitionBackend()
    let highlightBackend = FakeSpeechRecognitionBackend()
    let highlightEngine = VoiceSyncEngine(
      recognitionBackend: wordTrackingBackend,
      highlightRecognitionBackend: highlightBackend
    )
    highlightEngine.voiceScrollMode = .classicScroll

    highlightEngine.enableRecognitionIfNeeded()
    await Task.yield()

    #expect(highlightBackend.prepareCallCount == 1)
    #expect(wordTrackingBackend.prepareCallCount == 0)

    let wordEngine = VoiceSyncEngine(
      recognitionBackend: wordTrackingBackend,
      highlightRecognitionBackend: highlightBackend
    )
    wordEngine.voiceScrollMode = .wordTracking

    wordEngine.enableRecognitionIfNeeded()
    await Task.yield()

    #expect(wordTrackingBackend.prepareCallCount == 1)
  }

  @Test @MainActor func voiceSyncStopStopsBackendAndRejectsStaleWordCallbacks() async throws {
    let backend = FakeSpeechRecognitionBackend()
    let engine = VoiceSyncEngine(recognitionBackend: backend)
    engine.loadScript(text: "one two three four", startingAt: 0)

    engine.stop()
    backend.emit("three")

    #expect(backend.stopCallCount == 1)
    #expect(engine.currentWordIndex == nil)
    #expect(engine.scrollOffset == 0)
  }

  @Test func voiceSyncRecognitionPreprocessingSelectsStrongestChannel() throws {
    let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 48_000,
      channels: 2,
      interleaved: false
    )!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4)!
    buffer.frameLength = 4

    let channel0: [Float] = [0.001, -0.002, 0.001, -0.001]
    let channel1: [Float] = [0.010, -0.020, 0.015, -0.010]
    let channels = [channel0, channel1]

    for (channelIndex, samples) in channels.enumerated() {
      let destination = UnsafeMutableBufferPointer(
        start: buffer.floatChannelData![channelIndex],
        count: Int(buffer.frameLength)
      )
      for (frameIndex, sample) in samples.enumerated() {
        destination[frameIndex] = sample
      }
    }

    #expect(VoiceSyncRecognitionInput.dominantChannelIndex(for: buffer) == 1)
  }

  @Test func voiceSyncRecognitionPreprocessingNormalizesQuietSpeechToMono() throws {
    let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 48_000,
      channels: 2,
      interleaved: false
    )!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4)!
    buffer.frameLength = 4

    let quietChannel0: [Float] = [0.001, -0.001, 0.002, -0.001]
    let speechChannel1: [Float] = [0.010, -0.020, 0.015, -0.010]
    let channels = [quietChannel0, speechChannel1]

    for (channelIndex, samples) in channels.enumerated() {
      let destination = UnsafeMutableBufferPointer(
        start: buffer.floatChannelData![channelIndex],
        count: Int(buffer.frameLength)
      )
      for (frameIndex, sample) in samples.enumerated() {
        destination[frameIndex] = sample
      }
    }

    let recognitionBuffer = try #require(
      VoiceSyncRecognitionInput.makeRecognitionBuffer(from: buffer)
    )

    #expect(recognitionBuffer.format.channelCount == 1)
    #expect(recognitionBuffer.format.commonFormat == AVAudioCommonFormat.pcmFormatFloat32)
    #expect(recognitionBuffer.frameLength == buffer.frameLength)
    let samples = UnsafeBufferPointer(
      start: recognitionBuffer.floatChannelData![0],
      count: Int(recognitionBuffer.frameLength)
    )
    let peak = samples.reduce(into: Float(0)) { runningPeak, sample in
      runningPeak = max(runningPeak, abs(sample))
    }
    #expect(abs(peak - 0.18) < 0.0001)
  }

  @Test func voiceSyncRecognitionPreprocessingDropsSubThresholdNoise() throws {
    let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 48_000,
      channels: 1,
      interleaved: false
    )!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4)!
    buffer.frameLength = 4

    let roadNoise: [Float] = [0.0008, -0.0011, 0.0013, -0.0009]
    let destination = UnsafeMutableBufferPointer(
      start: buffer.floatChannelData![0],
      count: Int(buffer.frameLength)
    )
    for (frameIndex, sample) in roadNoise.enumerated() {
      destination[frameIndex] = sample
    }

    #expect(VoiceSyncRecognitionInput.makeRecognitionBuffer(from: buffer) == nil)
    #expect(VoiceSyncRecognitionInput.makeRecognitionSamples(from: buffer) == nil)
  }

  @Test func voiceSyncRecognitionPreprocessingResamplesMicAudioToWhisperRate() throws {
    let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 48_000,
      channels: 1,
      interleaved: false
    )!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480)!
    buffer.frameLength = 480

    let destination = UnsafeMutableBufferPointer(
      start: buffer.floatChannelData![0],
      count: Int(buffer.frameLength)
    )
    for frameIndex in 0..<Int(buffer.frameLength) {
      destination[frameIndex] = sin(Float(frameIndex) * 0.03) * 0.05
    }

    let samples = try #require(VoiceSyncRecognitionInput.makeRecognitionSamples(from: buffer))

    #expect(samples.count >= 150)
    #expect(samples.count <= 176)
  }

  @Test @MainActor func audioLevelMonitorUsesStrongestCapturedChannel() throws {
    let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 48_000,
      channels: 2,
      interleaved: false
    )!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4)!
    buffer.frameLength = 4

    let quietChannel0: [Float] = [0.001, -0.001, 0.002, -0.001]
    let speechChannel1: [Float] = [0.010, -0.020, 0.015, -0.010]
    let channels = [quietChannel0, speechChannel1]

    for (channelIndex, samples) in channels.enumerated() {
      let destination = UnsafeMutableBufferPointer(
        start: buffer.floatChannelData![channelIndex],
        count: Int(buffer.frameLength)
      )
      for (frameIndex, sample) in samples.enumerated() {
        destination[frameIndex] = sample
      }
    }

    let monitor = AudioLevelMonitor()
    monitor.processBuffer(buffer)

    #expect(monitor.level > 0.1)
  }

  @Test @MainActor func audioLevelMonitorNormalizesQuietSpeechForVisualMetering() throws {
    let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 48_000,
      channels: 1,
      interleaved: false
    )!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4)!
    buffer.frameLength = 4

    let quietSpeech: [Float] = [0.0015, -0.0033, 0.0022, -0.0018]
    let destination = UnsafeMutableBufferPointer(
      start: buffer.floatChannelData![0],
      count: Int(buffer.frameLength)
    )
    for (frameIndex, sample) in quietSpeech.enumerated() {
      destination[frameIndex] = sample
    }

    let monitor = AudioLevelMonitor()
    monitor.processBuffer(buffer)

    #expect(monitor.level >= 0.2)
  }

  @Test @MainActor func audioLevelMonitorUsesSpeechFocusedSpeakingThresholds() {
    #expect(AudioLevelMonitor.speakingThreshold(for: .low) == 0.35)
    #expect(AudioLevelMonitor.speakingThreshold(for: .medium) == 0.20)
    #expect(AudioLevelMonitor.speakingThreshold(for: .high) == 0.12)
  }

  @Test @MainActor func voiceSyncUsesPlainCaptureInputPathByDefault() {
    #expect(VoiceSyncEngine.enablesPlatformVoiceProcessingDSP == false)
  }

  @Test @MainActor func voiceSyncReseedHighlightPreservesScrollOffsetAndUpdatesCurrentAnchor() {
    let engine = VoiceSyncEngine()
    engine.loadScript(text: "one two three four five six", startingAt: 0.75)

    let originalOffset = engine.scrollOffset
    engine.reseedHighlight(to: 2)

    #expect(engine.scrollOffset == originalOffset)
    #expect(engine.currentWordIndex == 2)
    #expect(engine.highlightedWordRange == 0..<2)
  }

  @Test @MainActor func firstLaunchPermissionCoordinatorRequestsAccessibilityAndMicOnce()
    throws
  {
    let (settingsStore, defaults, suiteName) = makeSettingsStore()
    defer { cleanupSettings(defaults, suiteName: suiteName) }

    var microphoneRequestCount = 0
    var accessibilityPromptCount = 0
    let coordinator = AppPermissionCoordinator(
      settingsStore: settingsStore,
      microphonePermissionState: { .undetermined },
      requestMicrophonePermission: { reply in
        microphoneRequestCount += 1
        reply(true)
      },
      isAccessibilityTrusted: { false },
      promptForAccessibilityTrust: {
        accessibilityPromptCount += 1
      }
    )

    coordinator.requestLaunchPermissionsIfNeeded()
    coordinator.requestLaunchPermissionsIfNeeded()

    let persisted = try settingsStore.load()
    #expect(microphoneRequestCount == 1)
    #expect(accessibilityPromptCount == 1)
    #expect(persisted.hasCompletedInitialPermissionPrompt)
  }

  @Test @MainActor func laterLaunchPermissionCoordinatorSkipsFullyGrantedPermissions() throws {
    let (settingsStore, defaults, suiteName) = makeSettingsStore()
    defer { cleanupSettings(defaults, suiteName: suiteName) }

    try settingsStore.save(AppSettings(hasCompletedInitialPermissionPrompt: true))

    var microphoneRequestCount = 0
    var accessibilityPromptCount = 0
    let coordinator = AppPermissionCoordinator(
      settingsStore: settingsStore,
      microphonePermissionState: { .granted },
      requestMicrophonePermission: { _ in
        microphoneRequestCount += 1
      },
      isAccessibilityTrusted: { false },
      promptForAccessibilityTrust: {
        accessibilityPromptCount += 1
      }
    )

    coordinator.requestLaunchPermissionsIfNeeded()

    #expect(microphoneRequestCount == 0)
    #expect(accessibilityPromptCount == 1)
  }

  @Test @MainActor func launchAccessibilityPromptCanBeRetriedExplicitlyWhenStillUntrusted() {
    let (settingsStore, defaults, suiteName) = makeSettingsStore()
    defer { cleanupSettings(defaults, suiteName: suiteName) }

    var accessibilityPromptCount = 0
    let coordinator = AppPermissionCoordinator(
      settingsStore: settingsStore,
      microphonePermissionState: { .granted },
      requestMicrophonePermission: { _ in },
      isAccessibilityTrusted: { false },
      promptForAccessibilityTrust: {
        accessibilityPromptCount += 1
      }
    )

    coordinator.requestLaunchPermissionsIfNeeded()
    coordinator.promptForAccessibilityIfNeeded()

    #expect(accessibilityPromptCount == 2)
  }

  @Test @MainActor func laterLaunchPermissionCoordinatorOnlyRequestsStillUndeterminedPermissions()
    throws
  {
    let (settingsStore, defaults, suiteName) = makeSettingsStore()
    defer { cleanupSettings(defaults, suiteName: suiteName) }

    try settingsStore.save(AppSettings(hasCompletedInitialPermissionPrompt: true))

    var microphoneRequestCount = 0
    var accessibilityPromptCount = 0
    let coordinator = AppPermissionCoordinator(
      settingsStore: settingsStore,
      microphonePermissionState: { .undetermined },
      requestMicrophonePermission: { _ in
        microphoneRequestCount += 1
      },
      isAccessibilityTrusted: { true },
      promptForAccessibilityTrust: {
        accessibilityPromptCount += 1
      }
    )

    coordinator.requestLaunchPermissionsIfNeeded()

    #expect(microphoneRequestCount == 1)
    #expect(accessibilityPromptCount == 0)
  }

  @Test @MainActor func voiceSyncStartDoesNotPromptWhenLaunchPermissionsMissing() {
    let engine = VoiceSyncEngine(
      microphonePermissionGranted: { false }
    )

    engine.start()
    engine.startAudioMonitoring()

    #expect(engine.state == .idle)
  }

  @Test @MainActor func overlayWindowControllerEndSessionResetsSharedVoiceState() {
    let controller = OverlayWindowController()
    controller.voiceSync.loadScript(text: "alpha beta gamma delta", startingAt: 0.5)
    controller.voiceSync.setRecognitionDrivesScroll(false)
    controller.voiceSync.reseedHighlight(to: 2)
    controller.voiceSync.requestManualLineNudge(direction: 1)
    controller.playheadCoordinator.beginSession()
    controller.playheadCoordinator.updateProgress(0.75)
    controller.playheadCoordinator.updateVelocity(42)
    controller.playheadCoordinator.setPaused(true)

    controller.endSession()

    #expect(controller.voiceSync.state == .idle)
    #expect(controller.voiceSync.scrollOffset == 0)
    #expect(controller.voiceSync.currentWordIndex == nil)
    #expect(controller.voiceSync.highlightedWordRange == nil)
    #expect(controller.voiceSync.isHumanSpeechActive == false)
    #expect(controller.voiceSync.manualLineNudgeID == 0)
    #expect(controller.voiceSync.manualLineNudgeDirection == 0)
    #expect(controller.playheadCoordinator.progress == 0)
    #expect(controller.playheadCoordinator.velocity == 0)
    #expect(controller.playheadCoordinator.isPaused == false)
  }

  @Test @MainActor func pillControllerAcceptsLiveSessionBehaviorUpdates() {
    let controller = PillWindowController(mode: .voiceSync)

    controller.updateSessionBehavior(
      voiceSyncEnabled: false,
      spokenWordHighlightingEnabled: true,
      pauseOnHoverEnabled: false
    )

    let mirror = Mirror(reflecting: controller)
    #expect(mirror.descendant("voiceSyncEnabled") as? Bool == false)
    #expect(mirror.descendant("spokenWordHighlightingEnabled") as? Bool == true)
    #expect(mirror.descendant("pauseOnHoverEnabled") as? Bool == false)
  }

  @Test func classicHighlightOnlyVisualRangeUsesSpokenPrefix() {
    let currentWordIndex = 5
    let classicVisualRange = 0..<currentWordIndex

    #expect(classicVisualRange == 0..<5)
    #expect(!classicVisualRange.contains(currentWordIndex))
  }

  @Test func detailedMatchTracksCurrentMatchedWordIndex() {
    let scriptWords = ["one", "two", "three", "four", "five", "six"]
    let spokenWindow = ["three", "four", "five"]

    let match = VoiceSyncMatching.findDetailedMatch(
      scriptWords: scriptWords,
      spokenWindow: spokenWindow,
      cursorIndex: 0
    )

    #expect(match?.startIndex == 2)
    #expect(match?.overlap == 3)
    #expect(match?.currentWordIndex == 4)
  }

  @Test func voiceSyncStartupMatchConfigurationsAcceptEarlySingleWordPartial() {
    let recognizedWords = [
      VoiceSyncMatching.RecognizedWord(token: "hello", confidence: 0.60)
    ]

    let startupSingleWordConfiguration =
      VoiceSyncMatching.matchConfigurations(hasEstablishedMatch: false)
      .first { $0.windowLength == 1 }
    let steadyStateSingleWordConfiguration =
      VoiceSyncMatching.matchConfigurations(hasEstablishedMatch: true)
      .first { $0.windowLength == 1 }

    let startupWindow = VoiceSyncMatching.trailingRecognizedWindow(
      from: recognizedWords,
      length: startupSingleWordConfiguration?.windowLength ?? 1,
      minimumWordConfidence: startupSingleWordConfiguration?.minimumWordConfidence ?? 1,
      minimumAverageConfidence: startupSingleWordConfiguration?.minimumAverageConfidence ?? 1
    )
    let steadyStateWindow = VoiceSyncMatching.trailingRecognizedWindow(
      from: recognizedWords,
      length: steadyStateSingleWordConfiguration?.windowLength ?? 1,
      minimumWordConfidence: steadyStateSingleWordConfiguration?.minimumWordConfidence ?? 1,
      minimumAverageConfidence: steadyStateSingleWordConfiguration?.minimumAverageConfidence ?? 1
    )

    #expect(startupWindow?.map(\.token) == ["hello"])
    #expect(steadyStateWindow == nil)
  }

  @Test func currentWordHighlightAttributesUseUnderlineOnly() {
    let underlineColor = NSColor.labelColor

    let attributes = OverlayStyledTextContainerView.currentWordTemporaryAttributes(
      underlineColor: underlineColor
    )

    #expect(attributes[.foregroundColor] == nil)
    #expect((attributes[.underlineColor] as? NSColor) == underlineColor)
    #expect(
      attributes[.underlineStyle] as? Int
        == (NSUnderlineStyle.single.rawValue | NSUnderlineStyle.thick.rawValue))
  }

  @Test @MainActor func voiceSyncRecommendedLookAheadUsesStagedMatcherModes() {
    #expect(
      VoiceSyncEngine.recommendedStrictMatchLookAhead(
        visibleWordCount: 60,
        minimumOverlap: 1,
        mode: .startup
      ) == 12
    )
    #expect(
      VoiceSyncEngine.recommendedStrictMatchLookAhead(
        visibleWordCount: 60,
        minimumOverlap: 3,
        mode: .steady
      ) == 18
    )
    #expect(
      VoiceSyncEngine.recommendedStrictMatchLookAhead(
        visibleWordCount: 60,
        minimumOverlap: 2,
        mode: .steady
      ) == 12
    )
    #expect(
      VoiceSyncEngine.recommendedStrictMatchLookAhead(
        visibleWordCount: 60,
        minimumOverlap: 1,
        mode: .steady
      ) == 7
    )
    #expect(
      VoiceSyncEngine.recommendedStrictMatchLookAhead(
        visibleWordCount: 60,
        minimumOverlap: 1,
        mode: .catchUp(lagWords: 10)
      ) == 10
    )

    #expect(
      VoiceSyncEngine.recommendedVisualMatchLookAhead(
        visibleWordCount: 30,
        mode: .startup
      ) == 8
    )
    #expect(
      VoiceSyncEngine.recommendedVisualMatchLookAhead(
        visibleWordCount: 30,
        mode: .steady
      ) == 4
    )
    #expect(
      VoiceSyncEngine.recommendedVisualMatchLookAhead(
        visibleWordCount: 90,
        mode: .catchUp(lagWords: 10)
      ) == 12
    )
  }

  @Test @MainActor func voiceSyncLowOverlapPlausibilityRejectsImplausibleForwardJumps() {
    #expect(
      VoiceSyncEngine.isLowOverlapMatchPlausible(
        matchStartIndex: 6,
        searchStart: 0,
        minimumOverlap: 1,
        mode: .startup
      )
    )
    #expect(
      VoiceSyncEngine.isLowOverlapMatchPlausible(
        matchStartIndex: 12,
        searchStart: 0,
        minimumOverlap: 1,
        mode: .startup
      )
    )
    #expect(
      VoiceSyncEngine.isLowOverlapMatchPlausible(
        matchStartIndex: 10,
        searchStart: 0,
        minimumOverlap: 1,
        mode: .catchUp(lagWords: 6)
      )
    )
    #expect(
      !VoiceSyncEngine.isLowOverlapMatchPlausible(
        matchStartIndex: 14,
        searchStart: 0,
        minimumOverlap: 1,
        mode: .catchUp(lagWords: 4)
      )
    )
    #expect(
      VoiceSyncEngine.isLowOverlapMatchPlausible(
        matchStartIndex: 20,
        searchStart: 0,
        minimumOverlap: 1,
        mode: .steady
      )
    )
  }

  @Test @MainActor func voiceSyncStartupLowOverlapStaysOpenUntilFirstLockThenTightens() {
    #expect(
      VoiceSyncEngine.isLowOverlapMatchPlausible(
        matchStartIndex: 14,
        searchStart: 0,
        minimumOverlap: 1,
        mode: .startup
      )
    )
    #expect(
      !VoiceSyncEngine.isLowOverlapMatchPlausible(
        matchStartIndex: 14,
        searchStart: 0,
        minimumOverlap: 1,
        mode: .catchUp(lagWords: 4)
      )
    )
    #expect(
      VoiceSyncEngine.recommendedStrictMatchLookAhead(
        visibleWordCount: 60,
        minimumOverlap: 1,
        mode: .startup
      )
        > VoiceSyncEngine.recommendedStrictMatchLookAhead(
          visibleWordCount: 60,
          minimumOverlap: 1,
          mode: .steady
        )
    )
  }

  @Test @MainActor func voiceSyncStartupSeedUsesEarliestTokenFromFirstPartial() {
    let scriptWords = ["hello", "world", "from", "aira"]
    let recognizedWords = [
      VoiceSyncMatching.RecognizedWord(token: "hello", confidence: 0.2),
      VoiceSyncMatching.RecognizedWord(token: "world", confidence: 0.2),
      VoiceSyncMatching.RecognizedWord(token: "from", confidence: 0.2),
    ]

    let match = VoiceSyncEngine.startupSeedMatch(
      scriptWords: scriptWords,
      recognizedWords: recognizedWords,
      searchRange: 0..<scriptWords.count
    )

    #expect(match?.startIndex == 0)
    #expect(match?.currentWordIndex == 0)
  }

  @Test @MainActor func voiceSyncStartupSearchAnchorsToVisibleRangeBeforeFirstLock() {
    #expect(
      VoiceSyncEngine.startupSearchLowerBound(
        cursorIndex: 5,
        visibleWordLowerBound: 0,
        hasEstablishedMatch: false
      ) == 0
    )
    #expect(
      VoiceSyncEngine.startupSearchLowerBound(
        cursorIndex: 5,
        visibleWordLowerBound: 0,
        hasEstablishedMatch: true
      ) == 5
    )
    #expect(
      VoiceSyncEngine.startupSearchLowerBound(
        cursorIndex: 5,
        visibleWordLowerBound: 12,
        hasEstablishedMatch: true
      ) == 5
    )
  }

  @Test func normalizeTokenStripsCommonPunctuation() {
    #expect(VoiceSyncMatching.normalizeToken("Hello,") == "hello")
    #expect(VoiceSyncMatching.normalizeToken("world.") == "world")
    #expect(VoiceSyncMatching.normalizeToken("[pause]") == nil)
    #expect(VoiceSyncMatching.normalizeToken("  ") == nil)
  }

  @Test func bundledWhisperModelsIncludeTokenizerFilesForOfflineRecognition() throws {
    let bundleURL = try #require(
      Bundle.main.url(forResource: "WhisperModels", withExtension: "bundle"))
    let bundle = try #require(Bundle(url: bundleURL))

    for modelName in WhisperSpeechRecognitionBackend.preferredBundledModelNames {
      let modelURL = try #require(
        bundle.url(
          forResource: modelName,
          withExtension: nil,
          subdirectory: "Whisper"
        ))

      #expect(WhisperSpeechRecognitionBackend.hasRequiredBundledModelFiles(at: modelURL))
    }
  }

}

@MainActor
struct SessionPlayheadCoordinatorTests {
  @Test func clampsProgressAndPreservesPauseAcrossSessionTransitions() {
    let coordinator = SessionPlayheadCoordinator()

    coordinator.beginSession()
    coordinator.updateProgress(1.5)
    coordinator.setPaused(true)

    #expect(coordinator.progress == 1)
    #expect(coordinator.isPaused)

    coordinator.nudgeProgress(by: -2)
    #expect(coordinator.progress == 0)

    coordinator.endSession()
    #expect(coordinator.progress == 0)
    #expect(coordinator.velocity == 0)
    #expect(coordinator.isPaused == false)
  }

  @Test func cinematicScrollControllerStopHaltsFutureTicks() async {
    let controller = CinematicScrollController()
    let tickCounter = LockIsolated(0)

    controller.configure(pointsPerSecond: 80, contentHeight: 2000, viewportHeight: 400)
    controller.setInitialOffset(0)
    controller.onScrollTick = { _ in
      tickCounter.withValue { $0 += 1 }
    }
    controller.setAnchorOffset(0.8)

    try? await Task.sleep(nanoseconds: 80_000_000)
    let ticksBeforeStop = tickCounter.value
    #expect(ticksBeforeStop > 0)

    controller.stop()
    try? await Task.sleep(nanoseconds: 30_000_000)
    let ticksAfterStopSettled = tickCounter.value

    try? await Task.sleep(nanoseconds: 80_000_000)
    #expect(tickCounter.value == ticksAfterStopSettled)
  }
}

@MainActor
final class LockIsolated<Value: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: Value

  init(_ value: Value) {
    storage = value
  }

  var value: Value {
    lock.withLock { storage }
  }

  func withValue<R>(_ body: (inout Value) -> R) -> R {
    lock.withLock {
      body(&storage)
    }
  }
}

struct AppWindowCoordinatorTests {
  @Test func transientMenuBarWindowDetectionIgnoresTaggedManagerWindow() {
    #expect(
      AppWindowCoordinator.isTransientMenuBarWindow(
        identifier: AppWindowCoordinator.managerWindowIdentifier,
        isPanel: false,
        title: ""
      ) == false
    )
  }

  @Test func transientMenuBarWindowDetectionMatchesUntitledRegularWindow() {
    #expect(
      AppWindowCoordinator.isTransientMenuBarWindow(
        identifier: nil,
        isPanel: false,
        title: ""
      )
    )
  }

  @Test func transientMenuBarWindowDetectionMatchesUntitledPanelHostWindow() {
    #expect(
      AppWindowCoordinator.isTransientMenuBarWindow(
        identifier: nil,
        isPanel: true,
        title: "",
        sharingType: .readOnly,
        level: .normal
      )
    )
  }

  @Test func transientMenuBarWindowDetectionIgnoresStealthOverlayPanels() {
    #expect(
      AppWindowCoordinator.isTransientMenuBarWindow(
        identifier: nil,
        isPanel: true,
        title: "",
        sharingType: .none,
        level: .screenSaver
      ) == false
    )
  }

  @Test func managerRestoreFallbackRejectsTransientMenuBarWindows() {
    #expect(
      AppWindowCoordinator.isManagerRestoreFallbackCandidate(
        identifier: nil,
        isPanel: false,
        title: ""
      ) == false
    )
  }

  @Test func taggedTransientMenuBarWindowsAreRejectedEvenWithTitles() {
    #expect(
      AppWindowCoordinator.isTransientMenuBarWindow(
        identifier: AppWindowCoordinator.transientMenuBarWindowIdentifier,
        isPanel: false,
        title: "Aira"
      )
    )
    #expect(
      AppWindowCoordinator.isManagerRestoreFallbackCandidate(
        identifier: AppWindowCoordinator.transientMenuBarWindowIdentifier,
        isPanel: false,
        title: "Aira"
      ) == false
    )
  }

  @Test func managerRestoreFallbackAcceptsTaggedManagerWindow() {
    #expect(
      AppWindowCoordinator.isManagerRestoreFallbackCandidate(
        identifier: AppWindowCoordinator.managerWindowIdentifier,
        isPanel: false,
        title: ""
      )
    )
  }

  @Test func sessionWindowTransitionPreservesFullscreenManagerWindow() {
    #expect(AppWindowCoordinator.shouldPreserveManagerWindowForSession(styleMask: [.fullScreen]))
    #expect(
      !AppWindowCoordinator.shouldPreserveManagerWindowForSession(styleMask: [
        .titled, .closable,
      ]))
  }

  @Test func managerRestoreFallbackRejectsUntaggedTitledRegularWindows() {
    #expect(
      AppWindowCoordinator.isManagerRestoreFallbackCandidate(
        identifier: nil,
        isPanel: false,
        title: "Aira"
      ) == false
    )
  }

  @Test func transientMenuBarWindowsAreStillRejectedBeforeChromeRepair() {
    #expect(
      AppWindowCoordinator.isManagerRestoreFallbackCandidate(
        identifier: AppWindowCoordinator.transientMenuBarWindowIdentifier,
        isPanel: false,
        title: "Aira"
      ) == false
    )
  }
}

struct MenuBarVoiceControlPresentationTests {
  @Test func enablementDependsOnActiveSessionNotVoiceSyncMode() {
    #expect(MenuBarVoiceControlPresentation.isEnabled(hasActiveSession: true))
    #expect(!MenuBarVoiceControlPresentation.isEnabled(hasActiveSession: false))
  }

  @Test func pausedStateUsesResumeTitleAndPlayIcon() {
    #expect(MenuBarVoiceControlPresentation.title(isPausedByUser: true) == "Resume Voice")
    #expect(MenuBarVoiceControlPresentation.symbolName(isPausedByUser: true) == "play.fill")
  }

  @Test func runningStateUsesPauseTitleAndPauseIcon() {
    #expect(MenuBarVoiceControlPresentation.title(isPausedByUser: false) == "Pause Voice")
    #expect(MenuBarVoiceControlPresentation.symbolName(isPausedByUser: false) == "pause.fill")
  }
}

struct MenuBarStatusItemControllerTests {
  @Test func defersStatusItemCreationUntilLaunchCompletes() {
    #expect(
      MenuBarStatusItemController.shouldCreateStatusItem(
        hasCompletedLaunch: false,
        hasStatusItem: false
      ) == false
    )
    #expect(
      MenuBarStatusItemController.shouldCreateStatusItem(
        hasCompletedLaunch: true,
        hasStatusItem: false
      )
    )
    #expect(
      MenuBarStatusItemController.shouldCreateStatusItem(
        hasCompletedLaunch: true,
        hasStatusItem: true
      ) == false
    )
  }

  @Test func rebuildsPopoverWhenMarkedShownWithoutAttachedWindow() {
    #expect(
      MenuBarStatusItemController.shouldRebuildPopover(
        isShown: true,
        hasAttachedWindow: false
      )
    )
  }

  @Test func keepsPopoverWhenShownStateMatchesAttachedWindow() {
    #expect(
      MenuBarStatusItemController.shouldRebuildPopover(
        isShown: true,
        hasAttachedWindow: true
      ) == false
    )
    #expect(
      MenuBarStatusItemController.shouldRebuildPopover(
        isShown: false,
        hasAttachedWindow: false
      ) == false
    )
  }

  @Test func promotesQuickAccessPanelWindowLevelToAtLeastStatusBar() {
    #expect(
      MenuBarStatusItemController.promotedQuickAccessWindowLevel(from: .normal) == .statusBar
    )
    #expect(
      MenuBarStatusItemController.promotedQuickAccessWindowLevel(from: .statusBar) == .statusBar
    )
  }

  @Test func quickAccessPanelCollectionBehaviorFollowsActiveSpaceAndFullscreenApps() {
    let behavior = MenuBarStatusItemController.quickAccessCollectionBehavior()

    #expect(behavior.contains(.canJoinAllSpaces))
    #expect(behavior.contains(.fullScreenAuxiliary))
    #expect(behavior.contains(.moveToActiveSpace))
  }

  @Test func quickAccessPanelUsesNonactivatingBorderlessStyle() {
    let styleMask = MenuBarStatusItemController.quickAccessPanelStyleMask()

    #expect(styleMask.contains(.borderless))
    #expect(styleMask.contains(.nonactivatingPanel))
  }

  @Test func quickAccessPanelFrameAnchorsNearStatusItemInsideVisibleScreen() {
    let frame = MenuBarStatusItemController.quickAccessPanelFrame(
      buttonFrame: NSRect(x: 920, y: 870, width: 32, height: 24),
      panelSize: NSSize(width: 360, height: 420),
      visibleFrame: NSRect(x: 0, y: 0, width: 1_000, height: 900),
      margin: 8
    )

    #expect(frame.maxX <= 992)
    #expect(frame.minX >= 8)
    #expect(frame.maxY < 870)
  }

  @Test func statusItemUsesTemplateRenderingForAutomaticBlackWhiteSwitching() {
    #expect(MenuBarStatusItemController.statusItemUsesTemplateRendering())
  }

  @Test func outsideInteractionDismissesPopoverOnlyWhenNotOnPopoverOrStatusItem() {
    #expect(
      MenuBarStatusItemController.shouldDismissPopoverForOutsideInteraction(
        isPopoverShown: true,
        interactionInsidePopover: false,
        interactionOnStatusItem: false
      )
    )
    #expect(
      MenuBarStatusItemController.shouldDismissPopoverForOutsideInteraction(
        isPopoverShown: true,
        interactionInsidePopover: true,
        interactionOnStatusItem: false
      ) == false
    )
    #expect(
      MenuBarStatusItemController.shouldDismissPopoverForOutsideInteraction(
        isPopoverShown: true,
        interactionInsidePopover: false,
        interactionOnStatusItem: true
      ) == false
    )
    #expect(
      MenuBarStatusItemController.shouldDismissPopoverForOutsideInteraction(
        isPopoverShown: false,
        interactionInsidePopover: false,
        interactionOnStatusItem: false
      ) == false
    )
  }
}

struct MenuBarScriptSelectionPresentationTests {
  @Test func selectedScriptUsesExplicitRecentSelection() {
    let first = Self.meta(title: "First")
    let second = Self.meta(title: "Second")

    let selected = MenuBarScriptSelectionPresentation.selectedScript(
      recentScripts: [first, second],
      selectedScriptID: second.id,
      fallbackScript: first
    )

    #expect(selected?.id == second.id)
  }

  @Test func selectedScriptFallsBackWhenExplicitSelectionIsStale() {
    let first = Self.meta(title: "First")
    let staleID = UUID()

    let selected = MenuBarScriptSelectionPresentation.selectedScript(
      recentScripts: [first],
      selectedScriptID: staleID,
      fallbackScript: first
    )

    #expect(selected?.id == first.id)
  }

  @Test func castTitlesUseSelectedScriptName() {
    let script = Self.meta(title: "Launch Plan")

    #expect(
      MenuBarScriptSelectionPresentation.castTitle(
        selectedScript: script,
        includesPills: false
      ) == "Cast Launch Plan to Notch"
    )
    #expect(
      MenuBarScriptSelectionPresentation.castTitle(
        selectedScript: script,
        includesPills: true
      ) == "Cast Launch Plan to Notch + Pills"
    )
  }

  private static func meta(title: String) -> ScriptMeta {
    ScriptMeta(
      id: UUID(),
      title: title,
      lastEdited: Date(timeIntervalSince1970: 0),
      wordCount: 10,
      starred: false
    )
  }
}

struct MenuBarLaunchSettingsTests {
  @Test func voiceDrivenScrollFollowsVoiceScrollModeInsteadOfLegacyToggle() {
    var settings = AppSettings(
      voiceSyncEnabled: false,
      voiceScrollMode: .wordTracking
    )

    #expect(MenuBarLaunchSettings.voiceDrivenScrollEnabled(for: settings))

    settings.voiceScrollMode = .soundBased
    #expect(MenuBarLaunchSettings.voiceDrivenScrollEnabled(for: settings))

    settings.voiceScrollMode = .classicScroll
    #expect(!MenuBarLaunchSettings.voiceDrivenScrollEnabled(for: settings))
  }
}

struct NotchTextFadeGeometryTests {
  @Test func fadeHeightClampsToReadableViewport() {
    let regularHeight = NotchTextFadeGeometry.fadeHeight(
      availableHeight: 146,
      notchHeight: 34
    )
    #expect(regularHeight >= NotchTextFadeGeometry.minimumFadeHeight)
    #expect(regularHeight <= NotchTextFadeGeometry.maximumFadeHeight)

    let tinyHeight = NotchTextFadeGeometry.fadeHeight(
      availableHeight: 12,
      notchHeight: 34
    )
    #expect(tinyHeight == 12)
  }
}
