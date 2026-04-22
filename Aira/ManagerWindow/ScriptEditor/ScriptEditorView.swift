import AppKit
import SwiftUI

struct ScriptEditorLaunchMenuAction: Identifiable, Equatable {
  enum Kind: Equatable {
    case castToNotch
    case castWithSatellite
  }

  let kind: Kind
  let title: String

  var id: String { title }

  static let defaultItems: [ScriptEditorLaunchMenuAction] = [
    .init(kind: .castToNotch, title: "Cast to Notch"),
    .init(kind: .castWithSatellite, title: "Cast with Satellite…"),
  ]
}

struct ScriptEditorView: View {
  @EnvironmentObject var appState: AppState
  @Binding var script: Script
  @State private var saveErrorMessage: String?
  @State private var selectedRange = NSRange(location: 0, length: 0)
  let managerFontScale: CGFloat
  let isReadOnly: Bool
  var onCast: () -> Void
  var onCastWithSatellite: () -> Void = {}
  var onBack: () -> Void

  var wordCount: Int {
    ScriptEditorMetrics.wordCount(for: script.body)
  }

  var estimatedDuration: String {
    let minutes = max(1, wordCount / 130)
    return "\(wordCount) words · ~\(minutes)m"
  }

  private func scaled(_ size: CGFloat) -> CGFloat {
    size * managerFontScale
  }

  var body: some View {
    VStack(spacing: 0) {

      HStack(spacing: 12) {
        Button {
          onBack()
        } label: {
          AiraIcon(type: .back, size: 20, color: Color("colorBackground"), animated: false)
            .padding(8)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)

        TextField("Script title", text: $script.title)
          .font(.custom("Manrope-Bold", size: scaled(20)))
          .textFieldStyle(.plain)
          .foregroundStyle(Color("colorBackground"))
          .tint(Color("colorSecondary"))
          .disabled(isReadOnly)

        Spacer()

        Text(estimatedDuration)
          .font(.custom("Inter-Regular", size: scaled(13)))
          .foregroundStyle(Color("colorBackground").opacity(0.72))

        if isReadOnly {
          Text("Live script · read only")
            .font(.custom("CrimsonText-Regular", size: scaled(13)))
            .foregroundStyle(Color("colorBackground"))
        }

        Button {
          saveScript()
        } label: {
          HStack(spacing: 8) {
            AiraIcon(type: .save, size: 18, color: Color("colorText"), animated: false)
            Text("Save")
          }
        }
        .buttonStyle(AiraWobblyToolbarButtonStyle(variant: .tertiary))
        .disabled(isReadOnly)
        .opacity(isReadOnly ? 0.55 : 1)

        HStack(spacing: 8) {
          Button {
            onCast()
          } label: {
            HStack(spacing: 8) {
              AiraIcon(type: .notch, size: 18, color: .white, animated: false)
              Text("Cast to Notch")
            }
          }
          .buttonStyle(AiraWobblyToolbarButtonStyle(variant: .secondary))

          Menu {
            ForEach(ScriptEditorLaunchMenuAction.defaultItems) { action in
              Button(action.title) {
                handleLaunchMenuAction(action.kind)
              }
            }
          } label: {
            Image(systemName: "chevron.down")
              .font(.system(size: 12, weight: .semibold))
              .frame(width: 18, height: 18)
          }
          .menuStyle(.borderlessButton)
          .fixedSize()
        }
        .buttonStyle(AiraWobblyToolbarButtonStyle(variant: .secondary))
        .disabled(isReadOnly)
        .opacity(isReadOnly ? 0.55 : 1)
      }
      .padding(16)
      .background(Color("colorPrimary"))

      HStack(alignment: .top, spacing: 24) {
        ScriptEditorPanel(backgroundColor: Color("colorBackground")) {
          VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
              RoundedRectangle(cornerRadius: 10)
                .fill(Color("colorBackground"))
                .overlay(
                  RoundedRectangle(cornerRadius: 10)
                    .stroke(Color("colorText").opacity(0.2), lineWidth: 2)
                )

              ScriptTextEditor(
                text: $script.body,
                selectedRange: $selectedRange,
                isEditable: !isReadOnly
              )
              .padding(14)
              .frame(maxWidth: .infinity, maxHeight: .infinity)

              if script.body.isEmpty {
                Text("Start typing your script here...")
                  .font(.custom("CrimsonText-Regular", size: scaled(18)))
                  .foregroundStyle(Color("colorText").opacity(0.4))
                  .padding(.horizontal, 20)
                  .padding(.vertical, 20)
                  .allowsHitTesting(false)
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
              Text("\(wordCount) words")
              Spacer()
              Text("\(script.body.count) characters")
            }
            .font(.custom("CrimsonText-Regular", size: scaled(15)))
            .foregroundStyle(Color("colorMuted"))
            .padding(.top, 16)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        CuePanelView(isReadOnly: isReadOnly, onInsertCue: insertCue)
          .frame(width: 320)
      }
      .background(Color("colorBackground"))
      .padding(24)
    }
    .alert("Unable to Save Script", isPresented: saveErrorIsPresented) {
      Button("OK", role: .cancel) {
        saveErrorMessage = nil
      }
    } message: {
      Text(saveErrorMessage ?? "Please try again.")
    }
  }

  private var saveErrorIsPresented: Binding<Bool> {
    Binding(
      get: { saveErrorMessage != nil },
      set: { isPresented in
        if isPresented == false {
          saveErrorMessage = nil
        }
      }
    )
  }

  private func saveScript() {
    guard !isReadOnly else {
      return
    }

    do {
      try appState.saveScript(script)
      if let savedScript = appState.activeScript {
        script = savedScript
      }
    } catch {
      saveErrorMessage = error.localizedDescription
    }
  }

  private func insertCue(_ cue: String) {
    guard !isReadOnly else {
      return
    }

    let result = ScriptEditorTextInsertion.insertCue(
      cue,
      into: script.body,
      selectedRange: selectedRange
    )
    script.body = result.text
    selectedRange = result.selectedRange
  }

  private func handleLaunchMenuAction(_ action: ScriptEditorLaunchMenuAction.Kind) {
    switch action {
    case .castToNotch:
      onCast()
    case .castWithSatellite:
      onCastWithSatellite()
    }
  }
}

enum ScriptEditorMetrics {
  static func wordCount(for body: String) -> Int {
    body.split(whereSeparator: \.isWhitespace).count
  }
}

struct ScriptEditorPanel<Content: View>: View {
  let backgroundColor: Color
  @ViewBuilder var content: Content

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12)
        .fill(backgroundColor)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color("colorText"), lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

