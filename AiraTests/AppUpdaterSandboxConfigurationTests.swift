import Foundation
import Testing

@testable import Aira

struct AppUpdaterSandboxConfigurationTests {
  @Test func sparkleSandboxConfigurationIsPresent() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let entitlementsURL = repositoryRoot.appendingPathComponent("Aira/Aira.entitlements")
    let infoPlistURL = repositoryRoot.appendingPathComponent("Aira/Info.plist")

    let entitlementsData = try Data(contentsOf: entitlementsURL)
    let entitlementsObject = try PropertyListSerialization.propertyList(
      from: entitlementsData,
      options: [],
      format: nil
    )
    let entitlements = try #require(entitlementsObject as? [String: Any])

    #expect(entitlements["com.apple.security.app-sandbox"] as? Bool == true)
    #expect(entitlements["com.apple.security.network.client"] as? Bool == true)
    #expect(entitlements["com.apple.security.device.audio-input"] as? Bool == true)
    #expect(entitlements["com.apple.security.files.user-selected.read-write"] as? Bool == true)

    let machLookupNames = try #require(
      entitlements["com.apple.security.temporary-exception.mach-lookup.global-name"] as? [String]
    )
    #expect(machLookupNames.contains("$(PRODUCT_BUNDLE_IDENTIFIER)-spks"))
    #expect(machLookupNames.contains("$(PRODUCT_BUNDLE_IDENTIFIER)-spki"))

    let infoPlistData = try Data(contentsOf: infoPlistURL)
    let infoPlistObject = try PropertyListSerialization.propertyList(
      from: infoPlistData,
      options: [],
      format: nil
    )
    let infoPlist = try #require(infoPlistObject as? [String: Any])
    #expect(infoPlist["AiraDistributionChannel"] as? String == "direct")
    #expect(infoPlist["SUEnableInstallerLauncherService"] as? Bool == true)
  }

  @Test func appStoreSandboxConfigurationOmitsSparkleWiring() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let entitlementsURL = repositoryRoot.appendingPathComponent("Aira/AiraAppStore.entitlements")
    let infoPlistURL = repositoryRoot.appendingPathComponent("Aira/Info-AppStore.plist")

    let entitlementsData = try Data(contentsOf: entitlementsURL)
    let entitlementsObject = try PropertyListSerialization.propertyList(
      from: entitlementsData,
      options: [],
      format: nil
    )
    let entitlements = try #require(entitlementsObject as? [String: Any])

    #expect(entitlements["com.apple.security.app-sandbox"] as? Bool == true)
    #expect(entitlements["com.apple.security.device.audio-input"] as? Bool == true)
    #expect(entitlements["com.apple.security.files.user-selected.read-write"] as? Bool == true)
    #expect(entitlements["com.apple.security.network.client"] == nil)
    #expect(entitlements["com.apple.security.temporary-exception.mach-lookup.global-name"] == nil)

    let infoPlistData = try Data(contentsOf: infoPlistURL)
    let infoPlistObject = try PropertyListSerialization.propertyList(
      from: infoPlistData,
      options: [],
      format: nil
    )
    let infoPlist = try #require(infoPlistObject as? [String: Any])

    #expect(infoPlist["AiraDistributionChannel"] as? String == "app-store")
    #expect(infoPlist["SUEnableInstallerLauncherService"] == nil)
    #expect(infoPlist["SUFeedURL"] == nil)
    #expect(infoPlist["SUPublicEDKey"] == nil)
  }
}
