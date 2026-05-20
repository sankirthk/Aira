import AppKit
import Foundation
import Testing

@testable import Aira

struct ScriptEditorTextInsertionTests {
  @Test func insertCueAtBeginningOfEmptyText() {
    let result = ScriptEditorTextInsertion.insertCue(
      "Smile",
      into: "",
      selectedRange: NSRange(location: 0, length: 0)
    )

    #expect(result.text == "[Smile]")
    #expect(result.selectedRange.location == "[Smile]".utf16.count)
  }

  @Test func insertCueAtCursorInsideExistingText() {
    let result = ScriptEditorTextInsertion.insertCue(
      "Pause 2s",
      into: "Hello world",
      selectedRange: NSRange(location: 5, length: 0)
    )

    #expect(result.text == "Hello [Pause 2s] world")
    #expect(result.selectedRange.location == "Hello [Pause 2s]".utf16.count)
  }

  @Test func insertCueWithoutAddingDuplicateWhitespace() {
    let result = ScriptEditorTextInsertion.insertCue(
      "Breathe",
      into: "Hello world",
      selectedRange: NSRange(location: 6, length: 0)
    )

    #expect(result.text == "Hello [Breathe] world")
  }

  @Test func cuePopoverUsesSharedDefaultCueOptions() {
    #expect(
      ScriptEditorCueOptions.defaults == [
        "Smile", "Pause 2s", "Eye Contact", "Gesture", "Breathe", "Emphasize",
      ])
  }

  @Test func cueStylingFindsAllInlineCueTokens() {
    let text = "Hello [Pause 2s] world [Smile]"
    let ranges = ScriptEditorCueStyling.cueRanges(in: text)
    let tokens = ranges.compactMap { Range($0, in: text).map { String(text[$0]) } }

    #expect(tokens == ["[Pause 2s]", "[Smile]"])
  }

  @Test func cueStylingAppliesDistinctAnnotationColors() throws {
    let attributed = NSMutableAttributedString(string: "Hello [Pause 2s] world")
    let baseFont = NSFont.systemFont(ofSize: 18)
    let textColor = NSColor.black
    let cueTextColor = NSColor.white
    let cueBackgroundColor = NSColor.systemRed

    ScriptEditorCueStyling.applyCueAnnotationStyling(
      to: attributed,
      baseFont: baseFont,
      textColor: textColor,
      cueTextColor: cueTextColor,
      cueBackgroundColor: cueBackgroundColor
    )

    let cueRange = try #require(ScriptEditorCueStyling.cueRanges(in: attributed.string).first)
    let cueForeground =
      attributed.attribute(.foregroundColor, at: cueRange.location, effectiveRange: nil) as? NSColor
    let cueBackground =
      attributed.attribute(.backgroundColor, at: cueRange.location, effectiveRange: nil) as? NSColor
    let plainForeground =
      attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
    let plainBackground =
      attributed.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor

    #expect(cueForeground == cueTextColor)
    #expect(cueBackground == cueBackgroundColor)
    #expect(plainForeground == textColor)
    #expect(plainBackground == nil)
  }

  @Test func editorWordCountUsesAllWhitespaceSeparators() {
    #expect(ScriptEditorMetrics.wordCount(for: "hello\nworld\tfrom   aira") == 4)
    #expect(ScriptEditorMetrics.wordCount(for: " one   two \n three\t") == 3)
  }

  @Test func markdownPasteNormalizesHeadingsListsLinksAndEmphasis() {
    let markdown = """
      # Welcome

      This is **bold** and *calm*.

      - First point
      - [Second point](https://example.com)
      1. Third point
      """

    let normalized = ScriptEditorMarkdownPaste.normalizedTextIfMarkdown(markdown)

    #expect(
      normalized == """
        Welcome

        This is bold and calm.

        • First point
        • Second point
        1. Third point
        """)
  }

  @Test func markdownPasteLeavesPlainTextUntouched() {
    let plainText = "Hello world.\nThis is already script text."
    #expect(ScriptEditorMarkdownPaste.normalizedTextIfMarkdown(plainText) == nil)
  }
}
