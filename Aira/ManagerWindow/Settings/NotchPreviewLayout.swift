import SwiftUI

enum NotchPreviewLayout {
  struct ResolvedLayout: Equatable {
    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
  }

  static let defaultSampleText = "Your script starts here."

  private static let minimumPreviewWidth: CGFloat = 240
  private static let previewWidthRange: CGFloat = 160
  private static let minimumPreviewHeight: CGFloat = 108
  private static let previewHeightRange: CGFloat = 48
  private static let maximumAutoFitWidth: CGFloat = 520
  private static let maximumAutoFitHeight: CGFloat = 240
  private static let notchCutoutDepthRatio: CGFloat = 30.0 / 110.0
  private static let minimumReadableGap: CGFloat = 12
  private static let previewWidthStep: CGFloat = 8
  private static let previewHeightStep: CGFloat = 4

  static func previewWidth(for preferredWidth: Double) -> CGFloat {
    let normalized =
      (preferredWidth - NotchWidthConfiguration.minimumWidth)
      / (NotchWidthConfiguration.maximumWidth - NotchWidthConfiguration.minimumWidth)
    let clamped = min(max(normalized, 0), 1)
    return minimumPreviewWidth + (previewWidthRange * clamped)
  }

  static func previewHeight(for preferredHeight: Double) -> CGFloat {
    let normalized =
      (preferredHeight - NotchHeightConfiguration.minimumHeight)
      / (NotchHeightConfiguration.maximumHeight - NotchHeightConfiguration.minimumHeight)
    let clamped = min(max(normalized, 0), 1)
    return minimumPreviewHeight + (previewHeightRange * clamped)
  }

  static func resolve(
    text: String = defaultSampleText,
    preferredWidth: Double,
    preferredHeight: Double,
    hasPhysicalNotch: Bool,
    appearance: OverlayAppearance
  ) -> ResolvedLayout {
    let maximumWidth = maximumAutoFitWidth
    let maximumHeight = maximumAutoFitHeight

    var width = previewWidth(for: preferredWidth)
    var height = previewHeight(for: preferredHeight)

    while true {
      let textHeight = measuredTextHeight(text: text, previewWidth: width, appearance: appearance)
      let availableHeight = availableTextHeight(
        previewHeight: height,
        hasPhysicalNotch: hasPhysicalNotch,
        appearance: appearance
      )

      if textHeight <= availableHeight {
        return ResolvedLayout(
          width: width,
          height: height,
          topPadding: textTopPadding(
            previewHeight: height,
            hasPhysicalNotch: hasPhysicalNotch,
            appearance: appearance
          )
        )
      }

      let canGrowWidth = width < maximumWidth
      let canGrowHeight = height < maximumHeight

      guard canGrowWidth || canGrowHeight else {
        return ResolvedLayout(
          width: width,
          height: height,
          topPadding: textTopPadding(
            previewHeight: height,
            hasPhysicalNotch: hasPhysicalNotch,
            appearance: appearance
          )
        )
      }

      if canGrowWidth {
        width = min(width + previewWidthStep, maximumWidth)
      }

      if canGrowHeight {
        let updatedTextHeight = measuredTextHeight(
          text: text, previewWidth: width, appearance: appearance)
        let updatedAvailableHeight = availableTextHeight(
          previewHeight: height,
          hasPhysicalNotch: hasPhysicalNotch,
          appearance: appearance
        )

        if updatedTextHeight > updatedAvailableHeight {
          height = min(height + previewHeightStep, maximumHeight)
        }
      }
    }
  }

  static func textTopPadding(
    previewHeight: CGFloat,
    hasPhysicalNotch: Bool,
    appearance: OverlayAppearance
  ) -> CGFloat {
    let cutoutInset = hasPhysicalNotch ? previewHeight * notchCutoutDepthRatio : 0
    let fontClearance = max(minimumReadableGap, appearance.fontSize * 0.35)
    return cutoutInset + fontClearance
  }

  static func availableTextHeight(
    previewHeight: CGFloat,
    hasPhysicalNotch: Bool,
    appearance: OverlayAppearance
  ) -> CGFloat {
    max(
      previewHeight
        - textTopPadding(
          previewHeight: previewHeight,
          hasPhysicalNotch: hasPhysicalNotch,
          appearance: appearance
        )
        - (appearance.contentPadding * 2),
      1
    )
  }

  static func measuredTextHeight(
    text: String = defaultSampleText,
    previewWidth: CGFloat,
    appearance: OverlayAppearance
  ) -> CGFloat {
    OverlayTextStyle.measuredHeight(
      for: text,
      width: max(previewWidth - (appearance.contentPadding * 2), 1),
      appearance: appearance
    )
  }
}
