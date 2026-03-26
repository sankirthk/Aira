import Testing
import Foundation
@testable import Aira

struct CollectionSidebarLogicTests {
    @Test func normalizedNameTrimsWhitespace() {
        #expect(CollectionSidebarLogic.normalizedName("  Investor Pitch  ") == "Investor Pitch")
    }

    @Test func normalizedNameRejectsBlankInput() {
        #expect(CollectionSidebarLogic.normalizedName("   \n\t  ") == nil)
    }

    @Test func deletingSelectedCollectionFallsBackToAllScripts() {
        let collectionID = UUID()

        let updatedNav = CollectionSidebarLogic.selectedNavAfterDeletingCollection(
            collectionID,
            selectedNav: .collection(collectionID)
        )

        #expect(updatedNav == .allScripts)
    }

    @Test func deletingDifferentCollectionKeepsCurrentSelection() {
        let selectedCollectionID = UUID()
        let deletedCollectionID = UUID()

        let updatedNav = CollectionSidebarLogic.selectedNavAfterDeletingCollection(
            deletedCollectionID,
            selectedNav: .collection(selectedCollectionID)
        )

        #expect(updatedNav == .collection(selectedCollectionID))
    }

    @Test func collectionFilterReturnsOnlyScriptsInSelectedCollection() {
        let includedID = UUID()
        let excludedID = UUID()
        let collectionID = UUID()
        let scripts = [
            ScriptMeta(id: includedID, title: "Included", lastEdited: .now, wordCount: 10, starred: false),
            ScriptMeta(id: excludedID, title: "Excluded", lastEdited: .now, wordCount: 12, starred: true)
        ]
        let collections = [
            AiraCollection(id: collectionID, name: "Launch", scriptIds: [includedID])
        ]

        let filtered = DocumentLibraryFilterLogic.filteredScripts(
            scripts: scripts,
            filter: .collection(collectionID),
            collections: collections
        )

        #expect(filtered.map(\.id) == [includedID])
    }

    @Test func collectionFilterReturnsEmptyWhenCollectionIsMissing() {
        let scripts = [
            ScriptMeta(id: UUID(), title: "Script", lastEdited: .now, wordCount: 10, starred: false)
        ]

        let filtered = DocumentLibraryFilterLogic.filteredScripts(
            scripts: scripts,
            filter: .collection(UUID()),
            collections: []
        )

        #expect(filtered.isEmpty)
    }

    @Test func collectionScriptCountMatchesFilteredScripts() {
        let includedID = UUID()
        let collectionID = UUID()
        let scripts = [
            ScriptMeta(id: includedID, title: "Included", lastEdited: .now, wordCount: 8, starred: false),
            ScriptMeta(id: UUID(), title: "Excluded", lastEdited: .now, wordCount: 9, starred: false)
        ]
        let collections = [
            AiraCollection(id: collectionID, name: "Launch", scriptIds: [includedID])
        ]

        let count = DocumentLibraryFilterLogic.scriptCount(
            for: collectionID,
            scripts: scripts,
            collections: collections
        )

        #expect(count == 1)
    }

    @Test func recentScriptsAreOrderedByLastEditedDescending() {
        let older = ScriptMeta(
            id: UUID(),
            title: "Older",
            lastEdited: Date(timeIntervalSince1970: 100),
            wordCount: 10,
            starred: false
        )
        let newer = ScriptMeta(
            id: UUID(),
            title: "Newer",
            lastEdited: Date(timeIntervalSince1970: 200),
            wordCount: 12,
            starred: false
        )

        let ordered = DocumentLibraryFilterLogic.recentScripts(from: [older, newer])

        #expect(ordered.map(\.title) == ["Newer", "Older"])
    }

    @Test func starredScriptsAreFilteredAndOrderedByLastEditedDescending() {
        let oldestStarred = ScriptMeta(
            id: UUID(),
            title: "Old Star",
            lastEdited: Date(timeIntervalSince1970: 100),
            wordCount: 10,
            starred: true
        )
        let unstarred = ScriptMeta(
            id: UUID(),
            title: "Plain",
            lastEdited: Date(timeIntervalSince1970: 300),
            wordCount: 10,
            starred: false
        )
        let newestStarred = ScriptMeta(
            id: UUID(),
            title: "New Star",
            lastEdited: Date(timeIntervalSince1970: 200),
            wordCount: 10,
            starred: true
        )

        let ordered = DocumentLibraryFilterLogic.starredScripts(from: [oldestStarred, unstarred, newestStarred])

        #expect(ordered.map(\.title) == ["New Star", "Old Star"])
    }
}
