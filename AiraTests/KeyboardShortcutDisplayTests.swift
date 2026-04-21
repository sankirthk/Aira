import AppKit
import Testing

@testable import Aira

private final class ShortcutActionRecorder {
  private(set) var triggeredShortcuts: [String] = []

  func record(_ shortcut: String) {
    triggeredShortcuts.append(shortcut)
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

  @Test func scrollOffsetIsProportionalToCursorPosition() {
    let offset = VoiceSyncMatching.scrollOffset(cursorIndex: 25, totalWords: 100)

    #expect(offset == 0.25)
  }

  @Test @MainActor func voiceSyncInputTapBufferSizeUsesLowerLatency128Frames() {
    #expect(VoiceSyncEngine.inputTapBufferSize == 128)
  }

  @Test @MainActor func voiceSyncReseedHighlightPreservesScrollOffsetAndUpdatesVisualAnchor() {
    let engine = VoiceSyncEngine()
    engine.loadScript(text: "one two three four five six", startingAt: 0.75)

    let originalOffset = engine.scrollOffset
    engine.reseedHighlight(to: 2)

    #expect(engine.scrollOffset == originalOffset)
    #expect(engine.currentWordIndex == nil)
    #expect(engine.highlightedWordRange == nil)
    #expect(engine.visualCurrentWordIndex == 2)
    #expect(engine.visualHighlightedWordRange == 0..<2)
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
    #expect(controller.voiceSync.visualCurrentWordIndex == nil)
    #expect(controller.voiceSync.visualHighlightedWordRange == nil)
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

  @Test func normalizeTokenStripsCommonPunctuation() {
    #expect(VoiceSyncMatching.normalizeToken("Hello,") == "hello")
    #expect(VoiceSyncMatching.normalizeToken("world.") == "world")
    #expect(VoiceSyncMatching.normalizeToken("[pause]") == nil)
    #expect(VoiceSyncMatching.normalizeToken("  ") == nil)
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
    let ticksImmediatelyAfterStop = tickCounter.value

    try? await Task.sleep(nanoseconds: 80_000_000)
    #expect(tickCounter.value == ticksImmediatelyAfterStop)
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

  @Test func managerWindowChromeRepairRestoresFullStandardTitlebarMask() {
    let repaired = AppWindowCoordinator.repairedManagerWindowStyleMask([])

    #expect(repaired.contains(.titled))
    #expect(repaired.contains(.closable))
    #expect(repaired.contains(.miniaturizable))
    #expect(repaired.contains(.resizable))
  }

  @Test func managerWindowChromeRepairPreservesExistingNonStandardStyleBits() {
    let repaired = AppWindowCoordinator.repairedManagerWindowStyleMask([.fullSizeContentView])

    #expect(repaired.contains(.fullSizeContentView))
    #expect(repaired.contains(.titled))
    #expect(repaired.contains(.closable))
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

  @Test func promotesPopoverWindowLevelToAtLeastFloating() {
    #expect(
      MenuBarStatusItemController.promotedPopoverWindowLevel(from: .normal) == .floating
    )
    #expect(
      MenuBarStatusItemController.promotedPopoverWindowLevel(from: .statusBar) == .statusBar
    )
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
