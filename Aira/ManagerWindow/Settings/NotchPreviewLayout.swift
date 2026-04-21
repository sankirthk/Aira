import SwiftUI

enum NotchPreviewLayout {
  struct ResolvedLayout: Equatable {
    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    let notchSize: CGSize
  }

  static let defaultSampleText = "Your script starts here."

  private static let maximumPreviewWidth: CGFloat = 420
  private static let maximumPreviewHeight: CGFloat = 220
  private static let minimumReadableGap: CGFloat = 12

  static func resolve(
    text: String = defaultSampleText,
    preferredWidth: Double,
    preferredHeight: Double,
    notchSize: CGSize,
    appearance: OverlayAppearance
  ) -> ResolvedLayout {
    let actualWidth = NotchWindowController.resolvedPanelWidth(preferredWidth)
    let actualHeight = NotchWindowController.resolvedPanelHeight(
      preferredHeight,
      notchHeight: notchSize.height,
      appearance: appearance
    )
    let scale = min(maximumPreviewWidth / actualWidth, maximumPreviewHeight / actualHeight, 1)
    let resolvedNotchSize = CGSize(width: notchSize.width * scale, height: notchSize.height * scale)
    let resolvedHeight = actualHeight * scale

    return ResolvedLayout(
      width: actualWidth * scale,
      height: resolvedHeight,
      topPadding: textTopPadding(
        notchSize: resolvedNotchSize, appearance: appearance, scale: scale),
      notchSize: resolvedNotchSize
    )
  }

  static func textTopPadding(
    notchSize: CGSize,
    appearance: OverlayAppearance,
    scale: CGFloat
  ) -> CGFloat {
    let fontClearance = max(minimumReadableGap, appearance.fontSize * 0.35) * scale
    return notchSize.height + fontClearance
  }
}
