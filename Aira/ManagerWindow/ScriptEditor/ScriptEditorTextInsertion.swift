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
    let prefixNeedsSpace =
      insertionIndex > text.startIndex && !text[text.index(before: insertionIndex)].isWhitespace
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

enum ScriptEditorMarkdownPaste {
  static func normalizedTextIfMarkdown(_ text: String) -> String? {
    guard containsMarkdownSyntax(text) else {
      return nil
    }

    var normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
    normalized = normalized.replacingOccurrences(of: "\r", with: "\n")
    normalized = stripCodeFenceMarkers(in: normalized)
    normalized = normalizeLines(in: normalized)
    normalized = normalizeInlineMarkdown(in: normalized)
    normalized = normalized.replacingOccurrences(
      of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
    normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)

    guard normalized.isEmpty == false, normalized != text else {
      return nil
    }

    return normalized
  }

  private static func containsMarkdownSyntax(_ text: String) -> Bool {
    let patterns = [
      #"(?m)^\s{0,3}#{1,6}\s+\S"#,
      #"(?m)^\s*[-*+]\s+\[[ xX]\]\s+\S"#,
      #"(?m)^\s*[-*+]\s+\S"#,
      #"(?m)^\s*\d+[.)]\s+\S"#,
      #"(?m)^\s*>\s+\S"#,
      #"(?m)^\s*(```|~~~)"#,
      #"\[[^\]]+\]\([^)]+\)"#,
      #"!\[[^\]]*\]\([^)]+\)"#,
      #"(?<!\*)\*\*[^*\n]+\*\*"#,
      #"(?<!_)__[^_\n]+__"#,
      #"(?<!\*)\*[^*\n]+\*(?!\*)"#,
      #"(?<!_)_[^_\n]+_(?!_)"#,
      #"~~[^~\n]+~~"#,
      #"`[^`\n]+`"#,
    ]

    return patterns.contains { pattern in
      text.range(of: pattern, options: .regularExpression) != nil
    }
  }

  private static func stripCodeFenceMarkers(in text: String) -> String {
    text
      .replacingOccurrences(of: #"(?m)^\s*```[^\n]*\n?"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"(?m)^\s*~~~[^\n]*\n?"#, with: "", options: .regularExpression)
  }

  private static func normalizeLines(in text: String) -> String {
    text
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { rawLine in
        let line = String(rawLine)

        if line.range(of: #"^\s*([-*_]\s*){3,}$"#, options: .regularExpression) != nil {
          return ""
        }

        if let task = match(#"^\s*[-*+]\s+\[[ xX]\]\s+(.+?)\s*$"#, in: line, capture: 1) {
          return "• \(task)"
        }

        if let heading = match(#"^\s{0,3}#{1,6}\s+(.+?)\s*$"#, in: line, capture: 1) {
          return heading
        }

        if let quote = match(#"^\s*>\s?(.+?)\s*$"#, in: line, capture: 1) {
          return quote
        }

        if let unordered = match(#"^\s*[-*+]\s+(.+?)\s*$"#, in: line, capture: 1) {
          return "• \(unordered)"
        }

        if let orderedNumber = match(#"^\s*(\d+)[.)]\s+(.+?)\s*$"#, in: line, capture: 1),
          let orderedText = match(#"^\s*(\d+)[.)]\s+(.+?)\s*$"#, in: line, capture: 2)
        {
          return "\(orderedNumber). \(orderedText)"
        }

        return line
      }
      .joined(separator: "\n")
  }

  private static func normalizeInlineMarkdown(in text: String) -> String {
    var normalized = text

    let replacements: [(pattern: String, template: String)] = [
      (#"!\[([^\]]*)\]\([^)]+\)"#, "$1"),
      (#"\[([^\]]+)\]\([^)]+\)"#, "$1"),
      (#"<((https?|mailto):[^>]+)>"#, "$1"),
      (#"`([^`\n]+)`"#, "$1"),
      (#"\*\*\*([^*\n]+)\*\*\*"#, "$1"),
      (#"___([^_\n]+)___"#, "$1"),
      (#"\*\*([^*\n]+)\*\*"#, "$1"),
      (#"__([^_\n]+)__"#, "$1"),
      (#"(?<!\*)\*([^*\n]+)\*(?!\*)"#, "$1"),
      (#"(?<!_)_([^_\n]+)_(?!_)"#, "$1"),
      (#"~~([^~\n]+)~~"#, "$1"),
    ]

    for replacement in replacements {
      normalized = normalized.replacingOccurrences(
        of: replacement.pattern,
        with: replacement.template,
        options: .regularExpression
      )
    }

    normalized = normalized.replacingOccurrences(
      of: #"\\([\\`*_{}\[\]()#+\-.!>~])"#,
      with: "$1",
      options: .regularExpression
    )

    return normalized
  }

  private static func match(_ pattern: String, in text: String, capture: Int) -> String? {
    guard
      let regex = try? NSRegularExpression(pattern: pattern),
      let result = regex.firstMatch(
        in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
      let range = Range(result.range(at: capture), in: text)
    else {
      return nil
    }

    return String(text[range])
  }
}
