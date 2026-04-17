import AppKit
import SwiftUI

@MainActor
class CinematicScrollController {
  var onScrollTick: ((CGFloat) -> Void)?

  private var scrollTask: Task<Void, Never>?
  private var isSpeaking: Bool = false
  private var autoScrollWPM: Double = 135
  private var contentHeight: CGFloat = 0
  private var viewportHeight: CGFloat = 0
  private var fontSize: CGFloat = 20
  private var pointsPerWord: Double = 0
  private var anchorOffset: CGFloat? = nil
  private var currentScrollOffset: CGFloat = 0

  private var lastFrameTime: CFTimeInterval = 0
  private let postSpeechGlideDuration: Double = 0.42
  private let voiceSpeedMultiplier: Double = 1.18
  private let speakingCatchUpFactorRange: ClosedRange<Double> = 1.0...2.6
  private let glideCatchUpFactorRange: ClosedRange<Double> = 1.0...1.2
  private let postGlideGapSpeedMultiplier: Double = 1.6
  private var remainingPostSpeechGlide: Double = 0

  func configure(
    wpm: Double,
    contentHeight: CGFloat,
    viewportHeight: CGFloat,
    fontSize: CGFloat,
    pointsPerWord: Double
  ) {
    self.autoScrollWPM = wpm
    self.contentHeight = contentHeight
    self.viewportHeight = viewportHeight
    self.fontSize = fontSize
    self.pointsPerWord = pointsPerWord
  }

  func setSpeaking(_ speaking: Bool) {
    if speaking != isSpeaking {
      isSpeaking = speaking
      if speaking {
        remainingPostSpeechGlide = 0
      } else {
        remainingPostSpeechGlide = postSpeechGlideDuration
      }
      updateTask()
    }
  }

  func setAnchorOffset(_ offset: CGFloat?) {
    anchorOffset = offset
    // If the task stopped and a new anchor is set ahead of the current position,
    // restart the task so blank-line gaps are traversed without waiting for speech.
    if offset != nil && scrollTask == nil {
      updateTask()
    }
  }

  func setInitialOffset(_ offset: CGFloat) {
    currentScrollOffset = offset
  }

  func stop() {
    scrollTask?.cancel()
    scrollTask = nil
    isSpeaking = false
    remainingPostSpeechGlide = 0
  }

  private var anchorDriftPixels: Double {
    guard let anchor = anchorOffset else { return 0 }
    let maxOff = Double(max(contentHeight - viewportHeight, 0))
    guard maxOff > 0 else { return 0 }
    return (Double(anchor) * maxOff) - (Double(currentScrollOffset) * maxOff)
  }

  private func updateTask() {
    let shouldRun = isSpeaking || remainingPostSpeechGlide > 0 || anchorDriftPixels > 4
    if shouldRun {
      if scrollTask == nil {
        lastFrameTime = CACurrentMediaTime()
        let tickInterval: UInt64 = 16_666_667  // ~60 fps

        scrollTask = Task { [weak self] in
          while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: tickInterval)
            guard !Task.isCancelled else { break }
            self?.tick()
          }
        }
      }
    } else {
      scrollTask?.cancel()
      scrollTask = nil
    }
  }

  private func tick() {
    let currentTime = CACurrentMediaTime()
    if lastFrameTime == 0 {
      lastFrameTime = currentTime
      return
    }
    let dt = currentTime - lastFrameTime
    lastFrameTime = currentTime

    let maxOffset = max(contentHeight - viewportHeight, 0)
    guard maxOffset > 0 else { return }

    let calibratedPointsPerWord =
      pointsPerWord > 0
      ? pointsPerWord
      : Double(PrompterScrollMath.lineHeight(fontSize: fontSize)) / 8.0
    var pixelAdvancePerSecond =
      ((autoScrollWPM * voiceSpeedMultiplier) / 60.0) * calibratedPointsPerWord

    if !isSpeaking {
      if remainingPostSpeechGlide > 0 {
        // Normal post-speech deceleration glide.
        remainingPostSpeechGlide = max(remainingPostSpeechGlide - dt, 0)
        let glideProgress = remainingPostSpeechGlide / postSpeechGlideDuration
        let easedGlide = glideProgress * glideProgress
        pixelAdvancePerSecond *= easedGlide
      } else {
        // Glide expired. If the anchor is still ahead (blank-line gap), crawl
        // toward it gently so sparse layouts do not suddenly surge in speed.
        // If there is no gap, tick() will stop the task below.
        let drift = anchorDriftPixels
        if drift > 4 {
          pixelAdvancePerSecond =
            (autoScrollWPM / 60.0) * calibratedPointsPerWord * postGlideGapSpeedMultiplier
        } else {
          pixelAdvancePerSecond = 0
        }
      }
    }

    // Anchor correction: while speaking, scale aggressively with drift so blank-line
    // gaps are traversed in under a second when the user starts a new section.
    // During glide/crawl phases, apply only a gentle nudge to avoid overshoot.
    if let anchor = anchorOffset {
      let anchorPixelY = Double(anchor) * Double(maxOffset)
      let currentPixelY = Double(currentScrollOffset) * Double(maxOffset)
      let drift = anchorPixelY - currentPixelY

      if drift > 0 {
        let driftRatio = min(max(drift / max(Double(viewportHeight), 1), 0.0), 1.0)
        let catchUpFactor: Double
        if isSpeaking {
          catchUpFactor =
            speakingCatchUpFactorRange.lowerBound
            + (driftRatio
              * (speakingCatchUpFactorRange.upperBound - speakingCatchUpFactorRange.lowerBound))
        } else {
          catchUpFactor =
            glideCatchUpFactorRange.lowerBound
            + (driftRatio
              * (glideCatchUpFactorRange.upperBound - glideCatchUpFactorRange.lowerBound))
        }
        pixelAdvancePerSecond *= catchUpFactor
      }
    }

    let pixelAdvance = pixelAdvancePerSecond * dt
    let normalizedAdvance = pixelAdvance / Double(maxOffset)

    currentScrollOffset = min(currentScrollOffset + CGFloat(normalizedAdvance), 1.0)
    onScrollTick?(currentScrollOffset)

    if currentScrollOffset >= 1.0 {
      stop()
    } else if !isSpeaking && remainingPostSpeechGlide <= 0 && anchorDriftPixels <= 4 {
      // Gap fully traversed (or no gap) — stop the task.
      scrollTask?.cancel()
      scrollTask = nil
    }
  }
}
