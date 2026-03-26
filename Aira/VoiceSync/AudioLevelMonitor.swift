import Foundation
import AVFoundation
import Combine

/// Reads RMS level from the shared AVAudioEngine and publishes it for VisualBeamView.
/// Installed on the same engine instance owned by VoiceSyncEngine.
@MainActor
class AudioLevelMonitor: ObservableObject {
    @Published var level: Float = 0.0  // 0.0–1.0 normalized
    @Published var isSpeaking: Bool = false
    var sensitivity: SpeechSensitivity = .medium

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

    private var speakingThreshold: Float {
        switch sensitivity {
        case .low:
            return 0.20
        case .medium:
            return 0.11
        case .high:
            return 0.06
        }
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
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameCount = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameCount {
            let sample = channelData[0][i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(max(frameCount, 1)))
        // Normalize to 0–1 with a reasonable ceiling
        return min(rms * 10, 1.0)
    }
}