      RoundedRectangle(cornerRadius: 10)
        .inset(by: 3)
        .stroke(
          Color("colorText").opacity(0.3),
          style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [4, 2])
        )

      content
        .padding(32)
    }
  }
}

struct ScriptTextEditor: NSViewRepresentable {
  @Binding var text: String
  @Binding var selectedRange: NSRange
  let isEditable: Bool

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text, selectedRange: $selectedRange)
  }

  static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
    (nsView.documentView as? NSTextView)?.delegate = nil
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.borderType = .noBorder
    scrollView.autohidesScrollers = true

    let textView = ScriptEditorNSTextView()
    textView.isRichText = false
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.allowsUndo = true
    textView.backgroundColor = .clear
    textView.drawsBackground = false
    textView.textColor = NSColor(Color("colorText"))
    textView.insertionPointColor = NSColor(Color("colorText"))
    textView.font = NSFont(name: "CrimsonText-Regular", size: 18) ?? .systemFont(ofSize: 18)
    textView.isEditable = isEditable
    textView.isSelectable = true
    textView.isHorizontallyResizable = false
    textView.isVerticallyResizable = true
    textView.autoresizingMask = [.width]
    textView.textContainerInset = NSSize(width: 0, height: 2)
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = true
    textView.delegate = context.coordinator
    textView.string = text
    context.coordinator.applyCueStyling(to: textView)
    textView.selectedRange = selectedRange

    scrollView.documentView = textView
    context.coordinator.textView = textView
    return scrollView
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let textView = nsView.documentView as? NSTextView else {
      return
    }

    context.coordinator.text = $text
    context.coordinator.selectedRange = $selectedRange
    textView.isEditable = isEditable

    if textView.string != text {
      textView.string = text
      context.coordinator.applyCueStyling(to: textView)
    }

    if textView.selectedRange() != selectedRange {
      context.coordinator.isApplyingSelectionChange = true
      textView.setSelectedRange(selectedRange)
      context.coordinator.isApplyingSelectionChange = false
      textView.scrollRangeToVisible(selectedRange)
    }
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    var text: Binding<String>
    var selectedRange: Binding<NSRange>
    var isApplyingSelectionChange = false
    weak var textView: NSTextView?

    init(text: Binding<String>, selectedRange: Binding<NSRange>) {
      self.text = text
      self.selectedRange = selectedRange
    }

    func textDidChange(_ notification: Notification) {
      guard let textView else { return }
      text.wrappedValue = textView.string
      applyCueStyling(to: textView)
      selectedRange.wrappedValue = textView.selectedRange()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
      guard let textView else { return }
      guard isApplyingSelectionChange == false else { return }
      selectedRange.wrappedValue = textView.selectedRange()
    }

    func applyCueStyling(to textView: NSTextView) {
      guard let textStorage = textView.textStorage else { return }

      let selectedRange = textView.selectedRange()
      let baseFont = textView.font ?? .systemFont(ofSize: 18)
      let textColor = NSColor(Color("colorText"))
      let cueTextColor = NSColor(Color("colorBackground"))
      let cueBackgroundColor = NSColor(Color("colorSecondary"))
      let baseAttributes: [NSAttributedString.Key: Any] = [
        .font: baseFont,
        .foregroundColor: textColor,
      ]
      let cueFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)

      isApplyingSelectionChange = true
      textStorage.beginEditing()
      textStorage.setAttributes(
        baseAttributes, range: NSRange(location: 0, length: textStorage.length))

      for range in ScriptEditorCueStyling.cueRanges(in: textView.string) {
        textStorage.addAttributes(
          [
            .font: cueFont,
            .foregroundColor: cueTextColor,
            .backgroundColor: cueBackgroundColor,
          ],
          range: range
        )
      }

      textStorage.endEditing()
      textView.setSelectedRange(selectedRange)
      textView.typingAttributes = ScriptEditorCueStyling.typingAttributes(
        forInsertionLocation: selectedRange.location,
        in: textView.string,
        baseAttributes: baseAttributes,
        cueAttributes: [
          .font: cueFont,
          .foregroundColor: cueTextColor,
          .backgroundColor: cueBackgroundColor,
        ]
      )
      isApplyingSelectionChange = false
    }
  }
}

