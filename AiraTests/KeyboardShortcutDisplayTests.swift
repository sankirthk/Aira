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
      lineHeight: PrompterScrollMath.lineHeight(fontSize: 24)
    )

    #expect(delta == 0.075)
  }

  @Test func manualVelocityMatchesPixelSpeedAcrossDocumentLengths() {
    let shortVelocity = PrompterScrollMath.manualAutoScrollVelocity(
      pointsPerWord: 20,
      scrollableRange: 1_000,
      autoScrollWPM: 150
    )
    let longVelocity = PrompterScrollMath.manualAutoScrollVelocity(
      pointsPerWord: 20,
      scrollableRange: 10_000,
      autoScrollWPM: 150
    )

    let shortPixelSpeed = shortVelocity * 1_000
    let longPixelSpeed = longVelocity * 10_000

    #expect(shortPixelSpeed == 50)
    #expect(longPixelSpeed == 50)
  }

  @Test func manualVelocityReturnsZeroForInvalidInputs() {
    #expect(
      PrompterScrollMath.manualAutoScrollVelocity(
        pointsPerWord: 0,
        scrollableRange: 1_000,
        autoScrollWPM: 150
      ) == 0
    )
    #expect(
      PrompterScrollMath.manualAutoScrollVelocity(
        pointsPerWord: 20,
        scrollableRange: 0,
        autoScrollWPM: 150
      ) == 0
    )
    #expect(
      PrompterScrollMath.manualAutoScrollVelocity(
        pointsPerWord: 20,
        scrollableRange: 1_000,
        autoScrollWPM: 0
      ) == 0
    )
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
