import AVFoundation
import Combine
import Foundation

/// Reads RMS level from the shared AVAudioEngine and publishes it for VisualBeamView.
/// Installed on the same engine instance owned by VoiceSyncEngine.
@MainActor
class AudioLevelMonitor: ObservableObject {
  @Published var level: Float = 0.0  // 0.0–1.0 normalized
  @Published var isSpeaking: Bool = false
  var sensitivity: SpeechSensitivity = .medium
  private let visualMeterTargetPeak: Float = 0.12
  private let maxVisualMeterGain: Float = 10
  private let visualMeterBaseScale: Float = 12
  private let visualMeterCurveExponent: Float = 0.72

  private let hangTime: TimeInterval = 0.9
  private var lastSpokenTime: Date = .distantPast
  private var thresholdCrossedTime: Date?

  func processBuffer(_ buffer: AVAudioPCMBuffer) {
    let currentLevel = calculateRMS(buffer: buffer)
    level = currentLevel

    let now = Date()
    if currentLevel > speakingThreshold {
      if thresholdCrossedTime == nil {
        thresholdCrossedTime = now
      }
      if now.timeIntervalSince(thresholdCrossedTime ?? now) >= activationHoldTime {
        lastSpokenTime = now
        if !isSpeaking {
          isSpeaking = true
        }
      }
    } else {
      thresholdCrossedTime = nil
      if isSpeaking && now.timeIntervalSince(lastSpokenTime) > hangTime {
        isSpeaking = false
      }
    }
  }

  func reset() {
    level = 0
    isSpeaking = false
    lastSpokenTime = .distantPast
    thresholdCrossedTime = nil
  }

  static func speakingThreshold(for sensitivity: SpeechSensitivity) -> Float {
    switch sensitivity {
    case .low:
      return 0.35
    case .medium:
      return 0.20
    case .high:
      return 0.12
    }
  }

  private var speakingThreshold: Float {
    Self.speakingThreshold(for: sensitivity)
  }

  private var activationHoldTime: TimeInterval {
    switch sensitivity {
    case .low:
      return 0.18
    case .medium:
      return 0.1
    case .high:
      return 0.04
    }
  }

  private func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
    guard
      let channelData = buffer.floatChannelData,
      let dominantChannelIndex = VoiceSyncRecognitionInput.dominantChannelIndex(for: buffer)
    else { return 0 }
    let frameCount = Int(buffer.frameLength)
    var sum: Float = 0
    var peak: Float = 0
    for i in 0..<frameCount {
      let sample = channelData[dominantChannelIndex][i]
      sum += sample * sample
      peak = max(peak, abs(sample))
    }
    let rms = sqrt(sum / Float(max(frameCount, 1)))
    let gain = visualMeterGain(forPeak: peak)
    let scaledLevel = min(rms * visualMeterBaseScale * gain, 1.0)
    return pow(scaledLevel, visualMeterCurveExponent)
  }

  private func visualMeterGain(forPeak peak: Float) -> Float {
    guard peak > 0 else { return 1 }
    return max(1, min(maxVisualMeterGain, visualMeterTargetPeak / peak))
  }
}
