import Foundation

struct CollectionSidebarLogic {
    static func normalizedName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func selectedNavAfterDeletingCollection(
        _ collectionID: UUID,
        selectedNav: SidebarNav
    ) -> SidebarNav {
        if selectedNav == .collection(collectionID) {
            return .allScripts
        }

        return selectedNav
    }
}

struct DocumentLibraryFilterLogic {
    static func starredScripts(from scripts: [ScriptMeta]) -> [ScriptMeta] {
        scripts
            .filter(\.starred)
            .sorted { $0.lastEdited > $1.lastEdited }
    }

    static func recentScripts(from scripts: [ScriptMeta]) -> [ScriptMeta] {
        scripts.sorted { $0.lastEdited > $1.lastEdited }
    }

    static func scriptCount(
        for collectionID: UUID,
        scripts: [ScriptMeta],
        collections: [AiraCollection]
    ) -> Int {
        filteredScripts(
            scripts: scripts,
            filter: .collection(collectionID),
            collections: collections
        ).count
    }

    static func filteredScripts(
        scripts: [ScriptMeta],
        filter: SidebarNav,
        collections: [AiraCollection]
    ) -> [ScriptMeta] {
        switch filter {
        case .starred:
            return starredScripts(from: scripts)
        case .recent:
            return recentScripts(from: scripts)
        case .collection(let id):
            let scriptIDs = collections.first(where: { $0.id == id })?.scriptIds ?? []
            return scripts.filter { scriptIDs.contains($0.id) }
        case .allScripts:
            return scripts
        }
    }
}
