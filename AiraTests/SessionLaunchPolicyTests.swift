import Testing

@testable import Aira

struct SessionLaunchPolicyTests {
  @Test func zeroCountdownDefersVoiceStartupUntilAfterFirstRenderTurn() {
    #expect(PrompterVoiceStartupPolicy.shouldDeferVoiceStartup(countdownDuration: 0))
  }

  @Test func positiveCountdownDoesNotNeedExtraVoiceStartupDeferral() {
    #expect(!PrompterVoiceStartupPolicy.shouldDeferVoiceStartup(countdownDuration: 3))
  }
}
