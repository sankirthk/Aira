import Foundation
import Testing

@testable import Aira

struct DocumentLibrarySessionRulesTests {

  @Test func bulkSelectionControlsHideDuringActiveSession() {
    #expect(
      DocumentLibrarySessionRules.showsBulkSelectionControls(
        sessionActive: false, visibleScriptCount: 3))
    #expect(
      !DocumentLibrarySessionRules.showsBulkSelectionControls(
        sessionActive: true, visibleScriptCount: 3))
    #expect(
      !DocumentLibrarySessionRules.showsBulkSelectionControls(
        sessionActive: false, visibleScriptCount: 0))
  }

  @Test func editingIsBlockedOnlyForScriptsUsedByActiveSession() {
    let activeID = UUID()
    let otherID = UUID()

    #expect(
      !DocumentLibrarySessionRules.allowsEditing(
        scriptID: activeID,
        activeSessionScriptIDs: [activeID]
      )
    )
    #expect(
      DocumentLibrarySessionRules.allowsEditing(
        scriptID: otherID,
        activeSessionScriptIDs: [activeID]
      )
    )
  }

  @Test func deletionIsBlockedDuringActiveSession() {
    #expect(DocumentLibrarySessionRules.allowsDeletion(sessionActive: false))
    #expect(!DocumentLibrarySessionRules.allowsDeletion(sessionActive: true))
  }
}
