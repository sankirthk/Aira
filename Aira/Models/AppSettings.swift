import Foundation

enum ManualScrollConfiguration {
  static let minimumWPM: Double = 10
  static let maximumWPM: Double = 100
  static let defaultWPM: Double = 50

  static func clampedWPM(_ value: Double) -> Double {
    min(max(value, minimumWPM), maximumWPM)
  }
}

enum NotchWidthConfiguration {
  static let minimumWidth: Double = 320
  static let maximumWidth: Double = 520
  static let defaultWidth: Double = 360

  static func clampedWidth(_ value: Double) -> Double {
    min(max(value, minimumWidth), maximumWidth)
  }
}

enum NotchHeightConfiguration {
  static let minimumHeight: Double = 140
  static let maximumHeight: Double = 320
  static let defaultHeight: Double = 164

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
  var pauseOnHoverEnabled: Bool = true
  var voiceSyncMode: VoiceSyncMode = .voice
  var speechSensitivity: SpeechSensitivity = .medium
  var autoScrollWPM: Double = ManualScrollConfiguration.defaultWPM {
    didSet {
      autoScrollWPM = ManualScrollConfiguration.clampedWPM(autoScrollWPM)
    }
  }
  var screenCaptureExclusionEnabled: Bool = true
  var appearanceMode: AppearanceMode = .system
  var managerTypography: ManagerTypography = .medium
  var liveAnswerDisclosureAccepted: Bool = false

  // Pill Windows (REQ-009, REQ-044)
  var pillsEnabled: Bool = false
  var maxPillCount: Int = 1 {  // 1 or 2
    didSet {
      maxPillCount = Self.normalizedMaxPillCount(maxPillCount)
    }
  }
  var pillConfigurations: [PillWindowConfiguration] = PillWindowConfiguration.defaultSlots

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
    pauseOnHoverEnabled: Bool = true,
    voiceSyncMode: VoiceSyncMode = .voice,
    speechSensitivity: SpeechSensitivity = .medium,
    autoScrollWPM: Double = ManualScrollConfiguration.defaultWPM,
    screenCaptureExclusionEnabled: Bool = true,
    appearanceMode: AppearanceMode = .system,
    managerTypography: ManagerTypography = .medium,
    liveAnswerDisclosureAccepted: Bool = false,
    pillsEnabled: Bool = false,
    maxPillCount: Int = 1,
    pillConfigurations: [PillWindowConfiguration] = PillWindowConfiguration.defaultSlots,
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
    self.pauseOnHoverEnabled = pauseOnHoverEnabled
    self.voiceSyncMode = voiceSyncMode
    self.speechSensitivity = speechSensitivity
    self.autoScrollWPM = ManualScrollConfiguration.clampedWPM(autoScrollWPM)
    self.screenCaptureExclusionEnabled = screenCaptureExclusionEnabled
    self.appearanceMode = appearanceMode
    self.managerTypography = managerTypography
    self.liveAnswerDisclosureAccepted = liveAnswerDisclosureAccepted
    self.pillsEnabled = pillsEnabled
    self.maxPillCount = Self.normalizedMaxPillCount(maxPillCount)
    self.pillConfigurations = Self.normalizedPillConfigurations(from: pillConfigurations)
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

  var enabledPillModes: [PillContentMode] {
    guard pillsEnabled else { return [] }
    return pillModes(forRequestedCount: maxPillCount)
  }

  func pillModes(forRequestedCount count: Int) -> [PillContentMode] {
    Array(
      Self.normalizedPillConfigurations(from: pillConfigurations)
        .prefix(min(max(count, 0), PillWindowConfiguration.maximumSlotCount))
        .map(\.contentMode)
    )
  }

  func pillContentMode(forSlot slot: Int) -> PillContentMode {
    Self.normalizedPillConfigurations(from: pillConfigurations)[slot].contentMode
  }

  mutating func setPillContentMode(_ mode: PillContentMode, forSlot slot: Int) {
    var configurations = Self.normalizedPillConfigurations(from: pillConfigurations)
    configurations[slot].contentMode = mode
    pillConfigurations = configurations
  }

