import Foundation

struct SpokenWordToken: Equatable {
  let word: String
  let timestamp: TimeInterval
  let confidence: Float?
}

@MainActor
protocol SpeechRecognitionBackend: AnyObject {
  var onRecognizedWord: (@MainActor (SpokenWordToken) -> Void)? { get set }
  var onProcessingChanged: (@MainActor (Bool) -> Void)? { get set }

  func prepare() async throws
  func acceptAudio(_ samples: [Float]) async
  func stop()
}
