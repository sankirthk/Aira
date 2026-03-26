import Testing
import Foundation
@testable import Aira

// MARK: - Helpers

func makeStore() throws -> (ScriptStore, URL) {
    let dir = FileManager.default.temporaryDirectory
        .appending(path: "AiraTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return (ScriptStore(directory: dir), dir)
}

func cleanup(_ dir: URL) {
    try? FileManager.default.removeItem(at: dir)
}

func makeScript(title: String = "Test Script", body: String = "Hello world") -> Script {
    Script(
        id: UUID(),
        title: title,
        body: body,
        cues: [],
        collectionIds: [],
        createdAt: Date(),
        lastEdited: Date()
    )
}

// MARK: - Tests

struct ScriptStoreTests {

    // UT-001: save writes a JSON file that decodes back to the same Script
    @Test func saveAndReload() throws {
        let (store, dir) = try makeStore()
        defer { cleanup(dir) }

        let script = makeScript()
        try store.save(script)

        let loaded = try store.load(id: script.id)
        #expect(loaded.id == script.id)
        #expect(loaded.title == script.title)
        #expect(loaded.body == script.body)
    }

    // UT-002: loadIndex returns empty array when no index file exists
    @Test func loadIndexWhenEmpty() throws {
        let (store, dir) = try makeStore()
        defer { cleanup(dir) }

        let index = try store.loadIndex()
        #expect(index.isEmpty)
    }

    // UT-003: loadIndex returns correct entries after saves
    @Test func loadIndexAfterSaves() throws {
        let (store, dir) = try makeStore()
        defer { cleanup(dir) }

        let a = makeScript(title: "Alpha")
        let b = makeScript(title: "Beta")
        try store.save(a)
        try store.save(b)

        let index = try store.loadIndex()
        #expect(index.count == 2)
        #expect(index.contains(where: { $0.id == a.id }))
        #expect(index.contains(where: { $0.id == b.id }))
    }

    @Test func loadIndexCountsWordsAcrossWhitespace() throws {
        let (store, dir) = try makeStore()
        defer { cleanup(dir) }

        let script = makeScript(body: "hello\nworld\tfrom   aira")
        try store.save(script)

        let meta = try #require(store.loadIndex().first(where: { $0.id == script.id }))
        #expect(meta.wordCount == 4)
    }

    @Test func loadIndexCorruptJSONThrows() throws {
        let (store, dir) = try makeStore()
        defer { cleanup(dir) }

        try Data("broken".utf8).write(to: dir.appending(path: "index.json"))

        #expect(throws: (any Error).self) {
            try store.loadIndex()
        }
    }

    @Test func saveWithCorruptIndexThrowsInsteadOfReplacingData() throws {
        let (store, dir) = try makeStore()
        defer { cleanup(dir) }

        try Data("broken".utf8).write(to: dir.appending(path: "index.json"))

        #expect(throws: (any Error).self) {
            try store.save(makeScript())
        }
    }

    // UT-004: load throws when file does not exist
    @Test func loadMissingThrows() throws {
        let (store, dir) = try makeStore()
        defer { cleanup(dir) }

        #expect(throws: (any Error).self) {
            try store.load(id: UUID())
        }
    }

    // UT-005: delete removes file and removes entry from index
    @Test func deleteRemovesFileAndIndex() throws {
        let (store, dir) = try makeStore()
        defer { cleanup(dir) }

        let script = makeScript()
        try store.save(script)
        try store.delete(id: script.id)

        let index = try store.loadIndex()
        #expect(index.isEmpty)
        #expect(throws: (any Error).self) {
            try store.load(id: script.id)
        }
    }

    // UT-006: duplicate creates new file with different UUID, same body, title prefixed "Copy of"
    @Test func duplicateCreatesNewScript() throws {
        let (store, dir) = try makeStore()
        defer { cleanup(dir) }

        let original = makeScript(title: "My Talk", body: "Some content")
        try store.save(original)

        let copy = try store.duplicate(id: original.id)
        #expect(copy.id != original.id)
        #expect(copy.body == original.body)
        #expect(copy.title == "Copy of My Talk")

        let index = try store.loadIndex()
        #expect(index.count == 2)
    }

    @Test func duplicatePreservesCollectionMembership() throws {
        let (store, dir) = try makeStore()
        defer { cleanup(dir) }

        let collectionIDs = [UUID(), UUID()]
        let original = Script(
            id: UUID(),
            title: "Collection Script",
            body: "Some content",
            cues: [],
            collectionIds: collectionIDs,
            createdAt: Date(),
            lastEdited: Date()
        )
        try store.save(original)

        let copy = try store.duplicate(id: original.id)
        #expect(copy.collectionIds == collectionIDs)
    }

    // UT-007: importFromURL creates script whose body matches file contents
    @Test func importFromURLMatchesFileBody() throws {
        let (store, dir) = try makeStore()
        defer { cleanup(dir) }

        let txtFile = dir.appending(path: "sample.txt")
        let content = "This is my speech content."
        try content.write(to: txtFile, atomically: true, encoding: .utf8)

        let script = try store.importFromURL(txtFile)
        #expect(script.body == content)
        #expect(script.title == "sample")
    }

    @Test func importFromURLDoesNotModifySourceFile() throws {
        let (store, dir) = try makeStore()
        defer { cleanup(dir) }

        let txtFile = dir.appending(path: "source.txt")
        let content = "Original content stays put."
        try content.write(to: txtFile, atomically: true, encoding: .utf8)

        _ = try store.importFromURL(txtFile)

        let sourceContents = try String(contentsOf: txtFile, encoding: .utf8)
        #expect(sourceContents == content)
    }

    // UT-008: importFromURL throws fileTooLarge for files over 10 MB
    @Test func importFromURLRejectsTooLarge() throws {
        let (store, dir) = try makeStore()
        defer { cleanup(dir) }

        let bigFile = dir.appending(path: "big.txt")
        // Write 10 MB + 1 byte
        let data = Data(repeating: 65, count: 10_000_001)
        try data.write(to: bigFile)

        #expect(throws: ScriptStore.ImportError.fileTooLarge) {
            try store.importFromURL(bigFile)
        }
    }

    // UT-009: Script Codable round-trip
    @Test func scriptCodableRoundTrip() throws {
        let script = makeScript(title: "Round Trip", body: "Content here")
        let data = try JSONEncoder().encode(script)
        let decoded = try JSONDecoder().decode(Script.self, from: data)
        #expect(decoded.id == script.id)
        #expect(decoded.title == script.title)
        #expect(decoded.body == script.body)
        #expect(decoded.cues.count == script.cues.count)
    }

    // IT-006: save script -> re-init store -> load(id:) returns same body and title
    @Test func savePersistsAcrossStoreReinitialization() throws {
        let (store, dir) = try makeStore()
        defer { cleanup(dir) }

        let script = makeScript(title: "Persisted", body: "Reload me")
        try store.save(script)

        let reloadedStore = ScriptStore(directory: dir)
        let loaded = try reloadedStore.load(id: script.id)
        #expect(loaded.title == "Persisted")
        #expect(loaded.body == "Reload me")
    }

    // IT-007: delete script -> re-init store -> loadIndex omits deleted id
    @Test func deletePersistsAcrossStoreReinitialization() throws {
        let (store, dir) = try makeStore()
        defer { cleanup(dir) }

        let script = makeScript()
        try store.save(script)
        try store.delete(id: script.id)

        let reloadedStore = ScriptStore(directory: dir)
        let index = try reloadedStore.loadIndex()
        #expect(index.contains(where: { $0.id == script.id }) == false)
    }
}
