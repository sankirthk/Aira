import Testing
import AppKit
@testable import Aira

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
