import Foundation

/// Named group of scripts. Named AiraCollection to avoid conflict with Swift's Collection protocol.
struct AiraCollection: Codable, Identifiable {
  let id: UUID
  var name: String
  var scriptIds: [UUID]
}
