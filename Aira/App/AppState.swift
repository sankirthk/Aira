import Combine
import Foundation

@MainActor
class AppState: ObservableObject {
  @Published var scripts: [ScriptMeta] = []
  @Published var collections: [AiraCollection] = []
  @Published var activeScript: Script? = nil
  @Published var sessionActive: Bool = false
  @Published private(set) var activeSessionScriptIDs: Set<UUID> = []
  @Published var settings: AppSettings
  @Published var stealthWarning: Bool = false
  @Published var persistenceErrorMessage: String? = nil

  private let scriptStore: ScriptStore
  private let collectionStore: CollectionStore
  private let settingsStore: SettingsStore
  private var cancellables: Set<AnyCancellable> = []

  convenience init() {
    self.init(
      scriptStore: ScriptStore(),
      collectionStore: CollectionStore(),
      settingsStore: SettingsStore()
    )
  }

  convenience init(scriptStore: ScriptStore) {
    self.init(
      scriptStore: scriptStore,
      collectionStore: CollectionStore(),
      settingsStore: SettingsStore()
    )
  }

  convenience init(collectionStore: CollectionStore) {
    self.init(
      scriptStore: ScriptStore(),
      collectionStore: collectionStore,
      settingsStore: SettingsStore()
    )
  }

  convenience init(settingsStore: SettingsStore) {
    self.init(
      scriptStore: ScriptStore(),
      collectionStore: CollectionStore(),
      settingsStore: settingsStore
    )
  }

  convenience init(scriptStore: ScriptStore, collectionStore: CollectionStore) {
    self.init(
      scriptStore: scriptStore,
      collectionStore: collectionStore,
      settingsStore: SettingsStore()
    )
  }

  init(scriptStore: ScriptStore, collectionStore: CollectionStore, settingsStore: SettingsStore) {
    self.scriptStore = scriptStore
    self.collectionStore = collectionStore
    self.settingsStore = settingsStore
    do {
      self.settings = try settingsStore.load()
    } catch {
      self.settings = AppSettings()
      self.persistenceErrorMessage = error.localizedDescription
      AiraLogger.shared.error(error, category: "storage", context: "Failed to load settings")
    }

    do {
      try refreshScripts()
      try refreshCollections()
    } catch {
      self.persistenceErrorMessage = error.localizedDescription
      AiraLogger.shared.error(
        error, category: "storage", context: "Failed to load persisted library state")
    }
    bindSettingsPersistence()
  }

  @discardableResult
  func createScript(title: String = "Untitled Script", inCollection collectionID: UUID? = nil)
    throws -> Script
  {
    let now = Date()
    let collectionIDs = collectionID.map { [$0] } ?? []
    let script = Script(
      id: UUID(),
      title: title,
      body: "",
      cues: [],
      collectionIds: collectionIDs,
      createdAt: now,
      lastEdited: now
    )

    try scriptStore.save(script)
    if let collectionID {
      try collectionStore.addScript(script.id, toCollection: collectionID)
      try refreshCollections()
    }
    activeScript = script
    try refreshScripts()
    return script
  }

  func makeDraftScript(title: String = "Untitled Script", inCollection collectionID: UUID? = nil)
    -> Script
  {
    let now = Date()
    let collectionIDs = collectionID.map { [$0] } ?? []
    return Script(
      id: UUID(),
      title: title,
      body: "",
      cues: [],
      collectionIds: collectionIDs,
      createdAt: now,
      lastEdited: now
    )
  }

  func saveScript(_ script: Script) throws {
    var updatedScript = script
    updatedScript.lastEdited = Date()

    if updatedScript.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      updatedScript.title = Self.autoTitle(from: updatedScript.body)
    }

