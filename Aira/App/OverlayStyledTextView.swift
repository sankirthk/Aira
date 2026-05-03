import AppKit
import SwiftUI

struct OverlayStyledTextView: NSViewRepresentable {
  let attributedText: NSAttributedString
  let width: CGFloat
  let highlightedWordRange: Range<Int>?
  let currentWordIndex: Int?
  let highlightColor: NSColor
  let underlineColor: NSColor
  var onWordClick: ((Int) -> Void)? = nil

  func makeNSView(context: Context) -> OverlayStyledTextContainerView {
    OverlayStyledTextContainerView()
  }

  func updateNSView(_ nsView: OverlayStyledTextContainerView, context: Context) {
    nsView.configure(
      attributedText: attributedText,
      width: max(width, 1),
      highlightedWordRange: highlightedWordRange,
      currentWordIndex: currentWordIndex,
      highlightColor: highlightColor,
      underlineColor: underlineColor,
      onWordClick: onWordClick
    )
  }
}

struct OverlayAppearancePreviewText: View {
  let text: String
  let appearance: OverlayAppearance
  let width: CGFloat
  var topPadding: CGFloat = 0
  var bottomPadding: CGFloat = 0

  private var snapshot: OverlayTextLayoutSnapshot {
    OverlayTextStyle.layoutSnapshot(
      for: text,
      width: max(width - (appearance.contentPadding * 2), 1),
      appearance: appearance
    )
  }

  private var frameAlignment: Alignment {
    switch appearance.textAlignment {
    case .left, .justified:
      return .topLeading
    case .center:
      return .top
    }
  }

  var body: some View {
    OverlayStyledTextView(
      attributedText: snapshot.attributedText,
      width: snapshot.width,
      highlightedWordRange: nil,
      currentWordIndex: nil,
      highlightColor: NSColor(Color(hex: appearance.textColor)).usingColorSpace(.sRGB) ?? .white,
      underlineColor: NSColor(Color(hex: appearance.textColor)).usingColorSpace(.sRGB) ?? .white
    )
    .fixedSize(horizontal: false, vertical: true)
    .frame(
      width: snapshot.width,
      height: snapshot.textHeight,
      alignment: frameAlignment
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    .padding(.horizontal, appearance.contentPadding)
    .padding(.top, topPadding + appearance.contentPadding)
    .padding(.bottom, bottomPadding + appearance.contentPadding)
    .shadow(
      color: OverlayTextStyle.shadowColor(for: appearance),
      radius: appearance.textShadow,
      y: OverlayTextStyle.shadowYOffset(for: appearance)
    )
  }
}

final class OverlayStyledTextContainerView: NSView {
  private let textView: NSTextView
  private let textContainer: NSTextContainer
  private let layoutManager: NSLayoutManager
  private let textStorage: NSTextStorage
  private var preferredWidth: CGFloat = 1
  private var measuredHeight: CGFloat = 1
  private var tokenSpans: [VoiceSyncMatching.TokenSpan] = []
  private var highlightedWordCharacterRange: NSRange?
  private var highlightedTokenRange: NSRange?
  private var onWordClick: ((Int) -> Void)?

