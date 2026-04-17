import AppKit

struct LineMetric: Equatable {
  let y: CGFloat
  let height: CGFloat
  let wordRange: Range<Int>
  let text: String
}

enum PrompterTextMetrics {
  static func calculateLines(
    text: String,
    font: NSFont,
    width: CGFloat
  ) -> [LineMetric] {
    guard !text.isEmpty, width > 0 else { return [] }

    let textStorage = NSTextStorage(string: text)
    textStorage.addAttribute(
      .font, value: font, range: NSRange(location: 0, length: text.utf16.count))

    let layoutManager = NSLayoutManager()
    let textContainer = NSTextContainer(
      containerSize: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    textContainer.lineFragmentPadding = 0

    layoutManager.addTextContainer(textContainer)
    textStorage.addLayoutManager(layoutManager)

    // Force layout
    layoutManager.ensureLayout(for: textContainer)

    var lines: [LineMetric] = []
    var index = 0
    let length = text.utf16.count
    var runningWordIndex = 0

    while index < length {
      var lineRange = NSRange(location: 0, length: 0)
      let rect = layoutManager.lineFragmentRect(forGlyphAt: index, effectiveRange: &lineRange)
      let lineString = (text as NSString).substring(with: lineRange)

      // Re-use VoiceSyncMatching tokenizer so the word count exactly matches
      // the recognizer's word count.
      let tokens = VoiceSyncMatching.tokenize(lineString)
      let start = runningWordIndex
      runningWordIndex += tokens.count
      let end = runningWordIndex

      let metric = LineMetric(
        y: rect.minY,
        height: rect.height,
        wordRange: start..<end,
        text: lineString.trimmingCharacters(in: .newlines)
      )
      // Even if a line has no speakable words (blank line), we record it.
      // The wordRange will just have length 0.
      lines.append(metric)

      index = NSMaxRange(lineRange)
    }

    return lines
  }
}
