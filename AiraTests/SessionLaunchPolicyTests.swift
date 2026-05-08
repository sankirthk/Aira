import Foundation
import Testing

@testable import Aira

struct SessionLaunchPolicyTests {
  @Test func overlayLaunchIntentModelsNotchMirroredAndAssignedSatellitePathsExplicitly() {
    let manualID = UUID()
    let assignedSelections = [
      SatelliteLaunchSelection(slotIndex: 1, mode: .voiceSync),
      SatelliteLaunchSelection(slotIndex: 2, mode: .manual(scriptId: manualID)),
    ]

    #expect(OverlaySessionLaunchIntent.notchOnly.satelliteSelections == [])
    #expect(
      OverlaySessionLaunchIntent.mirroredSatellites(count: 2).satelliteSelections == [
        SatelliteLaunchSelection(slotIndex: 1, mode: .voiceSync),
        SatelliteLaunchSelection(slotIndex: 2, mode: .voiceSync),
      ]
    )
    #expect(
      OverlaySessionLaunchIntent.assignedSatellites(assignedSelections).satelliteSelections
        == assignedSelections
    )
  }

  @Test func zeroCountdownDefersVoiceStartupUntilAfterFirstRenderTurn() {
    #expect(PrompterVoiceStartupPolicy.shouldDeferVoiceStartup(countdownDuration: 0))
  }

  @Test func activePrompterRefreshStartsRequiredVoiceSubsystem() {
    #expect(
      PrompterVoiceStartupPolicy.shouldStartVoiceSubsystemOnAppear(
        sessionStarted: true,
        requiresVoiceSubsystem: true
      )
    )
    #expect(
      !PrompterVoiceStartupPolicy.shouldStartVoiceSubsystemOnAppear(
        sessionStarted: false,
        requiresVoiceSubsystem: true
      )
    )
    #expect(
      !PrompterVoiceStartupPolicy.shouldStartVoiceSubsystemOnAppear(
        sessionStarted: true,
        requiresVoiceSubsystem: false
      )
    )
  }

  @Test func positiveCountdownDoesNotNeedExtraVoiceStartupDeferral() {
    #expect(!PrompterVoiceStartupPolicy.shouldDeferVoiceStartup(countdownDuration: 3))
  }
}