  override init(frame frameRect: NSRect) {
    textContainer = NSTextContainer(
      size: CGSize(width: 1, height: CGFloat.greatestFiniteMagnitude)
    )
    textContainer.lineFragmentPadding = 0
    textContainer.widthTracksTextView = false

    layoutManager = NSLayoutManager()
    layoutManager.addTextContainer(textContainer)

    textStorage = NSTextStorage()
    textStorage.addLayoutManager(layoutManager)

    textView = NSTextView(frame: .zero, textContainer: textContainer)
    textView.drawsBackground = false
    textView.isEditable = false
    textView.isSelectable = false
    textView.isRichText = true
    textView.importsGraphics = false
    textView.isHorizontallyResizable = false
    textView.isVerticallyResizable = true
    textView.autoresizingMask = [.width, .height]
    textView.textContainerInset = .zero
    textView.textContainer?.lineFragmentPadding = 0

    super.init(frame: frameRect)
    addSubview(textView)
    setContentHuggingPriority(.required, for: .vertical)
    setContentCompressionResistancePriority(.required, for: .vertical)
    textView.setContentHuggingPriority(.required, for: .vertical)
    textView.setContentCompressionResistancePriority(.required, for: .vertical)
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard onWordClick != nil, bounds.contains(point) else { return nil }
    return self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(
    attributedText: NSAttributedString,
    width: CGFloat,
    highlightedWordRange: Range<Int>?,
    currentWordIndex: Int?,
    highlightColor: NSColor,
    underlineColor: NSColor,
    onWordClick: ((Int) -> Void)?
  ) {
    self.onWordClick = onWordClick
    let clampedWidth = max(width, 1)
    let contentChanged = !attributedText.isEqual(to: textStorage)
    if clampedWidth == preferredWidth && !contentChanged {
      applyHighlight(
        highlightedWordRange: highlightedWordRange,
        currentWordIndex: currentWordIndex,
        highlightColor: highlightColor,
        underlineColor: underlineColor
      )
      return
    }

    preferredWidth = clampedWidth
    textContainer.containerSize = CGSize(
      width: clampedWidth,
      height: CGFloat.greatestFiniteMagnitude
    )

    textStorage.setAttributedString(attributedText)
    tokenSpans = VoiceSyncMatching.tokenSpans(in: attributedText.string)
    layoutManager.ensureLayout(for: textContainer)

    let usedRect = layoutManager.usedRect(for: textContainer)
    measuredHeight = ceil(max(usedRect.height, 1))
    textView.frame = NSRect(x: 0, y: 0, width: clampedWidth, height: measuredHeight)
    frame = textView.frame

    invalidateIntrinsicContentSize()
    needsLayout = true
    applyHighlight(
      highlightedWordRange: highlightedWordRange,
      currentWordIndex: currentWordIndex,
      highlightColor: highlightColor,
      underlineColor: underlineColor
    )
  }

  private func applyHighlight(
    highlightedWordRange: Range<Int>?,
    currentWordIndex: Int?,
    highlightColor: NSColor,
    underlineColor: NSColor
  ) {
    if let highlightedTokenRange {
      layoutManager.removeTemporaryAttribute(
        .underlineStyle, forCharacterRange: highlightedTokenRange)
      layoutManager.removeTemporaryAttribute(
        .underlineColor, forCharacterRange: highlightedTokenRange)
      self.highlightedTokenRange = nil
    }

    updateHighlightedWordRange(
      characterRange: highlightedWordRange.flatMap(characterRange(for:)),
      highlightColor: highlightColor
    )

    guard let currentWordIndex else {
      textView.needsDisplay = true
      needsDisplay = true
      return
    }

    let clampedIndex = min(max(currentWordIndex, 0), max(tokenSpans.count - 1, 0))
    guard tokenSpans.indices.contains(clampedIndex) else {
      textView.needsDisplay = true
      needsDisplay = true
      return
    }

    let range = tokenSpans[clampedIndex].range
    layoutManager.addTemporaryAttributes(
      Self.currentWordTemporaryAttributes(underlineColor: underlineColor),
      forCharacterRange: range
    )
    highlightedTokenRange = range
    layoutManager.invalidateDisplay(forCharacterRange: range)
    textView.needsDisplay = true
    needsDisplay = true
  }

  private func updateHighlightedWordRange(characterRange: NSRange?, highlightColor: NSColor) {
    switch (highlightedWordCharacterRange, characterRange) {
    case (let oldRange?, let newRange?) where NSEqualRanges(oldRange, newRange):
      return
    case (let oldRange?, let newRange?) where oldRange.location == newRange.location:
      let oldUpperBound = oldRange.location + oldRange.length
      let newUpperBound = newRange.location + newRange.length

      if newUpperBound > oldUpperBound {
        let deltaRange = NSRange(location: oldUpperBound, length: newUpperBound - oldUpperBound)
        layoutManager.addTemporaryAttribute(
          .foregroundColor,
          value: highlightColor,
          forCharacterRange: deltaRange
        )
        layoutManager.invalidateDisplay(forCharacterRange: deltaRange)
      } else if newUpperBound < oldUpperBound {
        let deltaRange = NSRange(location: newUpperBound, length: oldUpperBound - newUpperBound)
        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: deltaRange)
        layoutManager.invalidateDisplay(forCharacterRange: deltaRange)
      }

      highlightedWordCharacterRange = newRange
    case (let oldRange?, nil):
      layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: oldRange)
      layoutManager.invalidateDisplay(forCharacterRange: oldRange)
      highlightedWordCharacterRange = nil
    case (nil, let newRange?):
      layoutManager.addTemporaryAttribute(
        .foregroundColor,
        value: highlightColor,
        forCharacterRange: newRange
      )
      layoutManager.invalidateDisplay(forCharacterRange: newRange)
      highlightedWordCharacterRange = newRange
    case (let oldRange?, let newRange?):
      layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: oldRange)
      layoutManager.addTemporaryAttribute(
        .foregroundColor,
        value: highlightColor,
        forCharacterRange: newRange
      )
      layoutManager.invalidateDisplay(forCharacterRange: oldRange)
      layoutManager.invalidateDisplay(forCharacterRange: newRange)
      highlightedWordCharacterRange = newRange
    case (nil, nil):
      break
    }
  }

  override func mouseDown(with event: NSEvent) {
    guard let onWordClick else {
      super.mouseDown(with: event)
      return
    }

    let point = convert(event.locationInWindow, from: nil)
    guard let wordIndex = wordIndex(at: point) else {
      super.mouseDown(with: event)
      return
    }

    onWordClick(wordIndex)
  }

  private func characterRange(for tokenRange: Range<Int>) -> NSRange? {
    let lowerBound = min(max(tokenRange.lowerBound, 0), tokenSpans.count)
    let upperBound = min(max(tokenRange.upperBound, lowerBound), tokenSpans.count)
    guard lowerBound < upperBound else { return nil }

    let firstRange = tokenSpans[lowerBound].range
    let lastRange = tokenSpans[upperBound - 1].range
    let location = firstRange.location
    let upperLocation = lastRange.location + lastRange.length
    guard upperLocation > location else { return nil }
    return NSRange(location: location, length: upperLocation - location)
  }

  private func wordIndex(at point: NSPoint) -> Int? {
    guard bounds.contains(point), !tokenSpans.isEmpty else { return nil }

    let textPoint = convert(point, to: textView)
    let containerOrigin = textView.textContainerOrigin
    let containerPoint = NSPoint(
      x: textPoint.x - containerOrigin.x,
      y: textPoint.y - containerOrigin.y
    )

    let glyphRange = layoutManager.glyphRange(for: textContainer)
    let usedRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
    guard usedRect.contains(containerPoint) else { return nil }

    var fraction: CGFloat = 0
    let glyphIndex = layoutManager.glyphIndex(
      for: containerPoint,
      in: textContainer,
      fractionOfDistanceThroughGlyph: &fraction
    )
    guard glyphIndex < layoutManager.numberOfGlyphs else { return nil }

    let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
    return tokenSpans.firstIndex { NSLocationInRange(characterIndex, $0.range) }
  }

  override func layout() {
    super.layout()
    textView.frame = bounds
  }

  override var fittingSize: NSSize {
    intrinsicContentSize
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: ceil(preferredWidth), height: measuredHeight)
  }

  static func currentWordTemporaryAttributes(
    underlineColor: NSColor
  ) -> [NSAttributedString.Key: Any] {
    [
      .underlineStyle: NSUnderlineStyle.single.rawValue | NSUnderlineStyle.thick.rawValue,
      .underlineColor: underlineColor,
    ]
  }
}
