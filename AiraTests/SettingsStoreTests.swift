import Foundation
import Testing

@testable import Aira

func makeSettingsStore() -> (SettingsStore, UserDefaults, String) {
  let suiteName = "AiraSettingsTests.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suiteName)!
  defaults.removePersistentDomain(forName: suiteName)
  return (SettingsStore(defaults: defaults), defaults, suiteName)
}

func cleanupSettings(_ defaults: UserDefaults, suiteName: String) {
  defaults.removePersistentDomain(forName: suiteName)
}

struct SettingsStoreTests {

  @Test func loadReturnsDefaultSettingsWhenNothingStored() throws {
    let (store, defaults, suiteName) = makeSettingsStore()
    defer { cleanupSettings(defaults, suiteName: suiteName) }

    #expect(try store.load() == AppSettings())
  }

  @Test func saveFollowedByLoadReturnsSameSettings() throws {
    let (store, defaults, suiteName) = makeSettingsStore()
    defer { cleanupSettings(defaults, suiteName: suiteName) }

    let settings = AppSettings(
      defaultOverlayAppearance: OverlayAppearance(
        textColor: "#111111",
        backgroundColor: "#ABCDEF",
        opacity: 0.62,
        fontName: "Manrope-Bold",
        fontSize: 24
      ),
      notchWindowWidth: 420,
      notchWindowHeight: 210,
      countdownDuration: 5,
      voiceSyncEnabled: false,
      speechSensitivity: .high,
      autoScrollWPM: 150,
      appearanceMode: .dark,
      managerTypography: .large,
      liveAnswerDisclosureAccepted: true,
      pillsEnabled: true,
      maxPillCount: 2,
      pillConfigurations: [
        PillWindowConfiguration(contentMode: .voiceSync),
        PillWindowConfiguration(
          contentMode: .manual(scriptId: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!)),
      ],
      shortcutToggleNotch: "⌘1",
      shortcutTogglePill: "⌘2",
      shortcutToggleVoiceSync: "⌘3",
      shortcutScrollUp: "PageUp",
      shortcutScrollDown: "PageDown",
      shortcutEndSession: "⌘."
    )

    try store.save(settings)

    #expect(try store.load() == settings)
  }

  @MainActor @Test func appSettingsCodableRoundTrip() throws {
    let settings = AppSettings(
      defaultOverlayAppearance: OverlayAppearance(
        textColor: "#222222",
        backgroundColor: "#EEEEEE",
        opacity: 0.88,
        fontName: "IndieFlower",
        fontSize: 18
      ),
      notchWindowWidth: 440,
      notchWindowHeight: 220,
      countdownDuration: 0,
      voiceSyncEnabled: true,
      speechSensitivity: .low,
      autoScrollWPM: 120,
      appearanceMode: .light,
      managerTypography: .small,
      liveAnswerDisclosureAccepted: false,
      pillsEnabled: true,
      maxPillCount: 2,
      pillConfigurations: [
        PillWindowConfiguration(
          contentMode: .manual(scriptId: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!)),
        PillWindowConfiguration(contentMode: .voiceSync),
      ],
      shortcutToggleNotch: "⌘⇧N",
      shortcutTogglePill: "⌘⇧P",
      shortcutToggleVoiceSync: "⌘⇧Space",
      shortcutScrollUp: "↑",
      shortcutScrollDown: "↓",
      shortcutEndSession: "Escape"
    )

    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

    #expect(decoded == settings)
  }

  @MainActor @Test func legacyVoiceModesDecodeAsUnifiedVoice() throws {
    for legacyMode in ["classic", "hybrid", "cinematic", "voice"] {
      let json = """
        {
          "defaultOverlayAppearance": {
            "textColor": "#FFFFFF",
            "backgroundColor": "#000000",
            "opacity": 0.85,
            "fontName": "Inter-Regular",
            "fontSize": 20
          },
          "notchWindowWidth": 400,
          "notchWindowHeight": 164,
          "countdownDuration": 3,
          "voiceSyncEnabled": true,
          "voiceSyncMode": "\(legacyMode)",
          "speechSensitivity": "medium",
          "autoScrollWPM": 135,
          "appearanceMode": "system",
          "managerTypography": "medium",
          "liveAnswerDisclosureAccepted": false,
          "pillsEnabled": false,
          "maxPillCount": 1,
          "pillContentMode": {
            "type": "voiceSync"
          },
          "shortcutToggleNotch": "⌘⇧N",
          "shortcutTogglePill": "⌘⇧P",
          "shortcutToggleVoiceSync": "⌘⇧Space",
          "shortcutScrollUp": "↑",
          "shortcutScrollDown": "↓",
          "shortcutEndSession": "Escape"
        }
        """.data(using: .utf8)!

      let decoded = try JSONDecoder().decode(AppSettings.self, from: json)
      #expect(decoded.voiceSyncMode == .voice)
    }
  }

