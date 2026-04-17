import Foundation
import Testing

@testable import Aira

struct MoodPresetTests {
  @Test func dayAndNightProduceValidOverlayAppearanceValues() {
    for preset in MoodPreset.all {
      #expect(preset.name.isEmpty == false)
      #expect(preset.appearance.backgroundColor.hasPrefix("#"))
      #expect(preset.appearance.textColor.hasPrefix("#"))
      #expect((0...1).contains(preset.appearance.opacity))
      #expect(preset.appearance.fontName.isEmpty == false)
      #expect(preset.appearance.fontSize > CGFloat(0))
    }
  }
}
