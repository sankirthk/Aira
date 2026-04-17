import Foundation

enum SelectAllControlState: Equatable {
  case none
  case mixed
  case all
}

enum DocumentLibrarySelectionModifier {
  case none
  case command
  case shift
}

struct DocumentLibraryBulkSelection {
  var selectedScriptIDs: Set<UUID> = []
  var lastSelectedScriptID: UUID? = nil

  var isSelectionMode: Bool {
    !selectedScriptIDs.isEmpty
  }

  func selectAllState(visibleScriptIDs: [UUID]) -> SelectAllControlState {
    guard !visibleScriptIDs.isEmpty else {
      return .none
    }

    let visibleSelectionCount = visibleScriptIDs.filter { selectedScriptIDs.contains($0) }.count
    if visibleSelectionCount == 0 {
      return .none
    }
    if visibleSelectionCount == visibleScriptIDs.count {
      return .all
    }
    return .mixed
  }

  mutating func toggleSelectAll(visibleScriptIDs: [UUID]) {
    switch selectAllState(visibleScriptIDs: visibleScriptIDs) {
    case .none:
      selectedScriptIDs = Set(visibleScriptIDs)
      lastSelectedScriptID = visibleScriptIDs.last
    case .mixed, .all:
      clear()
    }
  }

  mutating func handleCardSelection(
    for scriptID: UUID,
    visibleScriptIDs: [UUID],
    modifier: DocumentLibrarySelectionModifier
  ) {
    switch modifier {
    case .none:
      break
    case .command:
      toggleSingle(scriptID)
    case .shift:
      selectRange(to: scriptID, visibleScriptIDs: visibleScriptIDs)
    }
  }

  mutating func toggleSingle(_ scriptID: UUID) {
    if selectedScriptIDs.contains(scriptID) {
      selectedScriptIDs.remove(scriptID)
    } else {
      selectedScriptIDs.insert(scriptID)
    }

    lastSelectedScriptID = scriptID
    if selectedScriptIDs.isEmpty {
      lastSelectedScriptID = nil
    }
  }

  mutating func resolveBulkDeleteConfirmation(
    confirm: Bool,
    delete: (UUID) throws -> Void
  ) rethrows {
    guard confirm else {
      return
    }

    for scriptID in selectedScriptIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
      try delete(scriptID)
    }

    clear()
  }

  mutating func clear() {
    selectedScriptIDs.removeAll()
    lastSelectedScriptID = nil
  }

  private mutating func selectRange(to scriptID: UUID, visibleScriptIDs: [UUID]) {
    guard
      let targetIndex = visibleScriptIDs.firstIndex(of: scriptID)
    else {
      return
    }

    let anchorID = lastSelectedScriptID ?? scriptID
    guard let anchorIndex = visibleScriptIDs.firstIndex(of: anchorID) else {
      selectedScriptIDs.insert(scriptID)
      lastSelectedScriptID = scriptID
      return
    }

    let lowerBound = min(anchorIndex, targetIndex)
    let upperBound = max(anchorIndex, targetIndex)
    selectedScriptIDs.formUnion(visibleScriptIDs[lowerBound...upperBound])
    lastSelectedScriptID = scriptID
  }
}
