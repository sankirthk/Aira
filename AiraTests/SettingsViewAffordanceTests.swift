import CoreGraphics
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

  @Test func managerModeContainersShareLayoutGeometry() {
    #expect(ManagerLayoutParity.contentAreaCornerRadius == 28)
    #expect(ManagerLayoutParity.documentLibraryOuterPadding == 20)
    #expect(ManagerLayoutParity.documentLibraryHeaderHeight == 44)
    #expect(ManagerLayoutParity.documentLibraryGridPadding == 20)
    #expect(ManagerLayoutParity.scriptEditorRootCornerRadius == 18)
    #expect(ManagerLayoutParity.scriptEditorPanelCornerRadius == 12)
    #expect(ManagerLayoutParity.scriptEditorPanelPadding == 32)
    #expect(ManagerLayoutParity.scriptEditorHeaderPadding == 16)
    #expect(ManagerLayoutParity.toolbarButtonCornerRadius == 10)
    #expect(ManagerLayoutParity.toolbarButtonHeight == 38)
  }

  @Test func classicScriptEditorLaunchButtonMatchesToolbarTreatment() {
    #expect(ScriptEditorLaunchButtonAffordances.classicUsesSharedToolbarHeight)
    #expect(ScriptEditorLaunchButtonAffordances.classicUsesSharedToolbarCornerRadius)
    #expect(ScriptEditorLaunchButtonAffordances.classicUsesOutlinedToolbarTreatment)
    #expect(ScriptEditorLaunchButtonAffordances.classicPreservesTerracottaFillAndWhiteText)
    #expect(ScriptEditorLaunchButtonAffordances.liquidGlassKeepsProminentLaunchTreatment)
  }

  @Test func scriptCardActionButtonsUseRoundedRectangles() {
    #expect(ScriptCardActionButtonAffordances.cornerRadius == 8)
    #expect(ScriptCardActionButtonAffordances.editUsesRoundedRectangle)
    #expect(ScriptCardActionButtonAffordances.castUsesRoundedRectangle)
  }

  @Test func classicDarkPreferencesChromeUsesOneGreenSurface() {
    #expect(SettingsChromePalette.classicDarkSurfaceHex == "#465649")
  }

  @Test func liquidGlassPreferencesChromeUsesFrostedParentSurface() {
    #expect(SettingsChromePalette.liquidGlassDarkSurfaceHex == "#253D2E")
    #expect(SettingsChromePalette.liquidGlassLightSurfaceHex == "#849688")
    #expect(SettingsChromePalette.liquidGlassParentSurfaceOpacity < 1)
    #expect(SettingsChromePalette.liquidGlassParentSurfaceOpacity <= 0.1)
    #expect(SettingsChromePalette.liquidGlassTitlebarSurfaceOpacity < 0.5)
    #expect(SettingsChromePalette.liquidGlassPanelTintOpacity <= 0.2)
  }

  @Test func preferencesWindowKeepsModeSwitchLayoutGeometryStable() {
    #expect(SettingsLayoutParity.sectionSpacing == 16)
    #expect(SettingsLayoutParity.panelPadding == 20)
    #expect(SettingsLayoutParity.panelCornerRadius == 20)
    #expect(SettingsLayoutParity.sectionTitleHeight == 34)
    #expect(SettingsLayoutParity.sectionDescriptionHeight == 40)
    #expect(SettingsLayoutParity.appearanceThemeCardHeight == 160)
    #expect(SettingsLayoutParity.managerInterfaceCardHeight == 92)
    #expect(SettingsLayoutParity.typographyControlHeight == 46)
  }

  @Test func managerInterfaceStyleSelectorUsesPlainSettingsSelection() {
    #expect(!SettingsSelectionAffordances.managerInterfaceStyleUsesNativeProminentGlass)
    #expect(SettingsSelectionAffordances.managerInterfaceStyleOuterSpacing == 0)
    #expect(SettingsSelectionAffordances.managerInterfaceStyleSelectedTextUsesWhite)
  }
}
