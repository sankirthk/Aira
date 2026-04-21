import CoreGraphics
import Testing

@testable import Aira

struct NotchPreviewLayoutTests {
  @Test func defaultPreviewTextFitsWithinDefaultNotchPreviewHeight() {
    let appearance = OverlayAppearance.default
    let layout = NotchPreviewLayout.resolve(
      preferredWidth: NotchWidthConfiguration.defaultWidth,
      preferredHeight: NotchHeightConfiguration.defaultHeight,
      hasPhysicalNotch: true,
      appearance: appearance
    )
    let textHeight = NotchPreviewLayout.measuredTextHeight(
      text: NotchPreviewLayout.defaultSampleText,
      previewWidth: layout.width,
      appearance: appearance
    )
    let availableHeight = NotchPreviewLayout.availableTextHeight(
      previewHeight: layout.height,
      hasPhysicalNotch: true,
      appearance: appearance
    )

    #expect(textHeight <= availableHeight)
  }

  @Test func previewAutoExpandsForLargeReadabilitySettings() {
    let appearance = OverlayAppearance(
      textColor: "#F5F2EC",
      backgroundColor: "#849688",
      opacity: 0.75,
      fontName: "CrimsonText-Regular",
      fontSize: 32,
      textAlignment: .justified,
      lineSpacing: OverlayLineSpacingConfiguration.maximum,
      letterSpacing: OverlayLetterSpacingConfiguration.maximum,
      wordSpacing: OverlayWordSpacingConfiguration.maximum,
      textShadow: OverlayTextShadowConfiguration.maximum,
      contentPadding: OverlayContentPaddingConfiguration.maximum
    )
    let baseWidth = NotchPreviewLayout.previewWidth(for: NotchWidthConfiguration.minimumWidth)
    let baseHeight = NotchPreviewLayout.previewHeight(for: NotchHeightConfiguration.minimumHeight)
    let layout = NotchPreviewLayout.resolve(
      preferredWidth: NotchWidthConfiguration.minimumWidth,
      preferredHeight: NotchHeightConfiguration.minimumHeight,
      hasPhysicalNotch: true,
      appearance: appearance
    )
    let textHeight = NotchPreviewLayout.measuredTextHeight(
      text: NotchPreviewLayout.defaultSampleText,
      previewWidth: layout.width,
      appearance: appearance
    )
    let availableHeight = NotchPreviewLayout.availableTextHeight(
      previewHeight: layout.height,
      hasPhysicalNotch: true,
      appearance: appearance
    )

    #expect(layout.width >= baseWidth)
    #expect(layout.height >= baseHeight)
    #expect(layout.width > baseWidth || layout.height > baseHeight)
    #expect(textHeight <= availableHeight)
  }
}
