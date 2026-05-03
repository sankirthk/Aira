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
        fontName: "OpenDyslexic-Regular",
        fontSize: 24,
        textAlignment: .justified,
        lineSpacing: 12,
        letterSpacing: 1.2,
        wordSpacing: 4,
        textShadow: 3,
        contentPadding: 22
      ),
      notchWindowWidth: 420,
      notchWindowHeight: 210,
      countdownDuration: 5,
      voiceSyncEnabled: false,
      pauseOnHoverEnabled: false,
      speechSensitivity: .high,
      autoScrollWPM: 150,
      screenCaptureExclusionEnabled: false,
      appearanceMode: .dark,
      managerTypography: .large,
      liveAnswerDisclosureAccepted: true,
      hasCompletedInitialPermissionPrompt: true,
      maxPillCount: 2,
      satelliteAppearances: [
        nil,
        OverlayAppearance(
          textColor: "#F6E7C8",
          backgroundColor: "#456789",
          opacity: 0.71,
          fontName: "Inter-Regular",
          fontSize: 21,
          textAlignment: .center,
          lineSpacing: 9,
          letterSpacing: 0.6,
          wordSpacing: 2,
          textShadow: 1.5,
          contentPadding: 19
        ),
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
        fontSize: 18,
        textAlignment: .justified,
        lineSpacing: 10,
        letterSpacing: 0.8,
        wordSpacing: 3,
        textShadow: 2,
        contentPadding: 20
      ),
      notchWindowWidth: 440,
      notchWindowHeight: 220,
      countdownDuration: 0,
      voiceSyncEnabled: true,
      pauseOnHoverEnabled: false,
      speechSensitivity: .low,
      autoScrollWPM: 120,
      screenCaptureExclusionEnabled: false,
      appearanceMode: .light,
      managerTypography: .small,
      liveAnswerDisclosureAccepted: false,
      hasCompletedInitialPermissionPrompt: true,
      maxPillCount: 2,
      satelliteAppearances: [
        OverlayAppearance(
          textColor: "#111111",
          backgroundColor: "#778899",
          opacity: 0.81,
          fontName: "Manrope-Bold",
          fontSize: 19,
          textAlignment: .center,
          lineSpacing: 8,
          letterSpacing: 0.5,
          wordSpacing: 1.5,
          textShadow: 1,
          contentPadding: 18
        ),
        nil,
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

    let appearanceData = try JSONEncoder().encode(settings.defaultOverlayAppearance)
    let decodedAppearance = try JSONDecoder().decode(OverlayAppearance.self, from: appearanceData)
    #expect(decodedAppearance == settings.defaultOverlayAppearance)

    let legacyAppearanceJSON = """
      {
        "textColor": "#FFFFFF",
        "backgroundColor": "#000000",
        "opacity": 0.75,
        "fontName": "CrimsonText-Regular",
        "fontSize": 20
      }
      """.data(using: .utf8)!
    let legacyAppearance = try JSONDecoder().decode(
      OverlayAppearance.self, from: legacyAppearanceJSON)
    #expect(legacyAppearance.textAlignment == .left)
    #expect(legacyAppearance.lineSpacing == OverlayLineSpacingConfiguration.default)
    #expect(legacyAppearance.letterSpacing == OverlayLetterSpacingConfiguration.default)
    #expect(legacyAppearance.wordSpacing == OverlayWordSpacingConfiguration.default)
    #expect(legacyAppearance.textShadow == OverlayTextShadowConfiguration.default)
    #expect(legacyAppearance.contentPadding == OverlayContentPaddingConfiguration.default)
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
        "hasCompletedInitialPermissionPrompt": true,
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

  @MainActor @Test func voiceScrollModeDefaultsToWordTrackingAndCodableRoundTrips() throws {
    var settings = AppSettings()
    #expect(settings.voiceScrollMode == .wordTracking)

    settings.voiceScrollMode = .classicScroll
    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

    #expect(decoded.voiceScrollMode == .classicScroll)
  }

  @Test func voiceScrollModesExposeSettingsMenuCopy() {
    #expect(
      VoiceScrollMode.allCases.map(\.settingsTitle) == [
        "Classic", "Sound-based", "Word tracking",
      ])
    #expect(VoiceScrollMode.allCases.allSatisfy { !$0.settingsDescription.isEmpty })
  }

  @Test func voiceScrollModeDecodesLegacyVolumeGatedAsSoundBased() throws {
    let decoded = try JSONDecoder().decode(VoiceScrollMode.self, from: Data(#""volumeGated""#.utf8))

    #expect(decoded == .soundBased)
  }

  @Test func voiceScrollModePoliciesSeparateMicRecognitionAndMotion() {
    #expect(!VoiceScrollMode.classicScroll.usesVoiceDrivenScroll)
    #expect(
      !VoiceScrollMode.classicScroll.usesSpeechRecognition(spokenWordHighlightingEnabled: false))
    #expect(
      VoiceScrollMode.classicScroll.usesSpeechRecognition(spokenWordHighlightingEnabled: true))

    #expect(VoiceScrollMode.soundBased.usesVoiceDrivenScroll)
    #expect(VoiceScrollMode.soundBased.usesSoundBasedMotion)
    #expect(!VoiceScrollMode.soundBased.usesSpeechRecognition(spokenWordHighlightingEnabled: false))
    #expect(VoiceScrollMode.soundBased.usesSpeechRecognition(spokenWordHighlightingEnabled: true))

    #expect(VoiceScrollMode.wordTracking.usesVoiceDrivenScroll)
    #expect(!VoiceScrollMode.wordTracking.usesSoundBasedMotion)
    #expect(
      VoiceScrollMode.wordTracking.usesSpeechRecognition(spokenWordHighlightingEnabled: false))
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
  @Test func maxPillCountPersistsAcrossStoreReinitializationAndDrivesMirrorLaunchCount() throws {
    let suiteName = "AiraSettingsTests.pills.\(UUID().uuidString)"
    let defaults1 = UserDefaults(suiteName: suiteName)!
    defaults1.removePersistentDomain(forName: suiteName)
    defer { defaults1.removePersistentDomain(forName: suiteName) }

    let store1 = SettingsStore(defaults: defaults1)
    var settings = try store1.load()
    settings.maxPillCount = 2
    try store1.save(settings)

    let defaults2 = UserDefaults(suiteName: suiteName)!
    let store2 = SettingsStore(defaults: defaults2)
    let loaded = try store2.load()

    #expect(loaded.maxPillCount == 2)
    #expect(loaded.mirroredSatelliteModes == [.voiceSync, .voiceSync])
  }

  @Test func satelliteAppearanceOverridesFallbackToNotchDefaultsAndPersistIndependently()
    throws
  {
    let suiteName = "AiraSettingsTests.satelliteAppearance.\(UUID().uuidString)"
    let defaults1 = UserDefaults(suiteName: suiteName)!
    defaults1.removePersistentDomain(forName: suiteName)
    defer { defaults1.removePersistentDomain(forName: suiteName) }

    let store1 = SettingsStore(defaults: defaults1)
    var settings = try store1.load()
    settings.defaultOverlayAppearance = OverlayAppearance(
      textColor: "#FAF3E8",
      backgroundColor: "#234567",
      opacity: 0.67,
      fontName: "CrimsonText-Regular",
      fontSize: 22,
      textAlignment: .justified,
      lineSpacing: 11,
      letterSpacing: 0.4,
      wordSpacing: 3,
      textShadow: 2,
      contentPadding: 21
    )
    settings.setSatelliteAppearanceOverride(
      OverlayAppearance(
        textColor: "#101010",
        backgroundColor: "#C0A080",
        opacity: 0.83,
        fontName: "OpenDyslexic-Regular",
        fontSize: 18,
        textAlignment: .center,
        lineSpacing: 7,
        letterSpacing: 0.8,
        wordSpacing: 2,
        textShadow: 1.5,
        contentPadding: 17
      ),
      forSlot: 2
    )
    try store1.save(settings)

    let defaults2 = UserDefaults(suiteName: suiteName)!
    let store2 = SettingsStore(defaults: defaults2)
    let loaded = try store2.load()

    #expect(loaded.satelliteAppearanceOverride(forSlot: 1) == nil)
    #expect(loaded.effectiveSatelliteAppearance(forSlot: 1) == loaded.defaultOverlayAppearance)
    #expect(loaded.satelliteAppearanceOverride(forSlot: 2) != nil)
    #expect(
      loaded.effectiveSatelliteAppearance(forSlot: 2)
        == loaded.satelliteAppearanceOverride(
          forSlot: 2)
    )
  }

  @Test func satelliteAppearanceOverrideMutationTouchesOnlySelectedSlot() {
    var settings = AppSettings()
    let slotTwoAppearance = OverlayAppearance(
      textColor: "#202020",
      backgroundColor: "#7A8B9C",
      opacity: 0.79,
      fontName: "Inter-Regular",
      fontSize: 19,
      textAlignment: .center,
      lineSpacing: 8,
      letterSpacing: 0.5,
      wordSpacing: 2,
      textShadow: 1,
      contentPadding: 18
    )

    settings.setSatelliteAppearanceOverride(slotTwoAppearance, forSlot: 2)

    #expect(settings.satelliteAppearanceOverride(forSlot: 1) == nil)
    #expect(settings.effectiveSatelliteAppearance(forSlot: 1) == settings.defaultOverlayAppearance)
    #expect(settings.satelliteAppearanceOverride(forSlot: 2) == slotTwoAppearance)
    #expect(settings.effectiveSatelliteAppearance(forSlot: 2) == slotTwoAppearance)
  }

  @Test func screenCaptureExclusionSettingPersistsAcrossStoreReinitialization() throws {
    let suiteName = "AiraSettingsTests.capture.\\(UUID().uuidString)"
    let defaults1 = UserDefaults(suiteName: suiteName)!
    defaults1.removePersistentDomain(forName: suiteName)
    defer { defaults1.removePersistentDomain(forName: suiteName) }

    let store1 = SettingsStore(defaults: defaults1)
    var settings = try store1.load()
    settings.screenCaptureExclusionEnabled = false
    settings.pauseOnHoverEnabled = false
    try store1.save(settings)

    let defaults2 = UserDefaults(suiteName: suiteName)!
    let store2 = SettingsStore(defaults: defaults2)
    let loaded = try store2.load()

    #expect(loaded.screenCaptureExclusionEnabled == false)
    #expect(loaded.pauseOnHoverEnabled == false)
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
        "hasCompletedInitialPermissionPrompt": false,
        "maxPillCount": 0,
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

  @MainActor @Test func legacySatelliteBehaviorFieldsAreIgnoredAndStrippedOnSave() throws {
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
        "pillConfigurations": [
          {
            "contentMode": {
              "type": "manual",
              "scriptId": "\(scriptID.uuidString)"
            }
          },
          {
            "contentMode": {
              "type": "voiceSync"
            }
          }
        ],
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
    #expect(decoded.maxPillCount == 2)
    #expect(decoded.mirroredSatelliteModes == [.voiceSync, .voiceSync])

    let encoded = try JSONEncoder().encode(decoded)
    let encodedJSON = String(decoding: encoded, as: UTF8.self)
    #expect(!encodedJSON.contains("\"pillsEnabled\""))
    #expect(!encodedJSON.contains("\"pillConfigurations\""))
    #expect(!encodedJSON.contains("\"pillContentMode\""))
  }

  @Test func appSettingsDefaultsMatchConfiguredCountdownBehavior() {
    let defaults = AppSettings()

    #expect(defaults.countdownDuration == 3)
    #expect(defaults.voiceSyncEnabled)
    #expect(defaults.pauseOnHoverEnabled)
    #expect(defaults.speechSensitivity == .medium)
    #expect(defaults.autoScrollWPM == ManualScrollConfiguration.defaultWPM)
    #expect(defaults.appearanceMode == .system)
    #expect(defaults.managerTypography == .medium)
    #expect(!defaults.hasCompletedInitialPermissionPrompt)
    #expect(defaults.maxPillCount == 1)
    #expect(defaults.satelliteAppearances == AppSettings.defaultSatelliteAppearances)
    #expect(defaults.mirroredSatelliteModes == [.voiceSync])
  }

  @Test func manualScrollConfigurationClampsSupportedWPMRange() {
    #expect(ManualScrollConfiguration.clampedWPM(5) == 10)
    #expect(ManualScrollConfiguration.clampedWPM(50) == 50)
    #expect(ManualScrollConfiguration.clampedWPM(135) == 100)
  }
}
