import Foundation
import Testing
@testable import Aira

struct AppUpdaterConfigurationTests {
    @Test func updaterRequiresValidFeedURLAndSigningKey() {
        let configured = AppUpdaterConfiguration(
            feedURLString: "https://example.com/appcast.xml",
            publicEDKey: "abc123"
        )
        #expect(configured.isConfigured)
        #expect(configured.feedURL?.absoluteString == "https://example.com/appcast.xml")

        let missingKey = AppUpdaterConfiguration(
            feedURLString: "https://example.com/appcast.xml",
            publicEDKey: "   "
        )
        #expect(missingKey.isConfigured == false)

        let invalidURL = AppUpdaterConfiguration(
            feedURLString: "not a url",
            publicEDKey: "abc123"
        )
        #expect(invalidURL.isConfigured == false)
    }
}