  static func normalizedPillConfigurations(from configurations: [PillWindowConfiguration])
    -> [PillWindowConfiguration]
  {
    var normalized = Array(configurations.prefix(PillWindowConfiguration.maximumSlotCount))
    while normalized.count < PillWindowConfiguration.maximumSlotCount {
      normalized.append(.default)
    }
    return normalized
  }

  static func normalizedMaxPillCount(_ value: Int) -> Int {
    min(max(value, 1), PillWindowConfiguration.maximumSlotCount)
  }

  private enum CodingKeys: String, CodingKey {
    case defaultOverlayAppearance
    case notchWindowWidth
    case notchWindowHeight
    case countdownDuration
    case voiceSyncEnabled
    case spokenWordHighlightingEnabled
    case pauseOnHoverEnabled
    case voiceSyncMode
    case speechSensitivity
    case autoScrollWPM
    case screenCaptureExclusionEnabled
    case appearanceMode
    case managerTypography
    case liveAnswerDisclosureAccepted
    case pillsEnabled
    case maxPillCount
    case pillConfigurations
    case pillContentMode
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
    pauseOnHoverEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .pauseOnHoverEnabled) ?? true
    voiceSyncMode =
      try container.decodeIfPresent(VoiceSyncMode.self, forKey: .voiceSyncMode) ?? .voice
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
    managerTypography =
      try container.decodeIfPresent(ManagerTypography.self, forKey: .managerTypography) ?? .medium
    liveAnswerDisclosureAccepted =
      try container.decodeIfPresent(Bool.self, forKey: .liveAnswerDisclosureAccepted) ?? false
    pillsEnabled = try container.decodeIfPresent(Bool.self, forKey: .pillsEnabled) ?? false
    maxPillCount = Self.normalizedMaxPillCount(
      try container.decodeIfPresent(Int.self, forKey: .maxPillCount) ?? 1
    )

    if let decodedConfigurations = try container.decodeIfPresent(
      [PillWindowConfiguration].self, forKey: .pillConfigurations)
    {
      pillConfigurations = Self.normalizedPillConfigurations(from: decodedConfigurations)
    } else if let legacyMode = try container.decodeIfPresent(
      PillContentMode.self, forKey: .pillContentMode)
    {
      pillConfigurations = Self.normalizedPillConfigurations(
        from: Array(
          repeating: PillWindowConfiguration(contentMode: legacyMode),
          count: PillWindowConfiguration.maximumSlotCount)
      )
    } else {
      pillConfigurations = PillWindowConfiguration.defaultSlots
    }

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
    try container.encode(pauseOnHoverEnabled, forKey: .pauseOnHoverEnabled)
    try container.encode(voiceSyncMode, forKey: .voiceSyncMode)
    try container.encode(speechSensitivity, forKey: .speechSensitivity)
    try container.encode(autoScrollWPM, forKey: .autoScrollWPM)
    try container.encode(screenCaptureExclusionEnabled, forKey: .screenCaptureExclusionEnabled)
    try container.encode(appearanceMode, forKey: .appearanceMode)
    try container.encode(managerTypography, forKey: .managerTypography)
    try container.encode(liveAnswerDisclosureAccepted, forKey: .liveAnswerDisclosureAccepted)
    try container.encode(pillsEnabled, forKey: .pillsEnabled)
    try container.encode(maxPillCount, forKey: .maxPillCount)
    try container.encode(
      Self.normalizedPillConfigurations(from: pillConfigurations), forKey: .pillConfigurations)
    try container.encode(shortcutToggleNotch, forKey: .shortcutToggleNotch)
    try container.encode(shortcutTogglePill, forKey: .shortcutTogglePill)
    try container.encode(shortcutToggleVoiceSync, forKey: .shortcutToggleVoiceSync)
    try container.encode(shortcutScrollUp, forKey: .shortcutScrollUp)
    try container.encode(shortcutScrollDown, forKey: .shortcutScrollDown)
    try container.encode(shortcutEndSession, forKey: .shortcutEndSession)
  }
}

struct PillWindowConfiguration: Codable, Equatable {
  static let maximumSlotCount = 2
  static let `default` = PillWindowConfiguration(contentMode: .voiceSync)
  static let defaultSlots = Array(
    repeating: PillWindowConfiguration.default, count: maximumSlotCount)

  var contentMode: PillContentMode = .voiceSync
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

enum AppearanceMode: String, Codable, CaseIterable {
  case light, dark, system
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
