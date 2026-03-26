import Foundation

enum ScriptEditorTextInsertion {
    static func insertCue(
        _ cue: String,
        into text: String,
        selectedRange: NSRange
    ) -> (text: String, selectedRange: NSRange) {
        let cueToken = "[\(cue)]"
        let utf16Count = text.utf16.count
        let clampedLocation = max(0, min(selectedRange.location, utf16Count))

        let insertionIndex = stringIndex(in: text, utf16Offset: clampedLocation)
        let prefixNeedsSpace = insertionIndex > text.startIndex && !text[text.index(before: insertionIndex)].isWhitespace
        let suffixNeedsSpace = insertionIndex < text.endIndex && !text[insertionIndex].isWhitespace

        let insertedText = "\(prefixNeedsSpace ? " " : "")\(cueToken)\(suffixNeedsSpace ? " " : "")"
        var updatedText = text
        updatedText.insert(contentsOf: insertedText, at: insertionIndex)

        let cursorOffset = clampedLocation + insertedText.utf16.count
        return (updatedText, NSRange(location: cursorOffset, length: 0))
    }

    private static func stringIndex(in text: String, utf16Offset: Int) -> String.Index {
        let utf16Index = text.utf16.index(text.utf16.startIndex, offsetBy: utf16Offset)
        return String.Index(utf16Index, within: text) ?? text.endIndex
    }
}
