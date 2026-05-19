import Foundation

enum ManualScrollConfiguration {
  static let minimumWPM: Double = 10
  static let maximumWPM: Double = 30
  static let defaultWPM: Double = 10

  static func clampedWPM(_ value: Double) -> Double {
    min(max(value, minimumWPM), maximumWPM)
  }
}

enum NotchWidthConfiguration {
  static let minimumWidth: Double = 340
  static let maximumWidth: Double = 440
  static let defaultWidth: Double = 380

  static func clampedWidth(_ value: Double) -> Double {
    min(max(value, minimumWidth), maximumWidth)
  }
}

enum NotchHeightConfiguration {
  static let minimumHeight: Double = 148
  static let maximumHeight: Double = 220
  static let defaultHeight: Double = 168

  static func clampedHeight(_ value: Double) -> Double {
    min(max(value, minimumHeight), maximumHeight)
  }
}

struct AppSettings: Codable, Equatable {
  var defaultOverlayAppearance: OverlayAppearance = .default
  var notchWindowWidth: Double = NotchWidthConfiguration.defaultWidth
  var notchWindowHeight: Double = NotchHeightConfiguration.defaultHeight
  var countdownDuration: Int = 3
  var voiceSyncEnabled: Bool = true
  var spokenWordHighlightingEnabled: Bool = false
  var showScriptProgress: Bool = false
  var pauseOnHoverEnabled: Bool = true
  var voiceSyncMode: VoiceSyncMode = .voice
  var voiceScrollMode: VoiceScrollMode = .wordTracking

  var voiceDrivenScrollEnabled: Bool {
    voiceScrollMode.usesVoiceDrivenScroll
  }
  var speechSensitivity: SpeechSensitivity = .medium
  var autoScrollWPM: Double = ManualScrollConfiguration.defaultWPM {
    didSet {
      autoScrollWPM = ManualScrollConfiguration.clampedWPM(autoScrollWPM)
    }
  }
  var screenCaptureExclusionEnabled: Bool = true
  var appearanceMode: AppearanceMode = .system
  var notchFrostedGlassEnabled: Bool = false
  var pillFrostedGlassEnabled: Bool = false
  var managerInterfaceStyle: ManagerInterfaceStyle = .classic
  var managerTypography: ManagerTypography = .medium
  var liveAnswerDisclosureAccepted: Bool = false
  var hasCompletedInitialPermissionPrompt: Bool = false

  // Pill Windows (REQ-009, REQ-044)
  var maxPillCount: Int = 1 {  // 1 or 2
    didSet {
      maxPillCount = Self.normalizedMaxPillCount(maxPillCount)
    }
  }
  var satelliteAppearances: [OverlayAppearance?] = Self.defaultSatelliteAppearances {
    didSet {
      satelliteAppearances = Self.normalizedSatelliteAppearances(from: satelliteAppearances)
    }
  }

  // Keyboard shortcuts stored as display strings; parsed at session start
  var shortcutToggleNotch: String = "⌘⇧N"
  var shortcutTogglePill: String = "⌘⇧P"
  var shortcutToggleVoiceSync: String = "⌘⇧Space"
  var shortcutScrollUp: String = "↑"
  var shortcutScrollDown: String = "↓"
  var shortcutEndSession: String = "Escape"

