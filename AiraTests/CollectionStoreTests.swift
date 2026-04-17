import Foundation
import Testing

@testable import Aira

func makeCollectionStore() throws -> (CollectionStore, URL) {
  let dir = FileManager.default.temporaryDirectory
    .appending(path: "AiraCollectionsTests-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  return (CollectionStore(directory: dir), dir)
}

func makeCollection(name: String = "Demos", scriptIds: [UUID] = []) -> AiraCollection {
  AiraCollection(id: UUID(), name: name, scriptIds: scriptIds)
}

struct CollectionStoreTests {

  @Test func createPersistsCollection() throws {
    let (store, dir) = try makeCollectionStore()
    defer { cleanup(dir) }

    let collection = try store.create(name: "Product Demos")
    let all = try store.loadAll()

    #expect(all.count == 1)
    #expect(all.first?.id == collection.id)
    #expect(all.first?.name == "Product Demos")
  }

  @Test func loadAllReturnsEmptyWhenMissing() throws {
    let (store, dir) = try makeCollectionStore()
    defer { cleanup(dir) }

    let all = try store.loadAll()
    #expect(all.isEmpty)
  }

  @Test func loadAllCorruptJSONThrows() throws {
    let (store, dir) = try makeCollectionStore()
    defer { cleanup(dir) }

    try Data("broken".utf8).write(to: dir.appending(path: "collections.json"))

    #expect(throws: (any Error).self) {
      try store.loadAll()
    }
  }

  @Test func createWithCorruptDataThrowsInsteadOfResettingCollections() throws {
    let (store, dir) = try makeCollectionStore()
    defer { cleanup(dir) }

    try Data("broken".utf8).write(to: dir.appending(path: "collections.json"))

    #expect(throws: (any Error).self) {
      try store.create(name: "Won't Save")
    }
  }

  @Test func renamePersistsNewName() throws {
    let (store, dir) = try makeCollectionStore()
    defer { cleanup(dir) }

    let collection = try store.create(name: "Old Name")
    try store.rename(id: collection.id, to: "New Name")

    let all = try store.loadAll()
    #expect(all.first?.name == "New Name")
  }

  @Test func deleteRemovesCollectionButNotScripts() throws {
    let (store, dir) = try makeCollectionStore()
    defer { cleanup(dir) }

    let scriptId = UUID()
    let collection = try store.create(name: "To Delete")
    try store.addScript(scriptId, toCollection: collection.id)

    try store.delete(id: collection.id)

    let all = try store.loadAll()
    #expect(all.isEmpty)
  }

  @Test func addScriptDoesNotDuplicateIds() throws {
    let (store, dir) = try makeCollectionStore()
    defer { cleanup(dir) }

    let collection = try store.create(name: "Team Talks")
    let scriptId = UUID()

    try store.addScript(scriptId, toCollection: collection.id)
    try store.addScript(scriptId, toCollection: collection.id)

    let all = try store.loadAll()
    #expect(all.first?.scriptIds == [scriptId])
  }

  @Test func removeScriptDeletesMembership() throws {
    let (store, dir) = try makeCollectionStore()
    defer { cleanup(dir) }

    let collection = try store.create(name: "Weekly")
    let scriptId = UUID()

    try store.addScript(scriptId, toCollection: collection.id)
    try store.removeScript(scriptId, fromCollection: collection.id)

    let all = try store.loadAll()
    #expect(all.first?.scriptIds.isEmpty == true)
  }

  @Test func collectionCodableRoundTrip() throws {
    let collection = makeCollection(name: "Round Trip", scriptIds: [UUID(), UUID()])
    let data = try JSONEncoder().encode(collection)
    let decoded = try JSONDecoder().decode(AiraCollection.self, from: data)

    #expect(decoded.id == collection.id)
    #expect(decoded.name == collection.name)
    #expect(decoded.scriptIds == collection.scriptIds)
  }
}
