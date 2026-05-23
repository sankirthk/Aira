import Foundation
import Testing

@testable import Aira

struct ScriptEditorSessionLogicTests {

  @Test func launchMenuItemsExposeSplitButtonChoicesInOrder() {
    #expect(
      ScriptEditorLaunchMenuAction.defaultItems.map(\.title) == [
        "Cast with Pill Windows"
      ])
  }

  @Test func satelliteLaunchPanelUsesOneSectionPerEnabledSatellite() {
    let oneSatellite = ScriptEditorSatelliteLaunchPanelState.make(enabledSatelliteCount: 1)
    #expect(oneSatellite.sections.map(\.title) == ["Pill Window 1"])
    #expect(oneSatellite.sections.allSatisfy { $0.choice == .mirrorCurrentScript })

    let twoSatellites = ScriptEditorSatelliteLaunchPanelState.make(enabledSatelliteCount: 2)
    #expect(twoSatellites.sections.map(\.title) == ["Pill Window 1", "Pill Window 2"])
    #expect(twoSatellites.sections.allSatisfy { $0.choice == .mirrorCurrentScript })
  }

  @Test func satelliteLaunchPanelChoicesAreMirrorOrManual() {
    #expect(
      ScriptEditorSatelliteLaunchChoice.allCases.map(\.title) == [
        "Mirror current script",
        "Manual",
      ])
  }

  @Test func satelliteLaunchPanelMapsMirrorChoiceToSynchronizedSatelliteMode() {
    let state = ScriptEditorSatelliteLaunchPanelState.make(enabledSatelliteCount: 1)

    #expect(state.pillModes() == [.voiceSync])
  }

  @Test func satelliteLaunchPanelMapsManualChoiceToSelectedScriptMode() {
    let scriptID = UUID()
    var state = ScriptEditorSatelliteLaunchPanelState.make(enabledSatelliteCount: 1)
    state.sections[0].choice = .manual
    state.sections[0].selectedManualScriptID = scriptID

    #expect(state.pillModes() == [.manual(scriptId: scriptID)])
  }

  @Test func twoSatelliteLaunchPanelPreservesIndependentMixedModesInSlotOrder() {
    let manualScriptID = UUID()
    var state = ScriptEditorSatelliteLaunchPanelState.make(enabledSatelliteCount: 2)
    state.sections[0].choice = .mirrorCurrentScript
    state.sections[1].choice = .manual
    state.sections[1].selectedManualScriptID = manualScriptID

    #expect(
      state.pillModes() == [
        .voiceSync,
        .manual(scriptId: manualScriptID),
      ]
    )
  }

  @Test func satelliteLaunchRequestSkipsInvalidManualSectionsAndKeepsValidOrder() {
    let validManualID = UUID()
    let invalidManualID = UUID()
    let scripts = [
      ScriptMeta(
        id: validManualID,
        title: "Valid Manual",
        lastEdited: Date(timeIntervalSince1970: 20),
        wordCount: 80,
        starred: false
      ),
      ScriptMeta(
        id: invalidManualID,
        title: "Empty Manual",
        lastEdited: Date(timeIntervalSince1970: 10),
        wordCount: 0,
        starred: false
      ),
    ]
    var state = ScriptEditorSatelliteLaunchPanelState.make(enabledSatelliteCount: 2)
    state.sections[0].choice = .manual
    state.sections[0].selectedManualScriptID = invalidManualID
    state.sections[1].choice = .manual
    state.sections[1].selectedManualScriptID = validManualID

    let request = state.launchRequest(scripts: scripts)

    #expect(request.requestedSatelliteCount == 2)
    #expect(
      request.satelliteSelections == [
        SatelliteLaunchSelection(slotIndex: 2, mode: .manual(scriptId: validManualID))
      ]
    )
    #expect(request.pillModes == [.manual(scriptId: validManualID)])
    #expect(request.skippedDueToEmptyScript == 1)
  }

  @Test func satelliteLaunchRequestReportsSkippedSatelliteFeedback() {
    let emptyScriptID = UUID()
    let scripts = [
      ScriptMeta(
        id: emptyScriptID,
        title: "Empty Script",
        lastEdited: Date(timeIntervalSince1970: 10),
        wordCount: 0,
        starred: false
      )
    ]
    var state = ScriptEditorSatelliteLaunchPanelState.make(enabledSatelliteCount: 2)
    state.sections[0].choice = .mirrorCurrentScript
    state.sections[1].choice = .manual
    state.sections[1].selectedManualScriptID = emptyScriptID

    let request = state.launchRequest(scripts: scripts)

    #expect(request.skippedDueToEmptyScript == 1)
    #expect(
      request.skippedSatelliteFeedbackMessage
        == "1 Pill Window will be skipped because the selected script is empty."
    )
  }

  @Test func satelliteLaunchRequestNoWarningWhenNoScriptSelected() {
    var state = ScriptEditorSatelliteLaunchPanelState.make(enabledSatelliteCount: 2)
    state.sections[0].choice = .mirrorCurrentScript
    state.sections[1].choice = .manual
    // No selectedManualScriptID set — user hasn't picked a script yet

    let request = state.launchRequest(scripts: [])

    #expect(request.skippedDueToEmptyScript == 0)
    #expect(request.skippedSatelliteFeedbackMessage == nil)
  }

  @Test func satelliteLaunchPanelManualScriptDropdownTitleReflectsSelection() {
    let selectedID = UUID()
    let scripts = [
      ScriptMeta(
        id: UUID(),
        title: "Quarterly Review",
        lastEdited: Date(timeIntervalSince1970: 10),
        wordCount: 120,
        starred: false
      ),
      ScriptMeta(
        id: selectedID,
        title: "Launch Talk",
        lastEdited: Date(timeIntervalSince1970: 20),
        wordCount: 80,
        starred: true
      ),
    ]
    var section = ScriptEditorSatelliteLaunchSection(slotIndex: 1, choice: .manual)

    #expect(
      ScriptEditorSatelliteLaunchPanelState.manualScriptDropdownTitle(
        for: section, scripts: scripts) == "Select script")

    section.selectedManualScriptID = selectedID

    #expect(
      ScriptEditorSatelliteLaunchPanelState.manualScriptDropdownTitle(
        for: section, scripts: scripts) == "Launch Talk")
  }

  @Test func satelliteLaunchPanelManualScriptRowsUseFullWidthPointingHandTargets() {
    #expect(ScriptEditorSatelliteLaunchPanelState.manualScriptRowAffordance.usesFullWidthHitArea)
    #expect(ScriptEditorSatelliteLaunchPanelState.manualScriptRowAffordance.usesPointingHandCursor)
  }

  @Test func satelliteLaunchPanelChoiceButtonsUseFullWidthPointingHandTargets() {
    #expect(ScriptEditorSatelliteLaunchPanelState.choiceButtonAffordance.usesFullWidthHitArea)
    #expect(ScriptEditorSatelliteLaunchPanelState.choiceButtonAffordance.usesPointingHandCursor)
  }

  @Test func satelliteLaunchPanelPointingHandUsesHoverCursorTracking() {
    #expect(ScriptEditorSatelliteLaunchPanelState.choiceButtonAffordance.usesHoverCursorTracking)
    #expect(ScriptEditorSatelliteLaunchPanelState.manualScriptRowAffordance.usesHoverCursorTracking)
  }

  @Test func launchUIBlocksUnderlyingEditorInteraction() {
    #expect(
      !ScriptEditorPresentationState.blocksEditorInteraction(
        isLaunchMenuPresented: false,
        isSatelliteLaunchPanelPresented: false
      )
    )
    #expect(
      ScriptEditorPresentationState.blocksEditorInteraction(
        isLaunchMenuPresented: true,
        isSatelliteLaunchPanelPresented: false
      )
    )
    #expect(
      ScriptEditorPresentationState.blocksEditorInteraction(
        isLaunchMenuPresented: false,
        isSatelliteLaunchPanelPresented: true
      )
    )
  }

  @Test func satelliteLaunchPanelClampsToSettingsOwnedSatelliteLimit() {
    let belowMinimum = ScriptEditorSatelliteLaunchPanelState.make(enabledSatelliteCount: 0)
    #expect(belowMinimum.sections.map(\.title) == ["Pill Window 1"])

    let aboveMaximum = ScriptEditorSatelliteLaunchPanelState.make(enabledSatelliteCount: 3)
    #expect(aboveMaximum.sections.map(\.title) == ["Pill Window 1", "Pill Window 2"])
  }

  @Test func emptyOrWhitespaceScriptCannotStartPresenterSession() {
    #expect(!ScriptEditorSessionLogic.canStartPresenterSession(withBody: ""))
    #expect(!ScriptEditorSessionLogic.canStartPresenterSession(withBody: " \n\t "))
    #expect(ScriptEditorSessionLogic.canStartPresenterSession(withBody: "Opening line"))
  }

  @Test func emptyUntitledDraftIsDiscardedOnDismiss() {
    let draft = Script(
      id: UUID(),
      title: "Untitled Script",
      body: "",
      cues: [],
      collectionIds: [],
      createdAt: Date(),
      lastEdited: Date()
    )

    let disposition = ScriptEditorSessionLogic.dismissDisposition(for: draft, persistedScript: nil)

    #expect(disposition == .discardDraft)
  }

  @Test func bodyEditedDraftIsSavedOnDismiss() {
    let draft = Script(
      id: UUID(),
      title: "Untitled Script",
      body: "Opening line",
      cues: [],
      collectionIds: [],
      createdAt: Date(),
      lastEdited: Date()
    )

    let disposition = ScriptEditorSessionLogic.dismissDisposition(for: draft, persistedScript: nil)

    #expect(disposition == .save)
  }

  @Test func retitledDraftIsSavedOnDismiss() {
    let draft = Script(
      id: UUID(),
      title: "Keynote Intro",
      body: "",
      cues: [],
      collectionIds: [],
      createdAt: Date(),
      lastEdited: Date()
    )

    let disposition = ScriptEditorSessionLogic.dismissDisposition(for: draft, persistedScript: nil)

    #expect(disposition == .save)
  }

  @Test func unchangedExistingScriptClosesWithoutSaving() {
    let persisted = Script(
      id: UUID(),
      title: "Weekly Update",
      body: "Status text",
      cues: [],
      collectionIds: [],
      createdAt: Date(),
      lastEdited: Date()
    )

    let disposition = ScriptEditorSessionLogic.dismissDisposition(
      for: persisted, persistedScript: persisted)

    #expect(disposition == .closeWithoutSaving)
  }

  @Test func whitespaceOnlyDraftBodyIsDiscardedOnDismiss() {
    let draft = Script(
      id: UUID(),
      title: "Untitled Script",
      body: " \n\t ",
      cues: [],
      collectionIds: [],
      createdAt: Date(),
      lastEdited: Date()
    )

    let disposition = ScriptEditorSessionLogic.dismissDisposition(for: draft, persistedScript: nil)

    #expect(disposition == .discardDraft)
  }

  @Test func existingScriptWithTitleChangeSavesOnDismiss() {
    let persisted = Script(
      id: UUID(),
      title: "Weekly Update",
      body: "Status text",
      cues: [],
      collectionIds: [],
      createdAt: Date(),
      lastEdited: Date()
    )
    var edited = persisted
    edited.title = "Weekly Wrap-Up"

    let disposition = ScriptEditorSessionLogic.dismissDisposition(
      for: edited, persistedScript: persisted)

    #expect(disposition == .save)
  }

  @Test func existingScriptWithBodyChangeSavesOnDismiss() {
    let persisted = Script(
      id: UUID(),
      title: "Weekly Update",
      body: "Status text",
      cues: [],
      collectionIds: [],
      createdAt: Date(),
      lastEdited: Date()
    )
    var edited = persisted
    edited.body = "Status text with changes"

    let disposition = ScriptEditorSessionLogic.dismissDisposition(
      for: edited, persistedScript: persisted)

    #expect(disposition == .save)
  }

  @Test func existingScriptWithOnlyCueChangesClosesWithoutSaving() {
    let persisted = Script(
      id: UUID(),
      title: "Weekly Update",
      body: "Status text",
      cues: [],
      collectionIds: [],
      createdAt: Date(),
      lastEdited: Date()
    )
    var edited = persisted
    edited.cues = [ScriptCue(type: "Pause 2s", position: 5)]

    let disposition = ScriptEditorSessionLogic.dismissDisposition(
      for: edited, persistedScript: persisted)

    #expect(disposition == .closeWithoutSaving)
  }
}
