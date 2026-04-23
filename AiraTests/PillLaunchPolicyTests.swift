import Foundation
import Testing

@testable import Aira

struct PillLaunchPolicyTests {
  @Test func launchPlansSkipEmptyManualPillScripts() {
    let currentScript = makePillPolicyScript(title: "Current", body: "Opening line")
    let emptyManualScript = makePillPolicyScript(title: "Empty Manual", body: " \n\t ")

    let plans = PillLaunchPolicy.resolvedLaunchPlans(
      for: [.voiceSync, .manual(scriptId: emptyManualScript.id)],
      fallbackScript: currentScript,
      loadScript: { id in
        id == emptyManualScript.id ? emptyManualScript : nil
      }
    )

    #expect(plans.count == 1)
    #expect(plans.first?.mode == .voiceSync)
    #expect(plans.first?.script.id == currentScript.id)
  }

  @Test func launchPlansSkipMirroredPillsWhenFallbackScriptIsEmpty() {
    let emptyCurrentScript = makePillPolicyScript(title: "Current", body: "")

    let plans = PillLaunchPolicy.resolvedLaunchPlans(
      for: [.voiceSync],
      fallbackScript: emptyCurrentScript,
      loadScript: { _ in nil }
    )

    #expect(plans.isEmpty)
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
