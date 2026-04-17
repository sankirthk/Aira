import Foundation

struct Script: Codable, Identifiable {
  let id: UUID
  var title: String
  var body: String
  var cues: [ScriptCue]
  var collectionIds: [UUID]
  let createdAt: Date
  var lastEdited: Date
}

struct ScriptCue: Codable, Equatable {
  var type: String  // e.g. "Smile", "Pause 2s", "Breathe"
  var position: Int  // character offset in body
}
