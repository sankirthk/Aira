import AppKit
import SwiftUI

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)

    let red = Double((int >> 16) & 0xFF) / 255
    let green = Double((int >> 8) & 0xFF) / 255
    let blue = Double(int & 0xFF) / 255

    self.init(red: red, green: green, blue: blue)
  }

  var readableTextColor: Color {
    guard let srgb = NSColor(self).usingColorSpace(.sRGB) else {
      return .white
    }

    func linearized(_ component: CGFloat) -> CGFloat {
      component <= 0.03928
        ? component / 12.92
        : pow((component + 0.055) / 1.055, 2.4)
    }

    let red = linearized(srgb.redComponent)
    let green = linearized(srgb.greenComponent)
    let blue = linearized(srgb.blueComponent)
    let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    let blackContrast = (luminance + 0.05) / 0.05
    let whiteContrast = 1.05 / (luminance + 0.05)

    return blackContrast >= whiteContrast ? .black : .white
  }
}
