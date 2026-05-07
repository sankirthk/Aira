import AppKit
import Foundation
import OSLog
import UniformTypeIdentifiers

final class AiraLogger {
  static let shared = AiraLogger()

  private enum Level: String {
    case info = "info"
    case warning = "warning"
    case error = "error"
  }

  private static let subsystem = "com.aira.app"
  private static let maxLogSizeBytes = 1_000_000
  private static let trimTargetBytes = 500_000
  private static let dateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private let queue = DispatchQueue(label: "com.aira.logger")
  private let fileManager = FileManager.default
  private let logsDirectoryURL: URL
  private let logFileURL: URL

  private init() {
    let baseURL =
      fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    logsDirectoryURL = baseURL.appending(path: "Aira/Logs", directoryHint: .isDirectory)
    logFileURL = logsDirectoryURL.appending(path: "debug.log")
    queue.sync {
      prepareLogFileIfNeeded()
    }
  }

  var currentLogFileURL: URL {
    logFileURL
  }

  func logAppLaunch() {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    info(
      "App launched version=\(version) build=\(build) macOS=\"\(ProcessInfo.processInfo.operatingSystemVersionString)\"",
      category: "app"
    )
  }

  func info(_ message: String, category: String) {
    write(level: .info, message: message, category: category)
  }

  func warning(_ message: String, category: String) {
    write(level: .warning, message: message, category: category)
  }

  func error(_ message: String, category: String) {
    write(level: .error, message: message, category: category)
  }

  func error(_ error: Error, category: String, context: String) {
    write(level: .error, message: "\(context): \(error.localizedDescription)", category: category)
  }

  @MainActor
  func exportInteractively() {
    let panel = NSSavePanel()
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = "Aira-DebugLog-\(Self.exportDateString()).log"
    panel.allowedContentTypes = [.plainText]

    // Use begin(_:) instead of runModal() — runModal blocks the run loop and
    // fails to accept input in sandboxed App Store builds without a key window.
    panel.begin { [weak self] response in
      guard response == .OK, let destinationURL = panel.url, let self else { return }
      do {
        if self.fileManager.fileExists(atPath: destinationURL.path) {
          try self.fileManager.removeItem(at: destinationURL)
        }
        try self.fileManager.copyItem(at: self.logFileURL, to: destinationURL)
        self.info("Exported debug log", category: "logging")
      } catch {
        self.error(error, category: "logging", context: "Failed to export debug log")
      }
    }
  }

  private func write(level: Level, message: String, category: String) {
    let logger = Logger(subsystem: Self.subsystem, category: category)
    switch level {
    case .info:
      logger.info("\(message, privacy: .public)")
    case .warning:
      logger.warning("\(message, privacy: .public)")
    case .error:
      logger.error("\(message, privacy: .public)")
    }

    let line =
      "\(Self.dateFormatter.string(from: Date())) [\(category)] [\(level.rawValue)] \(message)\n"
    queue.async {
      self.prepareLogFileIfNeeded()
      self.rotateIfNeeded(forAppending: line)
      if let data = line.data(using: .utf8),
        let handle = try? FileHandle(forWritingTo: self.logFileURL)
      {
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
      }
    }
  }

  private func prepareLogFileIfNeeded() {
    try? fileManager.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
    if !fileManager.fileExists(atPath: logFileURL.path) {
      fileManager.createFile(atPath: logFileURL.path, contents: Data())
    }
  }

  private func rotateIfNeeded(forAppending line: String) {
    guard
      let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path),
      let size = attributes[.size] as? Int,
      let incomingSize = line.data(using: .utf8)?.count,
      size + incomingSize > Self.maxLogSizeBytes,
      let existingData = try? Data(contentsOf: logFileURL)
    else {
      return
    }

    let suffix = existingData.suffix(Self.trimTargetBytes)
    try? Data(suffix).write(to: logFileURL, options: .atomic)
  }

  private static func exportDateString() -> String {
    dateFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
  }
}
