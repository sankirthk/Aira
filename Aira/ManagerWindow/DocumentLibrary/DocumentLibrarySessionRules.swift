import Foundation

enum DocumentLibrarySessionRules {
    static func showsBulkSelectionControls(sessionActive: Bool, visibleScriptCount: Int) -> Bool {
        !sessionActive && visibleScriptCount > 0
    }

    static func allowsDeletion(sessionActive: Bool) -> Bool {
        !sessionActive
    }

    static func allowsEditing(scriptID: UUID, activeSessionScriptIDs: Set<UUID>) -> Bool {
        !activeSessionScriptIDs.contains(scriptID)
    }
}