  init(
    defaultOverlayAppearance: OverlayAppearance = .default,
    notchWindowWidth: Double = NotchWidthConfiguration.defaultWidth,
    notchWindowHeight: Double = NotchHeightConfiguration.defaultHeight,
    countdownDuration: Int = 3,
    voiceSyncEnabled: Bool = true,
    spokenWordHighlightingEnabled: Bool = false,
    showScriptProgress: Bool = false,
    pauseOnHoverEnabled: Bool = true,
    voiceSyncMode: VoiceSyncMode = .voice,
    voiceScrollMode: VoiceScrollMode = .wordTracking,
    speechSensitivity: SpeechSensitivity = .medium,
    autoScrollWPM: Double = ManualScrollConfiguration.defaultWPM,
    screenCaptureExclusionEnabled: Bool = true,
    appearanceMode: AppearanceMode = .system,
    notchFrostedGlassEnabled: Bool = false,
    pillFrostedGlassEnabled: Bool = false,
    managerInterfaceStyle: ManagerInterfaceStyle = .classic,
    managerTypography: ManagerTypography = .medium,
    liveAnswerDisclosureAccepted: Bool = false,
    hasCompletedInitialPermissionPrompt: Bool = false,
    maxPillCount: Int = 1,
    satelliteAppearances: [OverlayAppearance?] = AppSettings.defaultSatelliteAppearances,
    shortcutToggleNotch: String = "⌘⇧N",
    shortcutTogglePill: String = "⌘⇧P",
    shortcutToggleVoiceSync: String = "⌘⇧Space",
    shortcutScrollUp: String = "↑",
    shortcutScrollDown: String = "↓",
    shortcutEndSession: String = "Escape"
  ) {
    self.defaultOverlayAppearance = defaultOverlayAppearance
    self.notchWindowWidth = NotchWidthConfiguration.clampedWidth(notchWindowWidth)
    self.notchWindowHeight = NotchHeightConfiguration.clampedHeight(notchWindowHeight)
    self.countdownDuration = countdownDuration
    self.voiceSyncEnabled = voiceSyncEnabled
    self.spokenWordHighlightingEnabled = spokenWordHighlightingEnabled
    self.showScriptProgress = showScriptProgress
    self.pauseOnHoverEnabled = pauseOnHoverEnabled
    self.voiceSyncMode = voiceSyncMode
    self.voiceScrollMode = voiceScrollMode
    self.speechSensitivity = speechSensitivity
    self.autoScrollWPM = ManualScrollConfiguration.clampedWPM(autoScrollWPM)
    self.screenCaptureExclusionEnabled = screenCaptureExclusionEnabled
    self.appearanceMode = appearanceMode
    self.notchFrostedGlassEnabled = notchFrostedGlassEnabled
    self.pillFrostedGlassEnabled = pillFrostedGlassEnabled
    self.managerInterfaceStyle = managerInterfaceStyle
    self.managerTypography = managerTypography
    self.liveAnswerDisclosureAccepted = liveAnswerDisclosureAccepted
    self.hasCompletedInitialPermissionPrompt = hasCompletedInitialPermissionPrompt
    self.maxPillCount = Self.normalizedMaxPillCount(maxPillCount)
    self.satelliteAppearances = Self.normalizedSatelliteAppearances(from: satelliteAppearances)
    self.shortcutToggleNotch = shortcutToggleNotch
    self.shortcutTogglePill = shortcutTogglePill
    self.shortcutToggleVoiceSync = shortcutToggleVoiceSync
    self.shortcutScrollUp = shortcutScrollUp
    self.shortcutScrollDown = shortcutScrollDown
    self.shortcutEndSession = shortcutEndSession
  }

  var clampedMaxPillCount: Int {
    min(max(maxPillCount, 1), PillWindowConfiguration.maximumSlotCount)
  }

  var mirroredSatelliteModes: [PillContentMode] {
    mirroredSatelliteModes(forRequestedCount: maxPillCount)
  }

  static let defaultSatelliteAppearances = [OverlayAppearance?](
    repeating: nil,
    count: PillWindowConfiguration.maximumSlotCount
  )

  func mirroredSatelliteModes(forRequestedCount count: Int) -> [PillContentMode] {
    let requestedCount = min(max(count, 0), PillWindowConfiguration.maximumSlotCount)
    return Array(repeating: .voiceSync, count: requestedCount)
  }

