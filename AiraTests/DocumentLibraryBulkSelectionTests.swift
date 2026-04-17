import Foundation
import Testing

@testable import Aira

struct DocumentLibraryBulkSelectionTests {

  @Test func selectingAllScriptsSetsSelectedScriptIDsToFullVisibleSet() {
    let visibleIDs = [UUID(), UUID(), UUID()]
    var selection = DocumentLibraryBulkSelection()

    selection.toggleSelectAll(visibleScriptIDs: visibleIDs)

    #expect(selection.selectedScriptIDs == Set(visibleIDs))
    #expect(selection.selectAllState(visibleScriptIDs: visibleIDs) == .all)
  }

  @Test func deselectingOneAfterSelectAllLeavesMixedState() {
    let visibleIDs = [UUID(), UUID(), UUID()]
    var selection = DocumentLibraryBulkSelection()
    selection.toggleSelectAll(visibleScriptIDs: visibleIDs)

    selection.toggleSingle(visibleIDs[1])

    #expect(selection.selectedScriptIDs == Set([visibleIDs[0], visibleIDs[2]]))
    #expect(selection.selectAllState(visibleScriptIDs: visibleIDs) == .mixed)
  }

  @Test func shiftClickSelectsInclusiveRange() {
    let visibleIDs = [UUID(), UUID(), UUID(), UUID(), UUID()]
    var selection = DocumentLibraryBulkSelection()
    selection.toggleSingle(visibleIDs[1])

    selection.handleCardSelection(
      for: visibleIDs[4],
      visibleScriptIDs: visibleIDs,
      modifier: .shift
    )

    #expect(selection.selectedScriptIDs == Set(Array(visibleIDs[1...4])))
  }

  @Test func confirmingBulkDeleteDeletesEachSelectedScriptAndClearsSelection() {
    let ids = [UUID(), UUID(), UUID()]
    var deletedIDs: [UUID] = []
    var selection = DocumentLibraryBulkSelection(
      selectedScriptIDs: Set(ids),
      lastSelectedScriptID: ids[2]
    )

    selection.resolveBulkDeleteConfirmation(confirm: true) { id in
      deletedIDs.append(id)
    }

    #expect(Set(deletedIDs) == Set(ids))
    #expect(selection.selectedScriptIDs.isEmpty)
    #expect(selection.lastSelectedScriptID == nil)
  }

  @Test func cancellingBulkDeleteLeavesSelectionUnchanged() {
    let ids = [UUID(), UUID()]
    var deletedIDs: [UUID] = []
    var selection = DocumentLibraryBulkSelection(
      selectedScriptIDs: Set(ids),
      lastSelectedScriptID: ids[1]
    )

    selection.resolveBulkDeleteConfirmation(confirm: false) { id in
      deletedIDs.append(id)
    }

    #expect(deletedIDs.isEmpty)
    #expect(selection.selectedScriptIDs == Set(ids))
    #expect(selection.lastSelectedScriptID == ids[1])
  }
}
