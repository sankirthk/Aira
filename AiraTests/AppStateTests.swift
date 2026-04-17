import Foundation
import Testing

@testable import Aira

@MainActor
struct AppStateTests {

  @Test func initLoadsScriptIndex() throws {
    let (store, dir) = try makeStore()
    defer { cleanup(dir) }

    let script = makeScript(title: "Existing Script")
    try store.save(script)

    let appState = AppState(scriptStore: store)

    #expect(appState.scripts.count == 1)
    #expect(appState.scripts.first?.id == script.id)
    #expect(appState.scripts.first?.title == "Existing Script")
  }

  @Test func createScriptPersistsAndSetsActiveScript() throws {
    let (store, dir) = try makeStore()
    defer { cleanup(dir) }

    let appState = AppState(scriptStore: store)
    let script = try appState.createScript()

    #expect(appState.activeScript?.id == script.id)
    #expect(appState.scripts.contains(where: { $0.id == script.id }))
    #expect(try store.load(id: script.id).title == "Untitled Script")
  }

  @Test func makeDraftScriptDoesNotPersistOnCreation() throws {
    let (store, dir) = try makeStore()
    defer { cleanup(dir) }

    let appState = AppState(scriptStore: store)
    let draft = appState.makeDraftScript()

    #expect(appState.scripts.isEmpty)
    #expect(appState.activeScript == nil)
    #expect(draft.title == "Untitled Script")
    #expect(draft.body.isEmpty)
    #expect(throws: (any Error).self) {
      try store.load(id: draft.id)
    }
  }

  @Test func saveScriptPersistsChangesAndRefreshesIndex() throws {
    let (store, dir) = try makeStore()
    defer { cleanup(dir) }

    let original = makeScript(title: "Draft", body: "One two")
    try store.save(original)

    let appState = AppState(scriptStore: store)
    var updated = try appState.loadScript(id: original.id)
    updated.title = "Final"
    updated.body = "One two three four"
    let previousEditDate = updated.lastEdited

    try appState.saveScript(updated)

    let saved = try store.load(id: original.id)
    let savedMeta = try #require(appState.scripts.first(where: { $0.id == original.id }))
    #expect(saved.title == "Final")
    #expect(saved.body == "One two three four")
    #expect(saved.lastEdited >= previousEditDate)
    #expect(savedMeta.title == "Final")
    #expect(savedMeta.wordCount == 4)
    #expect(appState.activeScript?.title == "Final")
  }

  @Test func saveDraftScriptPersistsOnFirstSave() throws {
    let (store, dir) = try makeStore()
    defer { cleanup(dir) }

    let appState = AppState(scriptStore: store)
    var draft = appState.makeDraftScript()
    draft.body = "A saved draft"

    try appState.saveScript(draft)

    let saved = try store.load(id: draft.id)
    #expect(saved.body == "A saved draft")
    #expect(appState.scripts.contains(where: { $0.id == draft.id }))
    #expect(appState.activeScript?.id == draft.id)
  }

  @Test func deleteScriptRemovesIndexEntryAndClearsActiveScript() throws {
    let (store, dir) = try makeStore()
    defer { cleanup(dir) }

    let script = makeScript()
    try store.save(script)

    let appState = AppState(scriptStore: store)
    _ = try appState.loadScript(id: script.id)
    try appState.deleteScript(id: script.id)

    #expect(appState.activeScript?.id == nil)
    #expect(appState.scripts.isEmpty)
    #expect(throws: (any Error).self) {
      try store.load(id: script.id)
    }
  }

  @Test func presenterSessionTrackingStoresActiveScriptIDs() throws {
    let (store, dir) = try makeStore()
    defer { cleanup(dir) }

    let appState = AppState(scriptStore: store)
    let ids = Set([UUID(), UUID()])

    appState.setPresenterSessionState(isActive: true, scriptIDs: ids)

    #expect(appState.sessionActive)
    #expect(appState.activeSessionScriptIDs == ids)
    #expect(appState.isScriptLockedForSessionEditing(ids.first!))

    appState.setPresenterSessionState(isActive: false, scriptIDs: [])

    #expect(!appState.sessionActive)
    #expect(appState.activeSessionScriptIDs.isEmpty)
  }

  @Test func deleteScriptFailsWhilePresenterSessionIsActive() throws {
    let (store, dir) = try makeStore()
    defer { cleanup(dir) }

    let script = makeScript()
    try store.save(script)

    let appState = AppState(scriptStore: store)
    appState.setPresenterSessionState(isActive: true, scriptIDs: [script.id])

    #expect(throws: AppStateActionError.deletionUnavailableDuringSession) {
      try appState.deleteScript(id: script.id)
    }
    #expect(appState.scripts.contains(where: { $0.id == script.id }))
    #expect(try store.load(id: script.id).id == script.id)
  }

  @Test func duplicateScriptCreatesCopyAndMakesItActive() throws {
    let (store, dir) = try makeStore()
    defer { cleanup(dir) }

    let original = makeScript(title: "Quarterly Update", body: "Some content")
    try store.save(original)

    let appState = AppState(scriptStore: store)
    let copy = try appState.duplicateScript(id: original.id)

    #expect(copy.id != original.id)
    #expect(copy.title == "Copy of Quarterly Update")
    #expect(copy.body == original.body)
    #expect(appState.activeScript?.id == copy.id)
    #expect(appState.scripts.count == 2)
  }

  @Test func duplicateScriptInCollectionRefreshesCollectionMembership() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
    }

    let collection = try collectionStore.create(name: "Launch")
    let original = Script(
      id: UUID(),
      title: "Quarterly Update",
      body: "Some content",
      cues: [],
      collectionIds: [collection.id],
      createdAt: Date(),
      lastEdited: Date()
    )
    try scriptStore.save(original)
    try collectionStore.addScript(original.id, toCollection: collection.id)

    let appState = AppState(scriptStore: scriptStore, collectionStore: collectionStore)
    let copy = try appState.duplicateScript(id: original.id)

    let refreshedCollection = try #require(
      appState.collections.first(where: { $0.id == collection.id }))
    #expect(copy.collectionIds == [collection.id])
    #expect(refreshedCollection.scriptIds.contains(copy.id))
  }

  @Test func toggleStarredPersistsAcrossSubsequentSaves() throws {
    let (store, dir) = try makeStore()
    defer { cleanup(dir) }

    let script = makeScript()
    try store.save(script)

    let appState = AppState(scriptStore: store)
    try appState.toggleStarred(id: script.id)
    let starredMeta = try #require(appState.scripts.first(where: { $0.id == script.id }))
    #expect(starredMeta.starred)

    var updated = try appState.loadScript(id: script.id)
    updated.body = "Updated body"
    try appState.saveScript(updated)

    let persistedMeta = try #require(appState.scripts.first(where: { $0.id == script.id }))
    #expect(persistedMeta.starred)
  }

  @Test func loadScriptSetsActiveScript() throws {
    let (store, dir) = try makeStore()
    defer { cleanup(dir) }

    let script = makeScript(title: "Load Me", body: "Body")
    try store.save(script)

    let appState = AppState(scriptStore: store)
    let loaded = try appState.loadScript(id: script.id)

    #expect(loaded.id == script.id)
    #expect(appState.activeScript?.id == script.id)
    #expect(appState.activeScript?.body == "Body")
  }

  @Test func readScriptReturnsScriptWithoutChangingActiveScript() throws {
    let (store, dir) = try makeStore()
    defer { cleanup(dir) }

    let active = makeScript(title: "Active", body: "Current")
    let other = makeScript(title: "Other", body: "Separate")
    try store.save(active)
    try store.save(other)

    let appState = AppState(scriptStore: store)
    _ = try appState.loadScript(id: active.id)

    let loaded = try appState.readScript(id: other.id)

    #expect(loaded.id == other.id)
    #expect(appState.activeScript?.id == active.id)
  }

  @Test func importScriptPersistsImportedFileAndSetsActiveScript() throws {
    let (store, dir) = try makeStore()
    defer { cleanup(dir) }

    let textFile = dir.appending(path: "import-me.txt")
    try "Imported speech".write(to: textFile, atomically: true, encoding: .utf8)

    let appState = AppState(scriptStore: store)
    let imported = try appState.importScript(from: textFile)

    #expect(imported.title == "import-me")
    #expect(imported.body == "Imported speech")
    #expect(appState.activeScript?.id == imported.id)
    #expect(appState.scripts.contains(where: { $0.id == imported.id }))
  }

  @Test func importScriptInCollectionPersistsMembershipAndRefreshesCollections() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
    }

    let collection = try collectionStore.create(name: "Imported")
    let textFile = scriptDir.appending(path: "collection-import.txt")
    try "Imported into collection".write(to: textFile, atomically: true, encoding: .utf8)

    let appState = AppState(scriptStore: scriptStore, collectionStore: collectionStore)
    let imported = try appState.importScript(from: textFile, inCollection: collection.id)

    #expect(imported.collectionIds == [collection.id])
    #expect(try scriptStore.load(id: imported.id).collectionIds == [collection.id])
    #expect(try collectionStore.loadAll().first?.scriptIds == [imported.id])
    #expect(appState.collections.first?.scriptIds == [imported.id])
  }

  @Test func importScriptUsingDocumentLibraryCollectionContextPersistsMembership() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
    }

    let collection = try collectionStore.create(name: "Dropped")
    let textFile = scriptDir.appending(path: "dropped-import.txt")
    try "Dropped into collection".write(to: textFile, atomically: true, encoding: .utf8)

    let appState = AppState(scriptStore: scriptStore, collectionStore: collectionStore)
    let imported = try appState.importScript(
      from: textFile,
      inCollection: DocumentLibraryImportLogic.selectedCollectionID(for: .collection(collection.id))
    )

    #expect(imported.collectionIds == [collection.id])
    #expect(try scriptStore.load(id: imported.id).collectionIds == [collection.id])
    #expect(try collectionStore.loadAll().first?.scriptIds == [imported.id])
  }

  @Test func initLoadsCollections() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
    }

    _ = try collectionStore.create(name: "Investor Pitch")

    let appState = AppState(scriptStore: scriptStore, collectionStore: collectionStore)

    #expect(appState.collections.count == 1)
    #expect(appState.collections.first?.name == "Investor Pitch")
  }

  @Test func createCollectionPersistsAndRefreshesState() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
    }

    let appState = AppState(scriptStore: scriptStore, collectionStore: collectionStore)
    let collection = try appState.createCollection(name: "Product Demos")

    #expect(appState.collections.contains(where: { $0.id == collection.id }))
    #expect(try collectionStore.loadAll().contains(where: { $0.id == collection.id }))
  }

  @Test func deleteCollectionRemovesMembershipFromPersistedScripts() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
    }

    let collection = try collectionStore.create(name: "Launch")
    let scriptInCollection = Script(
      id: UUID(),
      title: "Launch Notes",
      body: "Body",
      cues: [],
      collectionIds: [collection.id],
      createdAt: Date(),
      lastEdited: Date()
    )
    let unaffectedScript = Script(
      id: UUID(),
      title: "General Notes",
      body: "Body",
      cues: [],
      collectionIds: [],
      createdAt: Date(),
      lastEdited: Date()
    )
    try scriptStore.save(scriptInCollection)
    try scriptStore.save(unaffectedScript)
    try collectionStore.addScript(scriptInCollection.id, toCollection: collection.id)

    let appState = AppState(scriptStore: scriptStore, collectionStore: collectionStore)
    try appState.deleteCollection(id: collection.id)

    let reloadedScript = try scriptStore.load(id: scriptInCollection.id)
    let reloadedUnaffectedScript = try scriptStore.load(id: unaffectedScript.id)
    #expect(!reloadedScript.collectionIds.contains(collection.id))
    #expect(reloadedUnaffectedScript.collectionIds.isEmpty)
    #expect(appState.collections.contains(where: { $0.id == collection.id }) == false)
  }

  @Test func createScriptInCollectionPersistsMembershipAndRefreshesCollections() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
    }

    let collection = try collectionStore.create(name: "Launch")
    let appState = AppState(scriptStore: scriptStore, collectionStore: collectionStore)

    let script = try appState.createScript(inCollection: collection.id)

    #expect(script.collectionIds == [collection.id])
    #expect(appState.collections.first?.scriptIds == [script.id])
    #expect(try scriptStore.load(id: script.id).collectionIds == [collection.id])
    #expect(try collectionStore.loadAll().first?.scriptIds == [script.id])
  }

  @Test func saveDraftScriptInCollectionPersistsMembershipAndRefreshesCollections() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
    }

    let collection = try collectionStore.create(name: "Drafts")
    let appState = AppState(scriptStore: scriptStore, collectionStore: collectionStore)
    var draft = appState.makeDraftScript(inCollection: collection.id)
    draft.title = "Collection Draft"

    try appState.saveScript(draft)

    #expect(try scriptStore.load(id: draft.id).collectionIds == [collection.id])
    #expect(try collectionStore.loadAll().first?.scriptIds == [draft.id])
    #expect(appState.collections.first?.scriptIds == [draft.id])
  }

  @Test func updateScriptCollectionsMovesScriptFromNoCollectionIntoCollection() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
    }

    let collection = try collectionStore.create(name: "Assigned")
    let script = makeScript(title: "Loose Script")
    try scriptStore.save(script)

    let appState = AppState(scriptStore: scriptStore, collectionStore: collectionStore)
    try appState.updateScriptCollections(id: script.id, collectionIDs: [collection.id])

    #expect(try scriptStore.load(id: script.id).collectionIds == [collection.id])
    #expect(try collectionStore.loadAll().first?.scriptIds == [script.id])
    #expect(appState.collections.first?.scriptIds == [script.id])
  }

  @Test func updateScriptCollectionsMovesScriptBetweenCollections() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
    }

    let source = try collectionStore.create(name: "Source")
    let destination = try collectionStore.create(name: "Destination")
    let script = Script(
      id: UUID(),
      title: "Movable",
      body: "Body",
      cues: [],
      collectionIds: [source.id],
      createdAt: Date(),
      lastEdited: Date()
    )
    try scriptStore.save(script)
    try collectionStore.addScript(script.id, toCollection: source.id)

    let appState = AppState(scriptStore: scriptStore, collectionStore: collectionStore)
    try appState.updateScriptCollections(id: script.id, collectionIDs: [destination.id])

    let persisted = try scriptStore.load(id: script.id)
    let refreshedCollections = try collectionStore.loadAll()
    let persistedSource = try #require(refreshedCollections.first(where: { $0.id == source.id }))
    let persistedDestination = try #require(
      refreshedCollections.first(where: { $0.id == destination.id }))

    #expect(persisted.collectionIds == [destination.id])
    #expect(!persistedSource.scriptIds.contains(script.id))
    #expect(persistedDestination.scriptIds.contains(script.id))
  }

  @Test func updateScriptCollectionsPreservesExistingMembershipsWhenAddingAnotherCollection() throws
  {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
    }

    let first = try collectionStore.create(name: "First")
    let second = try collectionStore.create(name: "Second")
    let script = Script(
      id: UUID(),
      title: "Shared",
      body: "Body",
      cues: [],
      collectionIds: [first.id],
      createdAt: Date(),
      lastEdited: Date()
    )
    try scriptStore.save(script)
    try collectionStore.addScript(script.id, toCollection: first.id)

    let appState = AppState(scriptStore: scriptStore, collectionStore: collectionStore)
    try appState.updateScriptCollections(id: script.id, collectionIDs: [first.id, second.id])

    let persisted = try scriptStore.load(id: script.id)
    let refreshedCollections = try collectionStore.loadAll()
    let persistedFirst = try #require(refreshedCollections.first(where: { $0.id == first.id }))
    let persistedSecond = try #require(refreshedCollections.first(where: { $0.id == second.id }))

    #expect(Set(persisted.collectionIds) == Set([first.id, second.id]))
    #expect(persistedFirst.scriptIds.contains(script.id))
    #expect(persistedSecond.scriptIds.contains(script.id))
  }

  @Test func updateScriptCollectionsRemovesOnlyDeselectedMemberships() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
    }

    let first = try collectionStore.create(name: "First")
    let second = try collectionStore.create(name: "Second")
    let script = Script(
      id: UUID(),
      title: "Shared",
      body: "Body",
      cues: [],
      collectionIds: [first.id, second.id],
      createdAt: Date(),
      lastEdited: Date()
    )
    try scriptStore.save(script)
    try collectionStore.addScript(script.id, toCollection: first.id)
    try collectionStore.addScript(script.id, toCollection: second.id)

    let appState = AppState(scriptStore: scriptStore, collectionStore: collectionStore)
    try appState.updateScriptCollections(id: script.id, collectionIDs: [second.id])

    let persisted = try scriptStore.load(id: script.id)
    let refreshedCollections = try collectionStore.loadAll()
    let persistedFirst = try #require(refreshedCollections.first(where: { $0.id == first.id }))
    let persistedSecond = try #require(refreshedCollections.first(where: { $0.id == second.id }))

    #expect(persisted.collectionIds == [second.id])
    #expect(!persistedFirst.scriptIds.contains(script.id))
    #expect(persistedSecond.scriptIds.contains(script.id))
  }

  @Test func renameCollectionPersistsAndRefreshesState() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
    }

    let collection = try collectionStore.create(name: "Old Name")
    let appState = AppState(scriptStore: scriptStore, collectionStore: collectionStore)

    try appState.renameCollection(id: collection.id, to: "New Name")

    #expect(appState.collections.first?.name == "New Name")
    #expect(try collectionStore.loadAll().first?.name == "New Name")
  }

  @Test func deleteCollectionRemovesItFromStateAndStorage() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
    }

    let collection = try collectionStore.create(name: "Delete Me")
    let appState = AppState(scriptStore: scriptStore, collectionStore: collectionStore)

    try appState.deleteCollection(id: collection.id)

    #expect(appState.collections.isEmpty)
    #expect(try collectionStore.loadAll().isEmpty)
  }

  @Test func initLoadsSettingsFromSettingsStore() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    let (settingsStore, defaults, suiteName) = makeSettingsStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
      cleanupSettings(defaults, suiteName: suiteName)
    }

    let storedSettings = AppSettings(
      defaultOverlayAppearance: OverlayAppearance(
        textColor: "#101010",
        backgroundColor: "#F0EAD6",
        opacity: 0.91,
        fontName: "Manrope-Bold",
        fontSize: 26
      ),
      countdownDuration: 7,
      voiceSyncEnabled: false,
      speechSensitivity: .low,
      appearanceMode: .dark,
      managerTypography: .large,
      liveAnswerDisclosureAccepted: true,
      shortcutToggleNotch: "⌘⇧1",
      shortcutTogglePill: "⌘⇧2",
      shortcutToggleVoiceSync: "⌘⇧3",
      shortcutScrollUp: "Fn↑",
      shortcutScrollDown: "Fn↓",
      shortcutEndSession: "⌘W"
    )
    try settingsStore.save(storedSettings)

    let appState = AppState(
      scriptStore: scriptStore,
      collectionStore: collectionStore,
      settingsStore: settingsStore
    )

    #expect(appState.settings == storedSettings)
  }

  @Test func settingsMutationsPersistThroughSettingsStore() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    let (settingsStore, defaults, suiteName) = makeSettingsStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
      cleanupSettings(defaults, suiteName: suiteName)
    }

    let appState = AppState(
      scriptStore: scriptStore,
      collectionStore: collectionStore,
      settingsStore: settingsStore
    )

    appState.settings.defaultOverlayAppearance.fontSize = 28
    appState.settings.defaultOverlayAppearance.textColor = "#D4B483"
    appState.settings.countdownDuration = 0
    appState.settings.voiceSyncEnabled = false
    appState.settings.speechSensitivity = .high
    appState.settings.autoScrollWPM = 170
    appState.settings.appearanceMode = .light
    appState.settings.managerTypography = .small
    appState.settings.pillsEnabled = true
    appState.settings.maxPillCount = 2
    appState.settings.shortcutToggleNotch = "⌘⌥N"
    appState.settings.shortcutTogglePill = "⌘⌥P"
    appState.settings.shortcutToggleVoiceSync = "⌃⌥Space"
    appState.settings.shortcutScrollUp = "⌥↑"
    appState.settings.shortcutScrollDown = "⌥↓"
    appState.settings.shortcutEndSession = "⌘."

    let persisted = try settingsStore.load()
    #expect(persisted == appState.settings)
  }

  @Test func initWithCorruptSettingsFallsBackToDefaultsAndPublishesError() throws {
    let (scriptStore, scriptDir) = try makeStore()
    let (collectionStore, collectionDir) = try makeCollectionStore()
    let (settingsStore, defaults, suiteName) = makeSettingsStore()
    defer {
      cleanup(scriptDir)
      cleanup(collectionDir)
      cleanupSettings(defaults, suiteName: suiteName)
    }

    defaults.set(Data("broken".utf8), forKey: "aira.appSettings")

    let appState = AppState(
      scriptStore: scriptStore,
      collectionStore: collectionStore,
      settingsStore: settingsStore
    )

    #expect(appState.settings == AppSettings())
    #expect(
      appState.persistenceErrorMessage == SettingsStore.StoreError.corruptData.localizedDescription)
  }
}
