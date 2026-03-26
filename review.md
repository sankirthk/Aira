# Review Tracker

This file tracks review findings as they come in and whether each issue is still open.

Status values:
- `open` — not fixed yet
- `resolved` — fixed and verified in code/tests
- `dismissed` — review was stale, incorrect, or not applicable to the current workspace

## Active Reviews

| Review Date | Area | Severity | File | Finding | Status | Notes |
|---|---|---|---|---|---|---|
| 2026-03-25 | Data Layer | P2 | `Aira/Storage/ScriptStore.swift` | Count indexed words using all whitespace, not just spaces | `resolved` | Fixed in `ScriptStore` and covered by `UT-003a`. |
| 2026-03-25 | Data Layer | P2 | `Aira/Storage/ScriptStore.swift` | Preserve collection membership when duplicating a script | `resolved` | `collectionIds` now persist on duplicate; later sync into `CollectionStore` was added too. |
| 2026-03-25 | Document Library | P1 | `Aira/ManagerWindow/Sidebar/SidebarView.swift` | New Script button not wired | `dismissed` | Verified stale review; button already routed through `ManagerWindowView.createAndOpenScript()`. |
| 2026-03-25 | Document Library | P1 | `Aira/ManagerWindow/DocumentLibrary/DocumentLibraryView.swift` | Drag-and-drop import not implemented | `dismissed` | Verified stale review; `.onDrop` imports and opens the script editor. |
| 2026-03-25 | Document Library | P1 | `Aira/ManagerWindow/DocumentLibrary/DocumentLibraryView.swift` | File-picker import missing | `dismissed` | Verified stale review; Import Script button is present and wired to `NSOpenPanel`. |
| 2026-03-25 | Document Library | P1 | `Aira/ManagerWindow/DocumentLibrary/ScriptCardView.swift` | Edit action not wired | `dismissed` | Verified stale review; edit loads the script and opens the editor. |
| 2026-03-25 | Document Library | P1 | `Aira/ManagerWindow/DocumentLibrary/ScriptCardView.swift` | Duplicate action not wired | `dismissed` | Verified stale review; duplicate works and opens the copy in the editor. |
| 2026-03-25 | Document Library | P1 | `Aira/ManagerWindow/DocumentLibrary/ScriptCardView.swift` | Delete action not wired | `dismissed` | Verified stale review; delete is confirmed and then executed. |
| 2026-03-25 | Document Library | P2 | `Aira/ManagerWindow/DocumentLibrary/DocumentLibraryView.swift` | Bulk selection model missing | `dismissed` | Verified stale review; selection state, range select, bulk delete, and Escape clear are implemented. |
| 2026-03-25 | Collections | P1 | `Aira/ManagerWindow/Sidebar/CollectionSidebarLogic.swift` | Collection filter drops duplicated scripts because duplicated IDs were not synced back into `CollectionStore` | `resolved` | Fixed in `AppState.duplicateScript(id:)` by syncing duplicate IDs into each preserved collection and refreshing collections. |
| 2026-03-25 | Script Editor | P2 | `Aira/ManagerWindow/ScriptEditor/ScriptEditorTextInsertion.swift` | Cue insertions render as plain body text instead of visually distinct annotations | `resolved` | Editor now restyles bracketed cue tokens inline in `NSTextView`; covered by cue-styling tests. |
| 2026-03-25 | Editor Lifecycle | P1 | `Aira/ManagerWindow/ManagerWindowView.swift` | Starting a new draft from the sidebar can discard unsaved editor changes | `resolved` | Verified current `createAndOpenScript()` first calls `dismissEditor()`; dismiss behavior is covered by `ScriptEditorSessionLogicTests`. |
| 2026-03-25 | Session Safety | P2 | `Aira/ManagerWindow/DocumentLibrary/DocumentLibraryView.swift` | Bulk deletion remains available during an active presenter session | `resolved` | Verified current session rules disable bulk selection/deletion during active sessions, and deletion/edit restrictions are covered by `DocumentLibrarySessionRulesTests`. |
| 2026-03-25 | Overlay Lifecycle | P1 | `Aira/OverlayWindows/OverlayWindowController.swift` | Closing the final pill in a pill-only session leaves the shared voice/audio pipeline running | `resolved` | Shared-session teardown now runs whenever the last overlay disappears, so pill-only shutdown also stops `voiceSync`, resets audio monitoring, clears primary metrics, and ends the playhead session. |
| 2026-03-25 | Overlay Launch | P1 | `Aira/OverlayWindows/OverlayWindowController.swift` | Launching a session with a manual pill can reload `VoiceSyncEngine` with the wrong script | `resolved` | Shared session setup is now keyed off actual overlay presence (`hasActiveOverlays`) instead of `appState.sessionActive`, so launch-time manual pills no longer overwrite the notch session's voice-sync script. |
| 2026-03-25 | Script Editor | P2 | `Aira/ManagerWindow/ScriptEditor/ScriptEditorView.swift` | Editor word count and duration undercount scripts containing newlines or tabs | `resolved` | The editor now counts words using all whitespace separators, matching `ScriptStore`, with focused coverage for multiline/tab-separated scripts. |
| 2026-03-25 | Collections | P2 | `Aira/App/AppState.swift` | Deleting a collection leaves orphaned collection IDs in persisted script files | `resolved` | `AppState.deleteCollection(id:)` now removes the deleted collection ID from affected scripts before refreshing state, with regression coverage. |

## Update Notes

When a new review comes in:
1. Add one row per finding.
2. Keep the original area, severity, file, and summary concise.
3. Update `Status` when the issue is fixed or dismissed.
4. Add a short note describing the fix or why the finding was dismissed.