  @Test func loadCorruptDataThrows() {
    let (store, defaults, suiteName) = makeSettingsStore()
    defer { cleanupSettings(defaults, suiteName: suiteName) }

    defaults.set(Data("not-json".utf8), forKey: "aira.appSettings")

    #expect(throws: SettingsStore.StoreError.corruptData) {
      try store.load()
    }
  }

  // UT-019a — REQ-023
  @Test func textColorMutationPersistsAcrossStoreReinitialization() throws {
    let suiteName = "AiraSettingsTests.textColor.\(UUID().uuidString)"
    let defaults1 = UserDefaults(suiteName: suiteName)!
    defaults1.removePersistentDomain(forName: suiteName)
    defer { defaults1.removePersistentDomain(forName: suiteName) }

    let store1 = SettingsStore(defaults: defaults1)
    var settings = try store1.load()
    settings.defaultOverlayAppearance.textColor = "#D4A574"
    try store1.save(settings)

    let defaults2 = UserDefaults(suiteName: suiteName)!
    let store2 = SettingsStore(defaults: defaults2)
    let loaded = try store2.load()

    #expect(loaded.defaultOverlayAppearance.textColor == "#D4A574")
  }

  // UT-019b — REQ-044
  @Test func pillSettingsPersistAcrossStoreReinitialization() throws {
    let suiteName = "AiraSettingsTests.pills.\(UUID().uuidString)"
    let defaults1 = UserDefaults(suiteName: suiteName)!
    defaults1.removePersistentDomain(forName: suiteName)
    defer { defaults1.removePersistentDomain(forName: suiteName) }

    let store1 = SettingsStore(defaults: defaults1)
    var settings = try store1.load()
    settings.pillsEnabled = true
    settings.maxPillCount = 2
    try store1.save(settings)

    let defaults2 = UserDefaults(suiteName: suiteName)!
    let store2 = SettingsStore(defaults: defaults2)
    let loaded = try store2.load()

    #expect(loaded.pillsEnabled)
    #expect(loaded.maxPillCount == 2)
    #expect(loaded.pillConfigurations.count == PillWindowConfiguration.maximumSlotCount)
  }

  @MainActor @Test func maxPillCountIsNormalizedDuringInitAndDecode() throws {
    let initialized = AppSettings(maxPillCount: 9)
    #expect(initialized.maxPillCount == 2)

    let json = """
      {
        "defaultOverlayAppearance": {
          "textColor": "#FFFFFF",
          "backgroundColor": "#000000",
          "opacity": 0.85,
          "fontName": "Inter-Regular",
          "fontSize": 20
        },
        "notchWindowWidth": 400,
        "notchWindowHeight": 164,
        "countdownDuration": 3,
        "voiceSyncEnabled": true,
        "voiceSyncMode": "voice",
        "speechSensitivity": "medium",
        "autoScrollWPM": 135,
        "appearanceMode": "system",
        "managerTypography": "medium",
        "liveAnswerDisclosureAccepted": false,
        "pillsEnabled": true,
        "maxPillCount": 0,
        "pillConfigurations": [
          { "contentMode": { "type": "voiceSync" } },
          { "contentMode": { "type": "voiceSync" } }
        ],
        "shortcutToggleNotch": "⌘⇧N",
        "shortcutTogglePill": "⌘⇧P",
        "shortcutToggleVoiceSync": "⌘⇧Space",
        "shortcutScrollUp": "↑",
        "shortcutScrollDown": "↓",
        "shortcutEndSession": "Escape"
      }
      """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(AppSettings.self, from: json)
    #expect(decoded.maxPillCount == 1)
  }

  @MainActor @Test func legacySinglePillContentModeMigratesToAllPillSlots() throws {
    let scriptID = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
    let json = """
      {
        "defaultOverlayAppearance": {
          "textColor": "#FFFFFF",
          "backgroundColor": "#000000",
          "opacity": 0.85,
          "fontName": "Inter-Regular",
          "fontSize": 20
        },
        "notchWindowWidth": 400,
        "notchWindowHeight": 164,
        "countdownDuration": 3,
        "voiceSyncEnabled": true,
        "voiceSyncMode": "voice",
        "speechSensitivity": "medium",
        "autoScrollWPM": 135,
        "appearanceMode": "system",
        "managerTypography": "medium",
        "liveAnswerDisclosureAccepted": false,
        "pillsEnabled": true,
        "maxPillCount": 2,
        "pillContentMode": {
          "type": "manual",
          "scriptId": "\(scriptID.uuidString)"
        },
        "shortcutToggleNotch": "⌘⇧N",
        "shortcutTogglePill": "⌘⇧P",
        "shortcutToggleVoiceSync": "⌘⇧Space",
        "shortcutScrollUp": "↑",
        "shortcutScrollDown": "↓",
        "shortcutEndSession": "Escape"
      }
      """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(AppSettings.self, from: json)

    #expect(decoded.pillConfigurations.count == PillWindowConfiguration.maximumSlotCount)
    #expect(decoded.pillContentMode(forSlot: 0) == .manual(scriptId: scriptID))
    #expect(decoded.pillContentMode(forSlot: 1) == .manual(scriptId: scriptID))
  }

  @Test func appSettingsDefaultsMatchConfiguredCountdownBehavior() {
    let defaults = AppSettings()

    #expect(defaults.countdownDuration == 3)
    #expect(defaults.voiceSyncEnabled)
    #expect(defaults.speechSensitivity == .medium)
    #expect(defaults.autoScrollWPM == ManualScrollConfiguration.defaultWPM)
    #expect(defaults.appearanceMode == .system)
    #expect(defaults.managerTypography == .medium)
    #expect(!defaults.pillsEnabled)
    #expect(defaults.maxPillCount == 1)
    #expect(defaults.pillConfigurations == PillWindowConfiguration.defaultSlots)
  }

  @Test func manualScrollConfigurationClampsSupportedWPMRange() {
    #expect(ManualScrollConfiguration.clampedWPM(40) == 100)
    #expect(ManualScrollConfiguration.clampedWPM(135) == 135)
    #expect(ManualScrollConfiguration.clampedWPM(320) == 300)
  }
}
