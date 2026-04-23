import Foundation
import Testing

@testable import Aira

struct AiraMessagePopupContentTests {
  @Test func emptyScriptLaunchMessageUsesBrandedCopy() {
    let content = AiraMessagePopupContent.emptyScriptLaunchError

    #expect(content.eyebrow == "Cast paused")
    #expect(content.title == "Add script text first")
    #expect(content.message == "Write or paste a few words before casting to the notch.")
    #expect(content.primaryActionTitle == "OK")
  }
}
