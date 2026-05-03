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

  var onRecognizedWord: (@MainActor (SpokenWordToken) -> Void)?
  var onProcessingChanged: (@MainActor (Bool) -> Void)?

  private var whisper: WhisperKit?
  private var audioAccumulator: [Float] = []
  private var emittedWords: Set<String> = []
  private var isProcessing = false
  private let chunkSize = 16_000
  private let overlapSize = 8_000

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
    guard audioAccumulator.count >= chunkSize else { return }
    await transcribePendingAudio()
  }

  func stop() {
    audioAccumulator = []
    emittedWords = []
    isProcessing = false
    whisper = nil
    onProcessingChanged?(false)
  }

  private func transcribePendingAudio() async {
    guard !isProcessing, let whisper else { return }
    isProcessing = true
    onProcessingChanged?(true)
    let audio = audioAccumulator

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
        let key = "\(word.start)-\(word.word)"
        guard !emittedWords.contains(key) else { continue }
        emittedWords.insert(key)
        AiraLogger.shared.info(
          "whisperBackend.emit word=\"\(word.word)\" start=\(word.start) confidence=\(word.probability)",
          category: "voice"
        )
        onRecognizedWord?(
          SpokenWordToken(
            word: word.word,
            timestamp: TimeInterval(word.start),
            confidence: word.probability
          )
        )
      }
    } catch {
      AiraLogger.shared.error(error, category: "voice", context: "Whisper transcription failed")
    }

    if audioAccumulator.count > overlapSize {
      audioAccumulator.removeFirst(audioAccumulator.count - overlapSize)
    }
    isProcessing = false
    onProcessingChanged?(false)
  }

  private static func bundledModelURL() -> URL? {
    Bundle.main.url(
      forResource: "openai_whisper-tiny.en",
      withExtension: nil,
      subdirectory: "Whisper"
    )
      ?? Bundle.main.url(
        forResource: "openai_whisper-tiny.en",
        withExtension: nil,
        subdirectory: "Models/Whisper"
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
