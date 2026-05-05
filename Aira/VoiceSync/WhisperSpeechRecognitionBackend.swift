import Foundation
import WhisperKit

@MainActor
final class WhisperSpeechRecognitionBackend: SpeechRecognitionBackend {
  nonisolated static let requiredBundledModelFiles = [
    "AudioEncoder.mlmodelc",
    "MelSpectrogram.mlmodelc",
    "TextDecoder.mlmodelc",
    "config.json",
    "generation_config.json",
    "tokenizer.json",
    "tokenizer_config.json",
  ]
  nonisolated static let preferredBundledModelNames = [
    "openai_whisper-base.en",
    "openai_whisper-tiny.en",
  ]
  nonisolated static let maximumContextSamples = 48_000
  nonisolated static let transcriptionTriggerSamples = 8_000
  nonisolated static let sampleRate = 16_000.0
  nonisolated static let maximumEmittedTokenCacheSize = 500
  nonisolated static let emittedTokenCacheTrimCount = 100

  var onRecognizedWord: (@MainActor (SpokenWordToken) -> Void)?
  var onProcessingChanged: (@MainActor (Bool) -> Void)?

  private var whisper: WhisperKit?
  private var audioAccumulator: [Float] = []
  private var emittedTokens: [SpokenWordToken] = []
  private var isProcessing = false
  private var unprocessedSamplesCount = 0
  private var totalAcceptedSamples = 0
  private var bufferTimeOffset: TimeInterval = 0

  func prepare() async throws {
    guard whisper == nil else { return }
    guard let modelURL = Self.bundledModelURL() else {
      throw WhisperBackendError.missingBundledModel
    }
    guard Self.hasRequiredBundledModelFiles(at: modelURL) else {
      throw WhisperBackendError.incompleteBundledModel
    }

    let config = WhisperKitConfig(
      modelFolder: modelURL.path,
      verbose: false,
      prewarm: false,
      load: true,
      download: false
    )
    whisper = try await WhisperKit(config)
    AiraLogger.shared.info(
      "whisperBackend.prepared modelPath=\(modelURL.path)",
      category: "voice"
    )
  }

  func acceptAudio(_ samples: [Float]) async {
    audioAccumulator.append(contentsOf: samples)
    totalAcceptedSamples += samples.count
    unprocessedSamplesCount += samples.count
    guard unprocessedSamplesCount >= Self.transcriptionTriggerSamples else { return }
    await transcribePendingAudio()
  }

  func stop() {
    audioAccumulator = []
    emittedTokens = []
    unprocessedSamplesCount = 0
    totalAcceptedSamples = 0
    bufferTimeOffset = 0
    isProcessing = false
    whisper = nil
    onProcessingChanged?(false)
  }

  private func transcribePendingAudio() async {
    guard !isProcessing, let whisper else { return }
    isProcessing = true
    onProcessingChanged?(true)
    let audio = audioAccumulator
    let currentBufferTimeOffset = bufferTimeOffset
    let acceptedSamplesAtSnapshot = totalAcceptedSamples

    do {
      let options = DecodingOptions(language: "en", wordTimestamps: true)
      let results = try await whisper.transcribe(audioArray: audio, decodeOptions: options)
      let words = results.flatMap(\.allWords)
      AiraLogger.shared.info(
        "whisperBackend.transcribed samples=\(audio.count) segments=\(results.count) words=\(words.count)",
        category: "voice"
      )
      if words.isEmpty {
        AiraLogger.shared.info("whisperBackend.noWordsEmitted", category: "voice")
      }
      for word in words {
        let absoluteStart = currentBufferTimeOffset + TimeInterval(word.start)
        guard !isDuplicateEmission(word: word.word, timestamp: absoluteStart) else { continue }
        let token = SpokenWordToken(
          word: word.word,
          timestamp: absoluteStart,
          confidence: word.probability
        )
        emittedTokens.append(token)
        if emittedTokens.count > Self.maximumEmittedTokenCacheSize {
          emittedTokens.removeFirst(min(Self.emittedTokenCacheTrimCount, emittedTokens.count))
        }
        AiraLogger.shared.info(
          "whisperBackend.emit word=\"\(word.word)\" start=\(absoluteStart) confidence=\(word.probability)",
          category: "voice"
        )
        onRecognizedWord?(token)
      }
    } catch {
      AiraLogger.shared.error(error, category: "voice", context: "Whisper transcription failed")
    }

    if audioAccumulator.count > Self.maximumContextSamples {
      let excess = audioAccumulator.count - Self.maximumContextSamples
      audioAccumulator.removeFirst(excess)
      bufferTimeOffset += TimeInterval(excess) / Self.sampleRate
    }
    unprocessedSamplesCount = max(totalAcceptedSamples - acceptedSamplesAtSnapshot, 0)
    isProcessing = false
    onProcessingChanged?(false)
  }

  private func isDuplicateEmission(word: String, timestamp: TimeInterval) -> Bool {
    let normalizedWord = Self.normalizedWord(word)
    guard !normalizedWord.isEmpty else { return false }
    return emittedTokens.contains { token in
      Self.normalizedWord(token.word) == normalizedWord && abs(token.timestamp - timestamp) < 1.0
    }
  }

  private static func normalizedWord(_ word: String) -> String {
    word.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
  }

  private static func bundledModelURL() -> URL? {
    for modelName in preferredBundledModelNames {
      if let url = bundledModelResourceURL(for: modelName) {
        return url
      }
      if let url = Bundle.main.url(
        forResource: modelName,
        withExtension: nil,
        subdirectory: "Whisper"
      ) {
        return url
      }
      if let url = Bundle.main.url(
        forResource: modelName,
        withExtension: nil,
        subdirectory: "Models/Whisper"
      ) {
        return url
      }
    }
    return nil
  }

  private static func bundledModelResourceURL(for modelName: String) -> URL? {
    guard
      let bundleURL = Bundle.main.url(forResource: "WhisperModels", withExtension: "bundle"),
      let bundle = Bundle(url: bundleURL)
    else { return nil }

    return bundle.url(
      forResource: modelName,
      withExtension: nil,
      subdirectory: "Whisper"
    )
  }

  nonisolated static func hasRequiredBundledModelFiles(at modelURL: URL) -> Bool {
    let fileManager = FileManager.default
    return requiredBundledModelFiles.allSatisfy { fileName in
      fileManager.fileExists(atPath: modelURL.appendingPathComponent(fileName).path)
    }
  }
}

enum WhisperBackendError: Error {
  case missingBundledModel
  case incompleteBundledModel
}
