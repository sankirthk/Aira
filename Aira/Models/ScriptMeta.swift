import Foundation

/// Lightweight index entry loaded on app launch — no script body.
struct ScriptMeta: Codable, Identifiable {
    let id: UUID
    var title: String
    var lastEdited: Date
    var wordCount: Int
    var starred: Bool
}
