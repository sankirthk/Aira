import Foundation

class CollectionStore {
  private let collectionsURL: URL

  convenience init() {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!.appending(path: "Aira")
    self.init(directory: appSupport)
  }

  init(directory: URL) {
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    collectionsURL = directory.appending(path: "collections.json")
  }

  func loadAll() throws -> [AiraCollection] {
    guard FileManager.default.fileExists(atPath: collectionsURL.path) else { return [] }
    let data = try Data(contentsOf: collectionsURL)
    return try JSONDecoder().decode([AiraCollection].self, from: data)
  }

  private func saveAll(_ collections: [AiraCollection]) throws {
    let data = try JSONEncoder().encode(collections)
    try data.write(to: collectionsURL, options: .atomic)
  }

  func replaceAll(_ collections: [AiraCollection]) throws {
    try saveAll(collections)
  }

  func create(name: String) throws -> AiraCollection {
    var all = try loadAll()
    let collection = AiraCollection(id: UUID(), name: name, scriptIds: [])
    all.append(collection)
    try saveAll(all)
    return collection
  }

  func rename(id: UUID, to name: String) throws {
    var all = try loadAll()
    guard let i = all.firstIndex(where: { $0.id == id }) else { return }
    all[i].name = name
    try saveAll(all)
  }

  func delete(id: UUID) throws {
    var all = try loadAll()
    all.removeAll { $0.id == id }
    try saveAll(all)
  }

  func addScript(_ scriptId: UUID, toCollection collectionId: UUID) throws {
    var all = try loadAll()
    guard let i = all.firstIndex(where: { $0.id == collectionId }) else { return }
    if !all[i].scriptIds.contains(scriptId) {
      all[i].scriptIds.append(scriptId)
    }
    try saveAll(all)
  }

  func removeScript(_ scriptId: UUID, fromCollection collectionId: UUID) throws {
    var all = try loadAll()
    guard let i = all.firstIndex(where: { $0.id == collectionId }) else { return }
    all[i].scriptIds.removeAll { $0 == scriptId }
    try saveAll(all)
  }
}
