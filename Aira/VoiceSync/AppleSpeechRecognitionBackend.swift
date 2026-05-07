import AVFoundation
import Foundation
import Speech

@MainActor
final class AppleSpeechRecognitionBackend: PartialSpeechRecognitionBackend {
  var onRecognizedWord: (@MainActor (SpokenWordToken) -> Void)?
  var onRecognizedWords: (@MainActor ([VoiceSyncMatching.RecognizedWord], Bool) -> Void)?
  var onProcessingChanged: (@MainActor (Bool) -> Void)?

  private let recognizer: SFSpeechRecognizer?
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var generation: UInt64 = 0

  init(locale: Locale = .current) {
    recognizer = SFSpeechRecognizer(locale: locale)
  }

  func prepare() async throws {
    let status = SFSpeechRecognizer.authorizationStatus()
    let resolvedStatus =
      status == .notDetermined
      ? await Self.requestAuthorization()
      : status
    guard resolvedStatus == .authorized else {
      throw AppleSpeechRecognitionBackendError.notAuthorized
    }
    restartRecognitionTask()
  }

  func acceptAudio(_ samples: [Float]) async {
    guard let request, !samples.isEmpty else { return }
    guard
      let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: VoiceSyncRecognitionInput.targetSampleRate,
        channels: 1,
        interleaved: false
      ),
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: AVAudioFrameCount(samples.count)
      ),
      let channel = buffer.floatChannelData?[0]
    else { return }

    buffer.frameLength = AVAudioFrameCount(samples.count)
    samples.withUnsafeBufferPointer { source in
      channel.update(from: source.baseAddress!, count: samples.count)
    }
    request.append(buffer)
  }

  func stop() {
    generation &+= 1
    recognitionTask?.cancel()
    recognitionTask = nil
    request?.endAudio()
    request = nil
    onProcessingChanged?(false)
  }

  private func restartRecognitionTask() {
    generation &+= 1
    recognitionTask?.cancel()

    let nextRequest = SFSpeechAudioBufferRecognitionRequest()
    nextRequest.requiresOnDeviceRecognition = true
    nextRequest.shouldReportPartialResults = true
    nextRequest.addsPunctuation = false
    request = nextRequest

    let taskGeneration = generation
    recognitionTask = recognizer?.recognitionTask(with: nextRequest) { [weak self] result, error in
      guard let self else { return }
      if let result {
        Task { @MainActor [weak self] in
          guard let self, taskGeneration == self.generation else { return }
          let words = VoiceSyncMatching.recognizedWords(from: result.bestTranscription.segments)
          self.onProcessingChanged?(!words.isEmpty)
          self.onRecognizedWords?(words, result.isFinal)
          if result.isFinal {
            self.restartRecognitionTask()
          }
        }
      }

      if let error {
        let nsError = error as NSError
        let ignoredCodes = [216, 301, 1110]
        guard !ignoredCodes.contains(nsError.code) else { return }
        Task { @MainActor [weak self] in
          guard let self, taskGeneration == self.generation else { return }
          AiraLogger.shared.error(
            nsError, category: "voice", context: "Apple speech recognition failed")
          self.restartRecognitionTask()
        }
      }
    }
  }

  private static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
    await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status)
      }
    }
  }
}

enum AppleSpeechRecognitionBackendError: Error {
  case notAuthorized
}

extension VoiceSyncMatching {
  fileprivate static func recognizedWords(
    from segments: [SFTranscriptionSegment]
  ) -> [RecognizedWord] {
    segments.compactMap { segment in
      guard let token = normalizeToken(segment.substring) else { return nil }
      return RecognizedWord(token: token, confidence: segment.confidence)
    }
  }
}
