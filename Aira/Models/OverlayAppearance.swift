import Foundation

struct OverlayAppearance: Codable, Equatable {
  var textColor: String  // hex, e.g. "#F5F2EC"
  var backgroundColor: String  // hex, e.g. "#849688"
  var opacity: Double  // 0.2–1.0; applies to background only
  var fontName: String  // "CrimsonText-Regular", "Manrope-Bold", "Inter-Regular"
  var fontSize: CGFloat  // 14–32

  static let `default` = OverlayAppearance(
    textColor: "#F5F2EC",
    backgroundColor: "#849688",
    opacity: 0.75,
    fontName: "CrimsonText-Regular",
    fontSize: 20
  )
}
