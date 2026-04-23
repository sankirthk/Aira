import Testing

@testable import Aira

@MainActor
struct SessionLaunchTraceTests {
  @Test func recordsMarksInOrder() {
    let trace = SessionLaunchTrace(label: "test")

    trace.mark("start")
    trace.mark("ordered-front")

    let names = trace.snapshot().map(\.name)
    #expect(names == ["start", "ordered-front"])
  }

  @Test func elapsedMillisecondsNeverGoBackward() {
    let trace = SessionLaunchTrace(label: "test")

    trace.mark("start")
    trace.mark("middle")
    trace.mark("end")

    let marks = trace.snapshot()
    #expect(marks[0].elapsedMilliseconds <= marks[1].elapsedMilliseconds)
    #expect(marks[1].elapsedMilliseconds <= marks[2].elapsedMilliseconds)
  }
}
