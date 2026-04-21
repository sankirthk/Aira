import AppKit
import Foundation
import SwiftUI

enum OverlayTextAlignment: String, Codable, CaseIterable {
  case left
  case center
  case justified
}

enum OverlayLineSpacingConfiguration {
  static let minimum: CGFloat = 0
  static let maximum: CGFloat = 16
  static let `default`: CGFloat = 6

  static func clamped(_ value: CGFloat) -> CGFloat {
    min(max(value, minimum), maximum)
  }
}

enum OverlayLetterSpacingConfiguration {
  static let minimum: CGFloat = -0.5
  static let maximum: CGFloat = 3
  static let `default`: CGFloat = 0

  static func clamped(_ value: CGFloat) -> CGFloat {
    min(max(value, minimum), maximum)
  }
}

enum OverlayWordSpacingConfiguration {
  static let minimum: CGFloat = 0
  static let maximum: CGFloat = 12
  static let `default`: CGFloat = 0

  static func clamped(_ value: CGFloat) -> CGFloat {
    min(max(value, minimum), maximum)
  }
}

enum OverlayTextShadowConfiguration {
  static let minimum: CGFloat = 0
  static let maximum: CGFloat = 8
  static let `default`: CGFloat = 0

  static func clamped(_ value: CGFloat) -> CGFloat {
    min(max(value, minimum), maximum)
  }
}

enum OverlayContentPaddingConfiguration {
  static let minimum: CGFloat = 12
  static let maximum: CGFloat = 28
  static let `default`: CGFloat = 16

  static func clamped(_ value: CGFloat) -> CGFloat {
    min(max(value, minimum), maximum)
  }
}

enum OverlayFontSizeConfiguration {
  static let minimum: CGFloat = 16
  static let maximum: CGFloat = 26
  static let `default`: CGFloat = 20

  static func clamped(_ value: CGFloat) -> CGFloat {
    min(max(value, minimum), maximum)
  }
}

struct OverlayAppearance: Codable, Equatable {
  var textColor: String  // hex, e.g. "#F5F2EC"
  var backgroundColor: String  // hex, e.g. "#849688"
  var opacity: Double  // 0.2–1.0; applies to background only
  var fontName: String  // "CrimsonText-Regular", "Manrope-Bold", "Inter-Regular"
  var fontSize: CGFloat {  // 16–26
    didSet {
      fontSize = OverlayFontSizeConfiguration.clamped(fontSize)
    }
  }
  var textAlignment: OverlayTextAlignment
  var lineSpacing: CGFloat {
    didSet {
      lineSpacing = OverlayLineSpacingConfiguration.clamped(lineSpacing)
    }
  }
  var letterSpacing: CGFloat {
    didSet {
      letterSpacing = OverlayLetterSpacingConfiguration.clamped(letterSpacing)
    }
  }
  var wordSpacing: CGFloat {
    didSet {
      wordSpacing = OverlayWordSpacingConfiguration.clamped(wordSpacing)
    }
  }
  var textShadow: CGFloat {
    didSet {
      textShadow = OverlayTextShadowConfiguration.clamped(textShadow)
    }
  }
  var contentPadding: CGFloat {
    didSet {
      contentPadding = OverlayContentPaddingConfiguration.clamped(contentPadding)
    }
  }

  static let `default` = OverlayAppearance(
    textColor: "#F5F2EC",
    backgroundColor: "#849688",
    opacity: 0.75,
    fontName: "CrimsonText-Regular",
    fontSize: OverlayFontSizeConfiguration.default,
    textAlignment: .left,
    lineSpacing: OverlayLineSpacingConfiguration.default,
    letterSpacing: OverlayLetterSpacingConfiguration.default,
    wordSpacing: OverlayWordSpacingConfiguration.default,
    textShadow: OverlayTextShadowConfiguration.default,
    contentPadding: OverlayContentPaddingConfiguration.default
  )

  init(
    textColor: String,
    backgroundColor: String,
    opacity: Double,
    fontName: String,
    fontSize: CGFloat,
    textAlignment: OverlayTextAlignment = .left,
    lineSpacing: CGFloat = OverlayLineSpacingConfiguration.default,
    letterSpacing: CGFloat = OverlayLetterSpacingConfiguration.default,
    wordSpacing: CGFloat = OverlayWordSpacingConfiguration.default,
    textShadow: CGFloat = OverlayTextShadowConfiguration.default,
    contentPadding: CGFloat = OverlayContentPaddingConfiguration.default
  ) {
    self.textColor = textColor
    self.backgroundColor = backgroundColor
    self.opacity = opacity
    self.fontName = fontName
    self.fontSize = OverlayFontSizeConfiguration.clamped(fontSize)
    self.textAlignment = textAlignment
    self.lineSpacing = OverlayLineSpacingConfiguration.clamped(lineSpacing)
    self.letterSpacing = OverlayLetterSpacingConfiguration.clamped(letterSpacing)
    self.wordSpacing = OverlayWordSpacingConfiguration.clamped(wordSpacing)
    self.textShadow = OverlayTextShadowConfiguration.clamped(textShadow)
    self.contentPadding = OverlayContentPaddingConfiguration.clamped(contentPadding)
  }