  func satelliteAppearanceOverride(forSlot slot: Int) -> OverlayAppearance? {
    guard let index = Self.zeroBasedSatelliteSlotIndex(for: slot) else {
      return nil
    }
    return Self.normalizedSatelliteAppearances(from: satelliteAppearances)[index]
  }

  func effectiveSatelliteAppearance(
    forSlot slot: Int,
    fallback: OverlayAppearance? = nil
  ) -> OverlayAppearance {
    satelliteAppearanceOverride(forSlot: slot) ?? fallback ?? defaultOverlayAppearance
  }

  mutating func setSatelliteAppearanceOverride(_ appearance: OverlayAppearance?, forSlot slot: Int)
  {
    guard let index = Self.zeroBasedSatelliteSlotIndex(for: slot) else {
      return
    }

    var normalized = Self.normalizedSatelliteAppearances(from: satelliteAppearances)
    normalized[index] = appearance
    satelliteAppearances = normalized
  }

  static func normalizedSatelliteAppearances(from appearances: [OverlayAppearance?])
    -> [OverlayAppearance?]
  {
    var normalized = Array(appearances.prefix(PillWindowConfiguration.maximumSlotCount))
    while normalized.count < PillWindowConfiguration.maximumSlotCount {
      normalized.append(nil)
    }
    return normalized
  }

  static func normalizedMaxPillCount(_ value: Int) -> Int {
    min(max(value, 1), PillWindowConfiguration.maximumSlotCount)
  }

  private static func zeroBasedSatelliteSlotIndex(for slot: Int) -> Int? {
    let index = slot - 1
    guard (0..<PillWindowConfiguration.maximumSlotCount).contains(index) else {
      return nil
    }
    return index
  }

