import Foundation

class ScriptStore {
    private static let maxImportFileSize = 10_000_000

    private let scriptsURL: URL
    private let indexURL: URL

    private static func indexedWordCount(for body: String) -> Int {
        body.split(whereSeparator: \.isWhitespace).count
    }

    /// Production init — uses ~/Library/Application Support/Aira/Scripts/
    convenience init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appending(path: "Aira/Scripts")
        self.init(directory: appSupport)
    }

    /// Testable init — uses the provided directory
    init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        scriptsURL = directory
        indexURL = directory.appending(path: "index.json")
    }

    // MARK: - Index

    func loadIndex() throws -> [ScriptMeta] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return [] }
        let data = try Data(contentsOf: indexURL)
        return try JSONDecoder().decode([ScriptMeta].self, from: data)
    }

    func saveIndex(_ index: [ScriptMeta]) throws {
        let data = try JSONEncoder().encode(index)
        try data.write(to: indexURL)
    }

    // MARK: - CRUD

    func load(id: UUID) throws -> Script {
        let url = scriptsURL.appending(path: "\(id.uuidString).json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Script.self, from: data)
    }

    func save(_ script: Script) throws {
        let url = scriptsURL.appending(path: "\(script.id.uuidString).json")
        let data = try JSONEncoder().encode(script)
        try data.write(to: url)

        var index = try loadIndex()
        let existingStarred = index.first(where: { $0.id == script.id })?.starred ?? false
        let meta = ScriptMeta(
            id: script.id,
            title: script.title,
            lastEdited: script.lastEdited,
            wordCount: Self.indexedWordCount(for: script.body),
            starred: existingStarred
        )
        if let i = index.firstIndex(where: { $0.id == script.id }) {
            index[i] = meta
        } else {
            index.append(meta)
        }
        try saveIndex(index)
    }

    func delete(id: UUID) throws {
        let url = scriptsURL.appending(path: "\(id.uuidString).json")
        try FileManager.default.removeItem(at: url)

        var index = try loadIndex()
        index.removeAll { $0.id == id }
        try saveIndex(index)
    }

    func duplicate(id: UUID) throws -> Script {
        var source = try load(id: id)
        source = Script(
            id: UUID(),
            title: "Copy of \(source.title)",
            body: source.body,
            cues: source.cues,
            collectionIds: source.collectionIds,
            createdAt: Date(),
            lastEdited: Date()
        )
        try save(source)
        return source
    }

    func toggleStarred(id: UUID) throws -> ScriptMeta? {
        var index = try loadIndex()
        guard let i = index.firstIndex(where: { $0.id == id }) else { return nil }

        index[i].starred.toggle()
        try saveIndex(index)
        return index[i]
    }

    // MARK: - Import

    func importFromURL(_ url: URL) throws -> Script {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer { if isSecurityScoped { url.stopAccessingSecurityScopedResource() } }

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attrs[.size] as? Int, size > Self.maxImportFileSize {
            throw ImportError.fileTooLarge
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        let title = url.deletingPathExtension().lastPathComponent
        let script = Script(
            id: UUID(),
            title: title,
            body: content,
            cues: [],
            collectionIds: [],
            createdAt: Date(),
            lastEdited: Date()
        )
        try save(script)
        return script
    }

    enum ImportError: LocalizedError {
        case accessDenied
        case fileTooLarge

        var errorDescription: String? {
            switch self {
            case .accessDenied:  return "Aira could not access that file."
            case .fileTooLarge:  return "File is too large to import (max 10 MB)."
            }
        }
    }
}