  private enum CodingKeys: String, CodingKey {
    case textColor
    case backgroundColor
    case opacity
    case fontName
    case fontSize
    case textAlignment
    case lineSpacing
    case letterSpacing
    case wordSpacing
    case textShadow
    case contentPadding
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    textColor = try container.decode(String.self, forKey: .textColor)
    backgroundColor = try container.decode(String.self, forKey: .backgroundColor)
    opacity = try container.decode(Double.self, forKey: .opacity)
    fontName = try container.decode(String.self, forKey: .fontName)
    fontSize = OverlayFontSizeConfiguration.clamped(
      try container.decode(CGFloat.self, forKey: .fontSize)
    )
    textAlignment =
      try container.decodeIfPresent(OverlayTextAlignment.self, forKey: .textAlignment) ?? .left
    lineSpacing = OverlayLineSpacingConfiguration.clamped(
      try container.decodeIfPresent(CGFloat.self, forKey: .lineSpacing)
        ?? OverlayLineSpacingConfiguration.default
    )
    letterSpacing = OverlayLetterSpacingConfiguration.clamped(
      try container.decodeIfPresent(CGFloat.self, forKey: .letterSpacing)
        ?? OverlayLetterSpacingConfiguration.default
    )
    wordSpacing = OverlayWordSpacingConfiguration.clamped(
      try container.decodeIfPresent(CGFloat.self, forKey: .wordSpacing)
        ?? OverlayWordSpacingConfiguration.default
    )
    textShadow = OverlayTextShadowConfiguration.clamped(
      try container.decodeIfPresent(CGFloat.self, forKey: .textShadow)
        ?? OverlayTextShadowConfiguration.default
    )
    contentPadding = OverlayContentPaddingConfiguration.clamped(
      try container.decodeIfPresent(CGFloat.self, forKey: .contentPadding)
        ?? OverlayContentPaddingConfiguration.default
    )
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(textColor, forKey: .textColor)
    try container.encode(backgroundColor, forKey: .backgroundColor)
    try container.encode(opacity, forKey: .opacity)
    try container.encode(fontName, forKey: .fontName)
    try container.encode(fontSize, forKey: .fontSize)
    try container.encode(textAlignment, forKey: .textAlignment)
    try container.encode(
      OverlayLineSpacingConfiguration.clamped(lineSpacing), forKey: .lineSpacing)
    try container.encode(
      OverlayLetterSpacingConfiguration.clamped(letterSpacing), forKey: .letterSpacing)
    try container.encode(
      OverlayWordSpacingConfiguration.clamped(wordSpacing), forKey: .wordSpacing)
    try container.encode(
      OverlayTextShadowConfiguration.clamped(textShadow), forKey: .textShadow)
    try container.encode(
      OverlayContentPaddingConfiguration.clamped(contentPadding), forKey: .contentPadding)
  }
}

enum OverlayTextStyle {
  private static let layoutSnapshotCache = OverlayTextLayoutSnapshotCache()

  static func multilineTextAlignment(for appearance: OverlayAppearance) -> TextAlignment {
    switch appearance.textAlignment {
    case .left:
      return .leading
    case .center:
      return .center
    case .justified:
      return .leading
    }
  }

  static func frameAlignment(for appearance: OverlayAppearance) -> Alignment {
    switch appearance.textAlignment {
    case .left:
      return .leading
    case .center:
      return .center
    case .justified:
      return .leading
    }
  }

  static func shadowColor(for appearance: OverlayAppearance) -> Color {
    guard appearance.textShadow > 0 else { return .clear }
    let opacity = min(0.42, 0.12 + appearance.textShadow / 20)
    return Color.black.opacity(opacity)
  }

  static func shadowYOffset(for appearance: OverlayAppearance) -> CGFloat {
    guard appearance.textShadow > 0 else { return 0 }
    return max(appearance.textShadow * 0.35, 0.5)
  }