    try scriptStore.save(updatedScript)
    for collectionID in updatedScript.collectionIds {
      try collectionStore.addScript(updatedScript.id, toCollection: collectionID)
    }
    activeScript = updatedScript
    try refreshScripts()
    try refreshCollections()
  }

  static func autoTitle(from body: String) -> String {
    let words =
      body
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
    guard !words.isEmpty else { return "Untitled Script" }
    let snippet = words.prefix(3).joined(separator: " ")
    return snippet.count > 30 ? String(snippet.prefix(30)) + "…" : snippet
  }

  func deleteScript(id: UUID) throws {
    guard !sessionActive else {
      throw AppStateActionError.deletionUnavailableDuringSession
    }

    try scriptStore.delete(id: id)

    if activeScript?.id == id {
      activeScript = nil
    }

    try refreshScripts()
  }

  @discardableResult
  func duplicateScript(id: UUID) throws -> Script {
    let duplicatedScript = try scriptStore.duplicate(id: id)
    for collectionID in duplicatedScript.collectionIds {
      try collectionStore.addScript(duplicatedScript.id, toCollection: collectionID)
    }
    activeScript = duplicatedScript
    try refreshScripts()
    try refreshCollections()
    return duplicatedScript
  }

  func toggleStarred(id: UUID) throws {
    _ = try scriptStore.toggleStarred(id: id)
    try refreshScripts()
  }

  @discardableResult
  func loadScript(id: UUID) throws -> Script {
    let script = try scriptStore.load(id: id)
    activeScript = script
    return script
  }

  func readScript(id: UUID) throws -> Script {
    try scriptStore.load(id: id)
  }

  @discardableResult
  func importScript(from url: URL, inCollection collectionID: UUID? = nil) throws -> Script {
    var script = try scriptStore.importFromURL(url)
    if let collectionID {
      try updateScriptCollections(id: script.id, collectionIDs: [collectionID])
      script = try scriptStore.load(id: script.id)
    }
    activeScript = script
    try refreshScripts()
    try refreshCollections()
    return script
  }

  /// Extracts plain text from a supported file (txt, pdf, docx) without creating a new script.
  func extractText(from url: URL) throws -> String {
    try scriptStore.extractText(from: url)
  }

  func updateScriptCollections(id: UUID, collectionIDs: [UUID]) throws {
    let originalScript = try scriptStore.load(id: id)
    let originalCollections = try collectionStore.loadAll()
    var updatedScript = originalScript
    let previousCollections = Set(originalScript.collectionIds)
    let nextCollections = Set(collectionIDs)

    updatedScript.collectionIds = collectionIDs

    do {
      for collectionID in previousCollections.subtracting(nextCollections) {
        try collectionStore.removeScript(id, fromCollection: collectionID)
      }

      for collectionID in nextCollections.subtracting(previousCollections) {
        try collectionStore.addScript(id, toCollection: collectionID)
      }

      try scriptStore.save(updatedScript)
    } catch {
      try? collectionStore.replaceAll(originalCollections)
      try? scriptStore.save(originalScript)
      throw error
    }

    if activeScript?.id == id {
      activeScript = updatedScript
    }

    try refreshScripts()
    try refreshCollections()
  }

  @discardableResult
  func createCollection(name: String) throws -> AiraCollection {
    let collection = try collectionStore.create(name: name)
    try refreshCollections()
    return collection
  }

  func renameCollection(id: UUID, to name: String) throws {
    try collectionStore.rename(id: id, to: name)
    try refreshCollections()
  }

  func deleteCollection(id: UUID) throws {
    let originalCollections = try collectionStore.loadAll()
    let affectedScripts = try scriptsContainingCollection(id)

    do {
      try removeCollectionMembershipFromScripts(collectionID: id)
      try collectionStore.delete(id: id)
    } catch {
      try? restoreScripts(affectedScripts)
      try? collectionStore.replaceAll(originalCollections)
      throw error
    }

    try refreshCollections()
  }

  func setPresenterSessionState(isActive: Bool, scriptIDs: Set<UUID>) {
    sessionActive = isActive
    activeSessionScriptIDs = scriptIDs
  }

  func isScriptLockedForSessionEditing(_ id: UUID) -> Bool {
    activeSessionScriptIDs.contains(id)
  }

  private func refreshScripts() throws {
    scripts = try scriptStore.loadIndex().sorted(by: Self.sortScripts)
  }

  private func refreshCollections() throws {
    collections = try collectionStore.loadAll().sorted(by: Self.sortCollections)
  }

  private func removeCollectionMembershipFromScripts(collectionID: UUID) throws {
    let affectedScripts = try scriptsContainingCollection(collectionID)

    for var script in affectedScripts {
      script.collectionIds.removeAll { $0 == collectionID }
      try scriptStore.save(script)

      if activeScript?.id == script.id {
        activeScript = script
      }
    }

    try refreshScripts()
  }

  private func scriptsContainingCollection(_ collectionID: UUID) throws -> [Script] {
    try scripts.compactMap { meta in
      let script = try scriptStore.load(id: meta.id)
      return script.collectionIds.contains(collectionID) ? script : nil
    }
  }

  private func restoreScripts(_ scripts: [Script]) throws {
    for script in scripts {
      try scriptStore.save(script)

      if activeScript?.id == script.id {
        activeScript = script
      }
    }

    try refreshScripts()
  }

  private func bindSettingsPersistence() {
    $settings
      .dropFirst()
      .sink { [weak self, settingsStore] settings in
        do {
          try settingsStore.save(settings)
        } catch {
          // Write to @MainActor-isolated property explicitly so Swift 6
          // strict concurrency checking can verify the actor context.
          let message = error.localizedDescription
          AiraLogger.shared.error(error, category: "storage", context: "Failed to persist settings")
          Task { @MainActor [weak self] in
            self?.persistenceErrorMessage = message
          }
        }
      }
      .store(in: &cancellables)
  }

  private static func sortScripts(_ lhs: ScriptMeta, _ rhs: ScriptMeta) -> Bool {
    if lhs.lastEdited != rhs.lastEdited {
      return lhs.lastEdited > rhs.lastEdited
    }

    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
  }

  private static func sortCollections(_ lhs: AiraCollection, _ rhs: AiraCollection) -> Bool {
    lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
  }
}

enum AppStateActionError: LocalizedError {
  case deletionUnavailableDuringSession

  var errorDescription: String? {
    switch self {
    case .deletionUnavailableDuringSession:
      return "End the active session before deleting scripts."
    }
  }
}
