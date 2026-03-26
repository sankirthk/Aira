import SwiftUI
import AppKit

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
    private let voiceSpeedMultiplier: Double = 1.45
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

    private func updateTask() {
        if isSpeaking || remainingPostSpeechGlide > 0 {
            if scrollTask == nil {
                lastFrameTime = CACurrentMediaTime()
                let tickInterval: UInt64 = 16_666_667 // ~60 fps
                
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

        let calibratedPointsPerWord = pointsPerWord > 0
            ? pointsPerWord
            : Double(PrompterScrollMath.lineHeight(fontSize: fontSize)) / 8.0
        var pixelAdvancePerSecond = ((autoScrollWPM * voiceSpeedMultiplier) / 60.0) * calibratedPointsPerWord

        if !isSpeaking {
            remainingPostSpeechGlide = max(remainingPostSpeechGlide - dt, 0)
            let glideProgress = remainingPostSpeechGlide / postSpeechGlideDuration
            let easedGlide = glideProgress * glideProgress
            pixelAdvancePerSecond *= easedGlide
        }

        // Anchor correction should never make voice mode feel slower than the configured WPM.
        // Use the WPM-derived pace as the floor and allow only a modest forward catch-up boost.
        if let anchor = anchorOffset {
            let anchorPixelY = anchor * maxOffset
            let currentPixelY = currentScrollOffset * maxOffset
            let drift = anchorPixelY - currentPixelY

            let driftRatio = min(max(drift / max(viewportHeight, 1), 0.0), 1.0)
            let catchUpFactor = 1.0 + (driftRatio * 0.18)
            pixelAdvancePerSecond *= catchUpFactor
        }

        let pixelAdvance = pixelAdvancePerSecond * dt
        let normalizedAdvance = pixelAdvance / maxOffset

        currentScrollOffset = min(currentScrollOffset + CGFloat(normalizedAdvance), 1.0)
        onScrollTick?(currentScrollOffset)

        if currentScrollOffset >= 1.0 {
            stop()
        } else if !isSpeaking && remainingPostSpeechGlide <= 0 {
            scrollTask?.cancel()
            scrollTask = nil
        }
    }
}