  static func makeText(_ string: String, appearance: OverlayAppearance) -> Text {
    if let attributed = try? AttributedString(
      makeAttributedString(string, appearance: appearance),
      including: \.appKit
    ) {
      return Text(attributed)
    }

    return Text(string)
      .font(.custom(appearance.fontName, size: appearance.fontSize))
      .foregroundStyle(Color(hex: appearance.textColor))
  }

  static func makeAttributedString(
    _ string: String,
    appearance: OverlayAppearance,
    highlightedWordRange: Range<Int>? = nil,
    currentWordIndex: Int? = nil
  ) -> NSAttributedString {
    let mutable = NSMutableAttributedString(string: string)
    applyFoundationAttributes(
      to: mutable,
      appearance: appearance,
      highlightedWordRange: highlightedWordRange,
      currentWordIndex: currentWordIndex
    )
    return mutable
  }

  static func measuredHeight(
    for string: String,
    width: CGFloat,
    appearance: OverlayAppearance
  ) -> CGFloat {
    guard !string.isEmpty else { return 1 }

    let attributed = makeAttributedString(string, appearance: appearance)
    return textLayoutSize(for: attributed, width: width).height
  }

  static func applyFoundationAttributes(
    to mutable: NSMutableAttributedString,
    appearance: OverlayAppearance,
    highlightedWordRange: Range<Int>? = nil,
    currentWordIndex: Int? = nil
  ) {
    let fullRange = NSRange(location: 0, length: mutable.length)
    guard fullRange.length > 0 else { return }

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineSpacing = OverlayLineSpacingConfiguration.clamped(appearance.lineSpacing)
    paragraphStyle.alignment = nsTextAlignment(for: appearance.textAlignment)

    let nsColor = NSColor(Color(hex: appearance.textColor)).usingColorSpace(.sRGB) ?? .white
    let nsFont =
      NSFont(name: appearance.fontName, size: appearance.fontSize)
      ?? .systemFont(ofSize: appearance.fontSize)

    mutable.addAttributes(
      [
        .font: nsFont,
        .foregroundColor: nsColor,
        .paragraphStyle: paragraphStyle,
        .kern: OverlayLetterSpacingConfiguration.clamped(appearance.letterSpacing),
      ],
      range: fullRange
    )

    let text = mutable.string as NSString
    let whitespaceRegex = try? NSRegularExpression(pattern: "[ \\t]+")
    whitespaceRegex?.enumerateMatches(in: mutable.string, range: fullRange) { match, _, _ in
      guard let match else { return }
      mutable.addAttribute(
        .kern,
        value: OverlayWordSpacingConfiguration.clamped(appearance.wordSpacing),
        range: match.range
      )
    }

    let cueBackgroundColor =
      NSColor(Color("colorSecondary")).usingColorSpace(.sRGB)
      ?? NSColor(Color(hex: "#C98B7A")).usingColorSpace(.sRGB)
      ?? .systemOrange
    let cueTextColor = contrastingColor(for: cueBackgroundColor)
    let cueFont = NSFontManager.shared.convert(nsFont, toHaveTrait: .boldFontMask)

    for range in cueRanges(in: mutable.string) {
      mutable.addAttributes(
        [
          .font: cueFont,
          .foregroundColor: cueTextColor,
          .backgroundColor: cueBackgroundColor,
        ],
        range: range
      )
    }

    _ = highlightedWordRange

    if let currentWordIndex {
      let tokenSpans = VoiceSyncMatching.tokenSpans(in: mutable.string)
      let clampedIndex = min(max(currentWordIndex, 0), max(tokenSpans.count - 1, 0))
      if tokenSpans.indices.contains(clampedIndex) {
        let currentToken = tokenSpans[clampedIndex]
        mutable.addAttributes(
          [
            .foregroundColor: nsColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue | NSUnderlineStyle.thick.rawValue,
            .underlineColor: nsColor,
          ],
          range: currentToken.range
        )
      }
    }

    _ = text
  }