  private enum CodingKeys: String, CodingKey {
    case defaultOverlayAppearance
    case notchWindowWidth
    case notchWindowHeight
    case countdownDuration
    case voiceSyncEnabled
    case spokenWordHighlightingEnabled
    case showScriptProgress
    case pauseOnHoverEnabled
    case voiceSyncMode
    case voiceScrollMode
    case speechSensitivity
    case autoScrollWPM
    case screenCaptureExclusionEnabled
    case appearanceMode
    case notchFrostedGlassEnabled
    case pillFrostedGlassEnabled
    case managerInterfaceStyle
    case managerTypography
    case liveAnswerDisclosureAccepted
    case hasCompletedInitialPermissionPrompt
    case maxPillCount
    case satelliteAppearances
    case shortcutToggleNotch
    case shortcutTogglePill
    case shortcutToggleVoiceSync
    case shortcutScrollUp
    case shortcutScrollDown
    case shortcutEndSession
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    defaultOverlayAppearance =
      try container.decodeIfPresent(OverlayAppearance.self, forKey: .defaultOverlayAppearance)
      ?? .default
    notchWindowWidth = NotchWidthConfiguration.clampedWidth(
      try container.decodeIfPresent(Double.self, forKey: .notchWindowWidth)
        ?? NotchWidthConfiguration.defaultWidth
    )
    notchWindowHeight = NotchHeightConfiguration.clampedHeight(
      try container.decodeIfPresent(Double.self, forKey: .notchWindowHeight)
        ?? NotchHeightConfiguration.defaultHeight
    )
    countdownDuration = try container.decodeIfPresent(Int.self, forKey: .countdownDuration) ?? 3
    voiceSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .voiceSyncEnabled) ?? true
    spokenWordHighlightingEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .spokenWordHighlightingEnabled) ?? false
    showScriptProgress =
      try container.decodeIfPresent(Bool.self, forKey: .showScriptProgress) ?? false
    pauseOnHoverEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .pauseOnHoverEnabled) ?? true
    voiceSyncMode =
      try container.decodeIfPresent(VoiceSyncMode.self, forKey: .voiceSyncMode) ?? .voice
    voiceScrollMode =
      try container.decodeIfPresent(VoiceScrollMode.self, forKey: .voiceScrollMode)
      ?? .wordTracking
    speechSensitivity =
      try container.decodeIfPresent(SpeechSensitivity.self, forKey: .speechSensitivity) ?? .medium
    autoScrollWPM = ManualScrollConfiguration.clampedWPM(
      try container.decodeIfPresent(Double.self, forKey: .autoScrollWPM)
        ?? ManualScrollConfiguration.defaultWPM
    )
    screenCaptureExclusionEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .screenCaptureExclusionEnabled) ?? true
    appearanceMode =
      try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system
    notchFrostedGlassEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .notchFrostedGlassEnabled) ?? false
    pillFrostedGlassEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .pillFrostedGlassEnabled) ?? false
    managerInterfaceStyle =
      try container.decodeIfPresent(ManagerInterfaceStyle.self, forKey: .managerInterfaceStyle)
      ?? .classic
    managerTypography =
      try container.decodeIfPresent(ManagerTypography.self, forKey: .managerTypography) ?? .medium
    hasCompletedInitialPermissionPrompt =
      try container.decodeIfPresent(Bool.self, forKey: .hasCompletedInitialPermissionPrompt)
      ?? false
    liveAnswerDisclosureAccepted =
      try container.decodeIfPresent(Bool.self, forKey: .liveAnswerDisclosureAccepted) ?? false
    maxPillCount = Self.normalizedMaxPillCount(
      try container.decodeIfPresent(Int.self, forKey: .maxPillCount) ?? 1
    )
    satelliteAppearances = Self.normalizedSatelliteAppearances(
      from: try container.decodeIfPresent([OverlayAppearance?].self, forKey: .satelliteAppearances)
        ?? Self.defaultSatelliteAppearances
    )

    shortcutToggleNotch =
      try container.decodeIfPresent(String.self, forKey: .shortcutToggleNotch) ?? "⌘⇧N"
    shortcutTogglePill =
      try container.decodeIfPresent(String.self, forKey: .shortcutTogglePill) ?? "⌘⇧P"
    shortcutToggleVoiceSync =
      try container.decodeIfPresent(String.self, forKey: .shortcutToggleVoiceSync) ?? "⌘⇧Space"
    shortcutScrollUp = try container.decodeIfPresent(String.self, forKey: .shortcutScrollUp) ?? "↑"
    shortcutScrollDown =
      try container.decodeIfPresent(String.self, forKey: .shortcutScrollDown) ?? "↓"
    shortcutEndSession =
      try container.decodeIfPresent(String.self, forKey: .shortcutEndSession) ?? "Escape"
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(defaultOverlayAppearance, forKey: .defaultOverlayAppearance)
    try container.encode(notchWindowWidth, forKey: .notchWindowWidth)
    try container.encode(notchWindowHeight, forKey: .notchWindowHeight)
    try container.encode(countdownDuration, forKey: .countdownDuration)
    try container.encode(voiceSyncEnabled, forKey: .voiceSyncEnabled)
    try container.encode(spokenWordHighlightingEnabled, forKey: .spokenWordHighlightingEnabled)
    try container.encode(showScriptProgress, forKey: .showScriptProgress)
    try container.encode(pauseOnHoverEnabled, forKey: .pauseOnHoverEnabled)
    try container.encode(voiceSyncMode, forKey: .voiceSyncMode)
    try container.encode(voiceScrollMode, forKey: .voiceScrollMode)
    try container.encode(speechSensitivity, forKey: .speechSensitivity)
    try container.encode(autoScrollWPM, forKey: .autoScrollWPM)
    try container.encode(screenCaptureExclusionEnabled, forKey: .screenCaptureExclusionEnabled)
    try container.encode(appearanceMode, forKey: .appearanceMode)
    try container.encode(notchFrostedGlassEnabled, forKey: .notchFrostedGlassEnabled)
    try container.encode(pillFrostedGlassEnabled, forKey: .pillFrostedGlassEnabled)
    try container.encode(managerInterfaceStyle, forKey: .managerInterfaceStyle)
    try container.encode(managerTypography, forKey: .managerTypography)
    try container.encode(
      hasCompletedInitialPermissionPrompt, forKey: .hasCompletedInitialPermissionPrompt)
    try container.encode(liveAnswerDisclosureAccepted, forKey: .liveAnswerDisclosureAccepted)
    try container.encode(maxPillCount, forKey: .maxPillCount)
    try container.encode(
      Self.normalizedSatelliteAppearances(from: satelliteAppearances),
      forKey: .satelliteAppearances
    )
    try container.encode(shortcutToggleNotch, forKey: .shortcutToggleNotch)
    try container.encode(shortcutTogglePill, forKey: .shortcutTogglePill)
    try container.encode(shortcutToggleVoiceSync, forKey: .shortcutToggleVoiceSync)
    try container.encode(shortcutScrollUp, forKey: .shortcutScrollUp)
    try container.encode(shortcutScrollDown, forKey: .shortcutScrollDown)
    try container.encode(shortcutEndSession, forKey: .shortcutEndSession)
  }
}

