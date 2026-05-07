import Testing

@testable import Aira

struct SettingsViewAffordanceTests {

  @Test func settingsResetButtonsUseFullVisibleHitTargets() {
    #expect(SettingsControlAffordances.resetButton.usesFullVisibleHitTarget)
    #expect(SettingsControlAffordances.resetButton.usesPointingHandCursor)
  }

  @Test func settingsCustomColorSwatchesFillTheirVisibleTiles() {
    #expect(SettingsControlAffordances.customColorSwatch.usesFullVisibleHitTarget)
    #expect(SettingsControlAffordances.customColorSwatch.fillsVisibleTile)
    #expect(
      SettingsControlAffordances.customColorSwatch.colorSwatchControlKind == .appKitPanelButton)
  }
}