  private static func cueRanges(in text: String) -> [NSRange] {
    let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
    let regex = try? NSRegularExpression(pattern: #"\[[^\]\r\n]+\]"#)
    return regex?.matches(in: text, range: nsRange).map(\.range) ?? []
  }

  private static func contrastingColor(for color: NSColor) -> NSColor {
    let srgb = color.usingColorSpace(.sRGB) ?? color
    let red = srgb.redComponent
    let green = srgb.greenComponent
    let blue = srgb.blueComponent
    let luminance = (0.299 * red) + (0.587 * green) + (0.114 * blue)
    return luminance > 0.5 ? .black : .white
  }

  static func textLayoutSize(for attributed: NSAttributedString, width: CGFloat) -> CGSize {
    let clampedWidth = max(width, 1)
    let textStorage = NSTextStorage(attributedString: attributed)
    let layoutManager = NSLayoutManager()
    let textContainer = NSTextContainer(
      size: CGSize(width: clampedWidth, height: CGFloat.greatestFiniteMagnitude)
    )
    textContainer.lineFragmentPadding = 0
    textContainer.widthTracksTextView = false
    layoutManager.addTextContainer(textContainer)
    textStorage.addLayoutManager(layoutManager)
    layoutManager.ensureLayout(for: textContainer)

    let usedRect = layoutManager.usedRect(for: textContainer)
    return CGSize(width: ceil(clampedWidth), height: ceil(max(usedRect.height, 1)))
  }

  static func layoutSnapshot(
    for string: String,
    width: CGFloat,
    appearance: OverlayAppearance
  ) -> OverlayTextLayoutSnapshot {
    let clampedWidth = max(width, 1)
    let cacheKey = OverlayTextLayoutSnapshotCache.Key(
      string: string,
      width: clampedWidth,
      appearance: appearance
    )
    if let cachedSnapshot = layoutSnapshotCache.snapshot(for: cacheKey) {
      return cachedSnapshot
    }

    let attributedText = makeAttributedString(string, appearance: appearance)
    let textHeight = textLayoutSize(for: attributedText, width: clampedWidth).height
    let lineMetrics = PrompterTextMetrics.calculateLines(
      text: string,
      attributedText: attributedText,
      width: clampedWidth
    )

    let snapshot = OverlayTextLayoutSnapshot(
      string: string,
      attributedText: attributedText,
      width: clampedWidth,
      textHeight: textHeight,
      lineMetrics: lineMetrics,
      pointsPerWord: PrompterScrollMath.pointsPerWord(lineMetrics: lineMetrics)
    )
    layoutSnapshotCache.store(snapshot, for: cacheKey)
    return snapshot
  }

  private static func nsTextAlignment(for alignment: OverlayTextAlignment) -> NSTextAlignment {
    switch alignment {
    case .left:
      return .left
    case .center:
      return .center
    case .justified:
      return .justified
    }
  }
}

private final class OverlayTextLayoutSnapshotCache {
  struct Key: Hashable {
    let string: String
    let width: CGFloat

    let textColor: String
    let backgroundColor: String
    let opacity: Double
    let fontName: String
    let fontSize: Double
    let textAlignmentRawValue: String
    let lineSpacing: Double
    let letterSpacing: Double
    let wordSpacing: Double
    let textShadow: Double
    let contentPadding: Double

    init(string: String, width: CGFloat, appearance: OverlayAppearance) {
      self.string = string
      self.width = width
      textColor = appearance.textColor
      backgroundColor = appearance.backgroundColor
      opacity = appearance.opacity
      fontName = appearance.fontName
      fontSize = appearance.fontSize
      textAlignmentRawValue = appearance.textAlignment.rawValue
      lineSpacing = appearance.lineSpacing
      letterSpacing = appearance.letterSpacing
      wordSpacing = appearance.wordSpacing
      textShadow = appearance.textShadow
      contentPadding = appearance.contentPadding
    }
  }

  private let countLimit = 32
  private let cache = NSCache<WrappedKey, Entry>()

  init() {
    cache.countLimit = countLimit
  }

  func snapshot(for key: Key) -> OverlayTextLayoutSnapshot? {
    cache.object(forKey: WrappedKey(key))?.snapshot
  }

  func store(_ snapshot: OverlayTextLayoutSnapshot, for key: Key) {
    cache.setObject(Entry(snapshot: snapshot), forKey: WrappedKey(key))
  }

  private final class Entry: NSObject {
    let snapshot: OverlayTextLayoutSnapshot

    init(snapshot: OverlayTextLayoutSnapshot) {
      self.snapshot = snapshot
    }
  }

  private final class WrappedKey: NSObject {
    private let key: Key

    init(_ key: Key) {
      self.key = key
    }

    override var hash: Int {
      key.hashValue
    }

    override func isEqual(_ object: Any?) -> Bool {
      guard let other = object as? WrappedKey else { return false }
      return key == other.key
    }
  }
}

struct OverlayTextLayoutSnapshot {
  let string: String
  let attributedText: NSAttributedString
  let width: CGFloat
  let textHeight: CGFloat
  let lineMetrics: [LineMetric]
  let pointsPerWord: Double

  static let empty = OverlayTextLayoutSnapshot(
    string: "",
    attributedText: NSAttributedString(string: ""),
    width: 1,
    textHeight: 1,
    lineMetrics: [],
    pointsPerWord: 0
  )
}