final class ScriptEditorNSTextView: NSTextView {
  override func paste(_ sender: Any?) {
    guard
      isEditable,
      let pastedString = NSPasteboard.general.string(forType: .string),
      let transformed = ScriptEditorMarkdownPaste.normalizedTextIfMarkdown(pastedString)
    else {
      super.paste(sender)
      return
    }

    insertText(transformed, replacementRange: selectedRange())
  }
}

enum ScriptEditorCueStyling {
  static func cueRanges(in text: String) -> [NSRange] {
    let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
    let regex = try? NSRegularExpression(pattern: #"\[[^\]\r\n]+\]"#)
    return regex?.matches(in: text, range: nsRange).map(\.range) ?? []
  }

  static func applyCueAnnotationStyling(
    to attributedString: NSMutableAttributedString,
    baseFont: NSFont,
    textColor: NSColor,
    cueTextColor: NSColor,
    cueBackgroundColor: NSColor
  ) {
    let fullRange = NSRange(location: 0, length: attributedString.length)
    attributedString.setAttributes(
      [
        .font: baseFont,
        .foregroundColor: textColor,
      ],
      range: fullRange
    )

    let cueFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
    for range in cueRanges(in: attributedString.string) {
      attributedString.addAttributes(
        [
          .font: cueFont,
          .foregroundColor: cueTextColor,
          .backgroundColor: cueBackgroundColor,
        ],
        range: range
      )
    }
  }

  static func typingAttributes(
    forInsertionLocation location: Int,
    in text: String,
    baseAttributes: [NSAttributedString.Key: Any],
    cueAttributes: [NSAttributedString.Key: Any]
  ) -> [NSAttributedString.Key: Any] {
    for range in cueRanges(in: text) {
      if location > range.location && location < NSMaxRange(range) {
        return cueAttributes
      }
    }

    return baseAttributes
  }
}
