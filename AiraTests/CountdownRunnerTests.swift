import Testing
@testable import Aira

struct CountdownRunnerTests {
    @Test @MainActor func countdownFiresEachTickAndCompletes() async {
        var ticks: [Int] = []
        var completionCount = 0

        await CountdownRunner.run(
            duration: 3,
            sleep: {},
            onTick: { ticks.append($0) },
            onComplete: { completionCount += 1 }
        )

        #expect(ticks == [3, 2, 1])
        #expect(completionCount == 1)
    }

    @Test @MainActor func countdownEmitsCompletionAtZero() async {
        var didComplete = false

        await CountdownRunner.run(
            duration: 1,
            sleep: {},
            onTick: { _ in },
            onComplete: { didComplete = true }
        )

        #expect(didComplete)
    }

    @Test @MainActor func zeroDurationSkipsTicksAndCompletesImmediately() async {
        var ticks: [Int] = []
        var completionCount = 0

        await CountdownRunner.run(
            duration: 0,
            sleep: {},
            onTick: { ticks.append($0) },
            onComplete: { completionCount += 1 }
        )

        #expect(ticks.isEmpty)
        #expect(completionCount == 1)
    }
}
