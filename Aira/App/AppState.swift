import Foundation
import Combine

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
        }

        do {
            try refreshScripts()
            try refreshCollections()
        } catch {
            self.persistenceErrorMessage = error.localizedDescription
        }
        bindSettingsPersistence()
    }

    @discardableResult
    func createScript(title: String = "Untitled Script", inCollection collectionID: UUID? = nil) throws -> Script {
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

    func makeDraftScript(title: String = "Untitled Script", inCollection collectionID: UUID? = nil) -> Script {
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

        try scriptStore.save(updatedScript)
        for collectionID in updatedScript.collectionIds {
            try collectionStore.addScript(updatedScript.id, toCollection: collectionID)
        }
        activeScript = updatedScript
        try refreshScripts()
        try refreshCollections()
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
    func importScript(from url: URL) throws -> Script {
        let script = try scriptStore.importFromURL(url)
        activeScript = script
        try refreshScripts()
        return script
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
        try collectionStore.delete(id: id)
        try removeCollectionMembershipFromScripts(collectionID: id)
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
        let affectedScriptIDs = scripts
            .compactMap { meta -> UUID? in
                guard let script = try? scriptStore.load(id: meta.id) else {
                    return nil
                }
                return script.collectionIds.contains(collectionID) ? meta.id : nil
            }

        for scriptID in affectedScriptIDs {
            var script = try scriptStore.load(id: scriptID)
            script.collectionIds.removeAll { $0 == collectionID }
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
                    self?.persistenceErrorMessage = error.localizedDescription
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