struct PillWindowConfiguration {
  static let maximumSlotCount = 2
}

enum SpeechSensitivity: String, Codable, CaseIterable {
  case low, medium, high
}

enum VoiceSyncMode: String, Codable, CaseIterable {
  case voice

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    switch rawValue {
    case "classic", "hybrid", "cinematic", "voice":
      self = .voice
    default:
      self = .voice
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

enum VoiceScrollMode: String, Codable, CaseIterable {
  case classicScroll
  case soundBased
  case wordTracking

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    switch rawValue {
    case Self.classicScroll.rawValue:
      self = .classicScroll
    case Self.soundBased.rawValue, "volumeGated":
      self = .soundBased
    case Self.wordTracking.rawValue:
      self = .wordTracking
    default:
      self = .wordTracking
    }
  }

  var settingsTitle: String {
    switch self {
    case .classicScroll:
      return "Classic"
    case .soundBased:
      return "Sound-based"
    case .wordTracking:
      return "Word tracking"
    }
  }

  var settingsDescription: String {
    switch self {
    case .classicScroll:
      return "Use the configured scroll speed; voice only updates highlighting."
    case .soundBased:
      return "Scroll while microphone volume is above the sound threshold."
    case .wordTracking:
      return "Follow the currently spoken word and adapt to your actual pace."
    }
  }

  var usesVoiceDrivenScroll: Bool {
    self != .classicScroll
  }

  var usesSoundBasedMotion: Bool {
    self == .soundBased
  }

  var usesSpeechSensitivity: Bool {
    self == .soundBased || self == .wordTracking
  }

  var usesSpeechRecognitionForScroll: Bool {
    self == .wordTracking
  }

  func usesSpeechRecognition(spokenWordHighlightingEnabled: Bool) -> Bool {
    usesSpeechRecognitionForScroll || spokenWordHighlightingEnabled
  }
}

enum AppearanceMode: String, Codable, CaseIterable {
  case light, dark, system
}

enum ManagerInterfaceStyle: String, Codable, CaseIterable {
  case classic
  case liquidGlass

  var settingsTitle: String {
    switch self {
    case .classic:
      return "Classic"
    case .liquidGlass:
      return "Liquid Glass"
    }
  }

  var settingsDescription: String {
    switch self {
    case .classic:
      return "Keep Aira's current handcrafted manager chrome."
    case .liquidGlass:
      return "Use native glass surfaces with warm Aira accents."
    }
  }
}

enum ManagerTypography: String, Codable, CaseIterable {
  case small, medium, large

  var scaleFactor: Double {
    switch self {
    case .small:
      return 0.92
    case .medium:
      return 1.0
    case .large:
      return 1.1
    }
  }
}
