import CoreGraphics
import Testing

@testable import Aira

struct NotchPreviewLayoutTests {
  @Test func resolveScalesRuntimePanelGeometryAndNotchSize() {
    let appearance = OverlayAppearance.default
    let notchSize = CGSize(width: 128, height: 32)

    let actualWidth = NotchWindowController.resolvedPanelWidth(NotchWidthConfiguration.defaultWidth)
    let actualHeight = NotchWindowController.resolvedPanelHeight(
      NotchHeightConfiguration.defaultHeight,
      notchHeight: notchSize.height,
      appearance: appearance
    )
    let expectedScale = min(420 / actualWidth, 220 / actualHeight, 1)

    let layout = NotchPreviewLayout.resolve(
      preferredWidth: NotchWidthConfiguration.defaultWidth,
      preferredHeight: NotchHeightConfiguration.defaultHeight,
      notchSize: notchSize,
      appearance: appearance
    )

    #expect(layout.width == actualWidth * expectedScale)
    #expect(layout.height == actualHeight * expectedScale)
    #expect(layout.notchSize.width == notchSize.width * expectedScale)
    #expect(layout.notchSize.height == notchSize.height * expectedScale)
    #expect(
      layout.topPadding
        == NotchPreviewLayout.textTopPadding(
          notchSize: layout.notchSize,
          appearance: appearance,
          scale: expectedScale
        )
    )
  }

  @Test func resolveUsesClampedPanelDimensionsForOutOfRangeInputs() {
    let appearance = OverlayAppearance(
      textColor: "#F5F2EC",
      backgroundColor: "#849688",
      opacity: 0.75,
      fontName: "CrimsonText-Regular",
      fontSize: OverlayFontSizeConfiguration.maximum,
      textAlignment: .justified,
      lineSpacing: OverlayLineSpacingConfiguration.maximum,
      letterSpacing: OverlayLetterSpacingConfiguration.maximum,
      wordSpacing: OverlayWordSpacingConfiguration.maximum,
      textShadow: OverlayTextShadowConfiguration.maximum,
      contentPadding: OverlayContentPaddingConfiguration.maximum
    )
    let notchSize = CGSize(width: 128, height: 32)

    let clampedWidth = NotchWindowController.resolvedPanelWidth(
      NotchWidthConfiguration.maximumWidth)
    let clampedHeight = NotchWindowController.resolvedPanelHeight(
      NotchHeightConfiguration.maximumHeight + 999,
      notchHeight: notchSize.height,
      appearance: appearance
    )
    let expectedScale = min(420 / clampedWidth, 220 / clampedHeight, 1)

    let layout = NotchPreviewLayout.resolve(
      preferredWidth: NotchWidthConfiguration.maximumWidth + 999,
      preferredHeight: NotchHeightConfiguration.maximumHeight + 999,
      notchSize: notchSize,
      appearance: appearance
    )

    #expect(layout.width == clampedWidth * expectedScale)
    #expect(layout.height == clampedHeight * expectedScale)
    #expect(layout.topPadding > layout.notchSize.height)
  }
}
