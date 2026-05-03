import Foundation
import Testing

@testable import Aira

struct PillLaunchPolicyTests {
  @Test func launchPlansSkipEmptyManualPillScripts() {
    let currentScript = makePillPolicyScript(title: "Current", body: "Opening line")
    let emptyManualScript = makePillPolicyScript(title: "Empty Manual", body: " \n\t ")

    let plans = PillLaunchPolicy.resolvedLaunchPlans(
      for: [
        SatelliteLaunchSelection(slotIndex: 1, mode: .voiceSync),
        SatelliteLaunchSelection(slotIndex: 2, mode: .manual(scriptId: emptyManualScript.id)),
      ],
      fallbackScript: currentScript,
      loadScript: { id in
        id == emptyManualScript.id ? emptyManualScript : nil
      }
    )

    #expect(plans.count == 1)
    #expect(plans.first?.slotIndex == 1)
    #expect(plans.first?.mode == .voiceSync)
    #expect(plans.first?.script.id == currentScript.id)
  }

  @Test func launchPlansSkipMirroredPillsWhenFallbackScriptIsEmpty() {
    let emptyCurrentScript = makePillPolicyScript(title: "Current", body: "")

    let plans = PillLaunchPolicy.resolvedLaunchPlans(
      for: [SatelliteLaunchSelection(slotIndex: 1, mode: .voiceSync)],
      fallbackScript: emptyCurrentScript,
      loadScript: { _ in nil }
    )

    #expect(plans.isEmpty)
  }

  @Test func launchPlansPreserveIndependentTwoSatelliteMixedModesInSlotOrder() {
    let currentScript = makePillPolicyScript(title: "Current", body: "Opening line")
    let manualScript = makePillPolicyScript(title: "Manual", body: "Pill Window script")

    let plans = PillLaunchPolicy.resolvedLaunchPlans(
      for: [
        SatelliteLaunchSelection(slotIndex: 1, mode: .voiceSync),
        SatelliteLaunchSelection(slotIndex: 2, mode: .manual(scriptId: manualScript.id)),
      ],
      fallbackScript: currentScript,
      loadScript: { id in
        id == manualScript.id ? manualScript : nil
      }
    )

    #expect(plans.count == 2)
    #expect(plans[0].slotIndex == 1)
    #expect(plans[0].mode == .voiceSync)
    #expect(plans[0].script.id == currentScript.id)
    #expect(plans[1].slotIndex == 2)
    #expect(plans[1].mode == .manual(scriptId: manualScript.id))
    #expect(plans[1].script.id == manualScript.id)
  }

  @Test func launchPlansSkipManualPillsWhenSelectedScriptCannotBeLoaded() {
    let currentScript = makePillPolicyScript(title: "Current", body: "Opening line")

    let plans = PillLaunchPolicy.resolvedLaunchPlans(
      for: [
        SatelliteLaunchSelection(slotIndex: 1, mode: .voiceSync),
        SatelliteLaunchSelection(slotIndex: 2, mode: .manual(scriptId: UUID())),
      ],
      fallbackScript: currentScript,
      loadScript: { _ in nil }
    )

    #expect(plans.count == 1)
    #expect(plans[0].slotIndex == 1)
    #expect(plans[0].mode == .voiceSync)
    #expect(plans[0].script.id == currentScript.id)
  }
}

private func makePillPolicyScript(title: String, body: String) -> Script {
  Script(
    id: UUID(),
    title: title,
    body: body,
    cues: [],
    collectionIds: [],
    createdAt: Date(),
    lastEdited: Date()
  )
}
