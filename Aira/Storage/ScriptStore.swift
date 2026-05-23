import AppKit
import Foundation
import PDFKit

class ScriptStore {
  private static let maxImportFileSize = 10_000_000

  private let scriptsURL: URL
  private let indexURL: URL

  private static func indexedWordCount(for body: String) -> Int {
    body.split(whereSeparator: \.isWhitespace).count
  }

  static func defaultScriptsDirectory(
    fileManager: FileManager = .default,
    applicationSupportDirectory: () -> URL? = {
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }
  ) -> URL {
    let baseDirectory =
      applicationSupportDirectory()
      ?? {
        let fallback = fileManager.homeDirectoryForCurrentUser
          .appending(path: "Library/Application Support", directoryHint: .isDirectory)
        AiraLogger.shared.warning(
          "Application Support lookup failed; using fallback script storage directory",
          category: "storage"
        )
        return fallback
      }()

    return baseDirectory.appending(path: "Aira/Scripts", directoryHint: .isDirectory)
  }

  /// Production init — uses ~/Library/Application Support/Aira/Scripts/
  convenience init() {
    self.init(directory: Self.defaultScriptsDirectory())
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
    try data.write(to: indexURL, options: .atomic)
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
    try data.write(to: url, options: .atomic)

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
    let format = try ImportFormat(url: url)
    let isSecurityScoped = url.startAccessingSecurityScopedResource()
    defer { if isSecurityScoped { url.stopAccessingSecurityScopedResource() } }

    guard FileManager.default.isReadableFile(atPath: url.path) else {
      throw ImportError.accessDenied
    }

    let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
    if let size = attrs[.size] as? Int, size > Self.maxImportFileSize {
      throw ImportError.fileTooLarge
    }

    let content = try importedText(from: url, format: format)
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

  /// Extracts plain text from a supported file (txt, pdf, docx) without creating a script.
  func extractText(from url: URL) throws -> String {
    let format = try ImportFormat(url: url)
    let isSecurityScoped = url.startAccessingSecurityScopedResource()
    defer { if isSecurityScoped { url.stopAccessingSecurityScopedResource() } }

    guard FileManager.default.isReadableFile(atPath: url.path) else {
      throw ImportError.accessDenied
    }

    let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
    if let size = attrs[.size] as? Int, size > Self.maxImportFileSize {
      throw ImportError.fileTooLarge
    }

    return try importedText(from: url, format: format)
  }

  private func importedText(from url: URL, format: ImportFormat) throws -> String {
    let text: String

    switch format {
    case .plainText:
      text = try String(contentsOf: url, encoding: .utf8)
    case .pdf:
      guard let document = PDFDocument(url: url) else {
        throw ImportError.unreadableDocument
      }

      let pageText = (0..<document.pageCount).compactMap { index in
        document.page(at: index)?.string
      }
      text = pageText.joined(separator: "\n\n")
    case .docx:
      let attributed = try NSAttributedString(
        url: url,
        options: [.documentType: NSAttributedString.DocumentType.officeOpenXML],
        documentAttributes: nil
      )
      text = attributed.string
    }

    return normalizedImportedText(text)
  }

  private func normalizedImportedText(_ text: String) -> String {
    text
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .replacingOccurrences(of: "\u{00A0}", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private enum ImportFormat {
    case plainText
    case pdf
    case docx

    init(url: URL) throws {
      switch url.pathExtension.lowercased() {
      case "txt":
        self = .plainText
      case "pdf":
        self = .pdf
      case "docx":
        self = .docx
      default:
        throw ImportError.unsupportedType
      }
    }
  }

  enum ImportError: LocalizedError {
    case accessDenied
    case fileTooLarge
    case unsupportedType
    case unreadableDocument

    var errorDescription: String? {
      switch self {
      case .accessDenied: return "Aira could not access that file."
      case .fileTooLarge: return "File is too large to import (max 10 MB)."
      case .unsupportedType: return "Only .txt, .pdf, and .docx files can be imported."
      case .unreadableDocument: return "Aira could not extract text from that document."
      }
    }
  }
}
