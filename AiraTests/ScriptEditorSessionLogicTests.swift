import Testing
import Foundation
@testable import Aira

struct ScriptEditorSessionLogicTests {

    @Test func emptyUntitledDraftIsDiscardedOnDismiss() {
        let draft = Script(
            id: UUID(),
            title: "Untitled Script",
            body: "",
            cues: [],
            collectionIds: [],
            createdAt: Date(),
            lastEdited: Date()
        )

        let disposition = ScriptEditorSessionLogic.dismissDisposition(for: draft, persistedScript: nil)

        #expect(disposition == .discardDraft)
    }

    @Test func bodyEditedDraftIsSavedOnDismiss() {
        let draft = Script(
            id: UUID(),
            title: "Untitled Script",
            body: "Opening line",
            cues: [],
            collectionIds: [],
            createdAt: Date(),
            lastEdited: Date()
        )

        let disposition = ScriptEditorSessionLogic.dismissDisposition(for: draft, persistedScript: nil)

        #expect(disposition == .save)
    }

    @Test func retitledDraftIsSavedOnDismiss() {
        let draft = Script(
            id: UUID(),
            title: "Keynote Intro",
            body: "",
            cues: [],
            collectionIds: [],
            createdAt: Date(),
            lastEdited: Date()
        )

        let disposition = ScriptEditorSessionLogic.dismissDisposition(for: draft, persistedScript: nil)

        #expect(disposition == .save)
    }

    @Test func unchangedExistingScriptClosesWithoutSaving() {
        let persisted = Script(
            id: UUID(),
            title: "Weekly Update",
            body: "Status text",
            cues: [],
            collectionIds: [],
            createdAt: Date(),
            lastEdited: Date()
        )

        let disposition = ScriptEditorSessionLogic.dismissDisposition(for: persisted, persistedScript: persisted)

        #expect(disposition == .closeWithoutSaving)
    }

    @Test func whitespaceOnlyDraftBodyIsDiscardedOnDismiss() {
        let draft = Script(
            id: UUID(),
            title: "Untitled Script",
            body: " \n\t ",
            cues: [],
            collectionIds: [],
            createdAt: Date(),
            lastEdited: Date()
        )

        let disposition = ScriptEditorSessionLogic.dismissDisposition(for: draft, persistedScript: nil)

        #expect(disposition == .discardDraft)
    }

    @Test func existingScriptWithTitleChangeSavesOnDismiss() {
        let persisted = Script(
            id: UUID(),
            title: "Weekly Update",
            body: "Status text",
            cues: [],
            collectionIds: [],
            createdAt: Date(),
            lastEdited: Date()
        )
        var edited = persisted
        edited.title = "Weekly Wrap-Up"

        let disposition = ScriptEditorSessionLogic.dismissDisposition(for: edited, persistedScript: persisted)

        #expect(disposition == .save)
    }

    @Test func existingScriptWithBodyChangeSavesOnDismiss() {
        let persisted = Script(
            id: UUID(),
            title: "Weekly Update",
            body: "Status text",
            cues: [],
            collectionIds: [],
            createdAt: Date(),
            lastEdited: Date()
        )
        var edited = persisted
        edited.body = "Status text with changes"

        let disposition = ScriptEditorSessionLogic.dismissDisposition(for: edited, persistedScript: persisted)

        #expect(disposition == .save)
    }

    @Test func existingScriptWithOnlyCueChangesClosesWithoutSaving() {
        let persisted = Script(
            id: UUID(),
            title: "Weekly Update",
            body: "Status text",
            cues: [],
            collectionIds: [],
            createdAt: Date(),
            lastEdited: Date()
        )
        var edited = persisted
        edited.cues = [ScriptCue(type: "Pause 2s", position: 5)]

        let disposition = ScriptEditorSessionLogic.dismissDisposition(for: edited, persistedScript: persisted)

        #expect(disposition == .closeWithoutSaving)
    }
}
