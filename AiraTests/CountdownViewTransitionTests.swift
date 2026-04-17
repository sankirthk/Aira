import Testing

@testable import Aira

struct CountdownViewTransitionTests {
  @Test func completionSequenceKeepsOverlayVisibleUntilFadeFinishes() {
    let states = CountdownTransitionPlanner.completionSequence(for: 1)

    #expect(states.count == 2)
    #expect(states[0] == CountdownDisplayState(current: 1, overlayOpacity: 0, isVisible: true))
    #expect(states[1] == CountdownDisplayState(current: 1, overlayOpacity: 0, isVisible: false))
  }
}
