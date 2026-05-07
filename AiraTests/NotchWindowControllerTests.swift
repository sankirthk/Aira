import CoreGraphics
import Foundation
import SwiftUI
import Testing

@testable import Aira

struct NotchWindowControllerTests {
  @MainActor @Test func sessionPlayheadCoordinatorTracksSessionStartedState() {
    let coordinator = SessionPlayheadCoordinator()

    coordinator.beginSession()
    #expect(coordinator.isSessionStarted == false)

    coordinator.markSessionStarted()
    #expect(coordinator.isSessionStarted == true)

    coordinator.endSession()
    #expect(coordinator.isSessionStarted == false)
  }

  @Test func prompterRestorePolicyUsesSharedStartedStateForManualSessions() {
    #expect(
      PrompterSessionRestorePolicy.shouldRestoreRunningSession(
        sharedSessionStarted: false,
        voiceSyncState: .idle
      ) == false
    )
    #expect(
      PrompterSessionRestorePolicy.shouldRestoreRunningSession(
        sharedSessionStarted: true,
        voiceSyncState: .idle
      ) == true
    )
    #expect(
      PrompterSessionRestorePolicy.shouldRestoreRunningSession(
        sharedSessionStarted: false,
        voiceSyncState: .running
      ) == true
    )
  }

  @MainActor @Test func notchControllerAcceptsLiveSessionBehaviorUpdates() {
    let controller = NotchWindowController()

    controller.updateSessionBehavior(
      voiceSyncEnabled: false,
      spokenWordHighlightingEnabled: true,
      showScriptProgress: true,
      pauseOnHoverEnabled: false
    )

    let mirror = Mirror(reflecting: controller)
    #expect(mirror.descendant("voiceSyncEnabled") as? Bool == false)
    #expect(mirror.descendant("spokenWordHighlightingEnabled") as? Bool == true)
    #expect(mirror.descendant("showScriptProgress") as? Bool == true)
    #expect(mirror.descendant("pauseOnHoverEnabled") as? Bool == false)
  }

  @Test func notchDefaultWidthUsesNarrowerLaunchValue() {
    #expect(NotchWidthConfiguration.defaultWidth == 380)
    #expect(AppSettings().notchWindowWidth == NotchWidthConfiguration.defaultWidth)
  }

  @MainActor @Test func notchWidthSettingsClampDuringInitAndDecode() throws {
    let initialized = AppSettings(notchWindowWidth: 999, notchWindowHeight: 999)
    #expect(initialized.notchWindowWidth == NotchWidthConfiguration.maximumWidth)
    #expect(initialized.notchWindowHeight == NotchHeightConfiguration.maximumHeight)

    let json = """
      {
        "defaultOverlayAppearance": {
          "textColor": "#FFFFFF",
          "backgroundColor": "#000000",
          "opacity": 0.85,
          "fontName": "Inter-Regular",
          "fontSize": 20
        },
        "notchWindowWidth": 100,
        "notchWindowHeight": 80,
        "countdownDuration": 3,
        "voiceSyncEnabled": true,
        "voiceSyncMode": "voice",
        "speechSensitivity": "medium",
        "autoScrollWPM": 135,
        "appearanceMode": "system",
        "managerTypography": "medium",
        "liveAnswerDisclosureAccepted": false,
        "pillsEnabled": false,
        "maxPillCount": 1,
        "pillConfigurations": [
          { "contentMode": { "type": "voiceSync" } },
          { "contentMode": { "type": "voiceSync" } }
        ],
        "shortcutToggleNotch": "⌘⇧N",
        "shortcutTogglePill": "⌘⇧P",
        "shortcutToggleVoiceSync": "⌘⇧Space",
        "shortcutScrollUp": "↑",
        "shortcutScrollDown": "↓",
        "shortcutEndSession": "Escape"
      }
      """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(AppSettings.self, from: json)
    #expect(decoded.notchWindowWidth == NotchWidthConfiguration.minimumWidth)
    #expect(decoded.notchWindowHeight == NotchHeightConfiguration.minimumHeight)
  }

  @Test func notchWindowUsesPersistedWidthRange() {
    #expect(NotchWindowController.resolvedPanelWidth(280) == 340)
    #expect(NotchWindowController.resolvedPanelWidth(420) == 420)
    #expect(NotchWindowController.resolvedPanelWidth(640) == 440)
  }

  @Test func notchResizeKeepsOverlayAnchoredBeneathScreenTop() {
    var appearance = OverlayAppearance.default
    appearance.fontSize = 20
    let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let startFrame = NotchWindowController.defaultPanelFrame(
      screenFrame: screenFrame,
      notchHeight: 34,
      appearance: appearance,
      preferredWidth: 400,
      preferredHeight: 164
    )

    let resized = NotchWindowController.resizedFrame(
      from: startFrame,
      edge: .bottomTrailing,
      translation: CGSize(width: 30, height: 24),
      screenFrame: screenFrame,
      notchHeight: 34,
      appearance: appearance
    )

    #expect(resized.midX == screenFrame.midX)
    #expect(resized.maxY == screenFrame.maxY)
    #expect(resized.width == 430)
    #expect(resized.height == startFrame.height + 24)
  }

  @Test func notchResizeRespectsMinimumAndMaximumSizeLimits() {
    var appearance = OverlayAppearance.default
    appearance.fontSize = 28
    let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let startFrame = NotchWindowController.defaultPanelFrame(
      screenFrame: screenFrame,
      notchHeight: 34,
      appearance: appearance,
      preferredWidth: 400,
      preferredHeight: 164
    )

    let shrunk = NotchWindowController.resizedFrame(
      from: startFrame,
      edge: .leading,
      translation: CGSize(width: 400, height: 0),
      screenFrame: screenFrame,
      notchHeight: 34,
      appearance: appearance
    )
    let expanded = NotchWindowController.resizedFrame(
      from: startFrame,
      edge: .bottomTrailing,
      translation: CGSize(width: 400, height: 400),
      screenFrame: screenFrame,
      notchHeight: 34,
      appearance: appearance
    )

    #expect(shrunk.width == CGFloat(NotchWidthConfiguration.minimumWidth))
    #expect(expanded.width == CGFloat(NotchWidthConfiguration.maximumWidth))
    #expect(expanded.height == CGFloat(NotchHeightConfiguration.maximumHeight))
    #expect(
      shrunk.height
        >= NotchWindowController.minimumPanelHeight(notchHeight: 34, appearance: appearance))
  }

  @Test func nonNotchDisplayCollapsesNotchSizeToZero() {
    #expect(NotchWindowController.hasPhysicalNotch(notchWidth: 0, notchHeight: 34) == false)
    #expect(NotchWindowController.hasPhysicalNotch(notchWidth: 120, notchHeight: 0) == false)
    #expect(NotchWindowController.hasPhysicalNotch(notchWidth: 120, notchHeight: 34) == true)
    #expect(NotchWindowController.notchSize(notchWidth: 0, notchHeight: 34) == .zero)
    #expect(NotchWindowController.notchSize(notchWidth: 120, notchHeight: 0) == .zero)
    #expect(
      NotchWindowController.notchSize(notchWidth: 120, notchHeight: 34)
        == CGSize(width: 120, height: 34))
  }

  @Test func nonNotchFallbackGeometryStaysFlatAlongTopEdge() {
    let rect = CGRect(x: 0, y: 0, width: 320, height: 180)
    let path = NotchOverlayGeometry.fallbackPath(in: rect)

    #expect(path.contains(CGPoint(x: 1, y: 1), eoFill: false))
    #expect(path.contains(CGPoint(x: rect.maxX - 1, y: 1), eoFill: false))
    #expect(path.contains(CGPoint(x: 1, y: rect.maxY - 1), eoFill: false) == false)
    #expect(path.contains(CGPoint(x: rect.maxX - 1, y: rect.maxY - 1), eoFill: false) == false)
  }

  @Test func notchCutoutUsesRoundedCornersWithoutClosingTopOpening() {
    let rect = CGRect(x: 0, y: 0, width: 400, height: 160)
    let notchWidth: CGFloat = 120
    let notchHeight: CGFloat = 34
    let path = NotchOverlayGeometry.overlayPath(
      in: rect, notchSize: CGSize(width: notchWidth, height: notchHeight))
    let sideOverscan = NotchOverlayGeometry.sideOverscan(for: notchWidth)
    let cutoutDepth = NotchOverlayGeometry.cutoutDepth(for: notchHeight)
    let leftSideWallCompensation = NotchOverlayGeometry.leftSideWallSeamCompensation(
      in: rect, notchWidth: notchWidth)
    let rightSideWallCompensation = NotchOverlayGeometry.rightSideWallSeamCompensation(
      notchWidth: notchWidth)
    let physicalLeftWall = rect.midX - notchWidth / 2
    let physicalRightWall = rect.midX + notchWidth / 2
    let roundedCornerSampleY = max(cutoutDepth - 6, 1)
    let verticalWallSampleY = max(cutoutDepth * 0.3, 1)
    let topOpeningSampleY: CGFloat = 1
    let centerX = rect.midX

    #expect(NotchOverlayGeometry.minimumSideOverscan == 0)
    #expect(NotchOverlayGeometry.maximumSideOverscan == 0)
    #expect(sideOverscan == 0)
    #expect(leftSideWallCompensation == 1.0)
    #expect(rightSideWallCompensation == 0.5)
    #expect(
      path.contains(
        CGPoint(x: physicalLeftWall + leftSideWallCompensation + 0.25, y: topOpeningSampleY),
        eoFill: false)
        == false
    )
    #expect(
      path.contains(
        CGPoint(x: physicalRightWall - rightSideWallCompensation - 0.25, y: topOpeningSampleY),
        eoFill: false
      ) == false
    )
    #expect(path.contains(CGPoint(x: centerX, y: topOpeningSampleY), eoFill: false) == false)
    #expect(
      path.contains(
        CGPoint(
          x: physicalLeftWall + leftSideWallCompensation * 0.5, y: verticalWallSampleY),
        eoFill: false)
    )
    #expect(
      path.contains(
        CGPoint(
          x: physicalRightWall - rightSideWallCompensation * 0.5, y: verticalWallSampleY),
        eoFill: false)
    )
    #expect(path.contains(CGPoint(x: physicalLeftWall + 1, y: roundedCornerSampleY), eoFill: false))
    #expect(
      path.contains(CGPoint(x: physicalRightWall - 1, y: roundedCornerSampleY), eoFill: false))
    #expect(path.contains(CGPoint(x: centerX, y: cutoutDepth + 1), eoFill: false))
  }

  @Test func notchCutoutUsesExtraLeftSeamCompensationForEvenWidthPanels() {
    let rect = CGRect(x: 0, y: 0, width: 400, height: 160)
    let notchWidth: CGFloat = 120
    let path = NotchOverlayGeometry.overlayPath(
      in: rect, notchSize: CGSize(width: notchWidth, height: 34))
    let leftSideWallCompensation = NotchOverlayGeometry.leftSideWallSeamCompensation(
      in: rect, notchWidth: notchWidth)
    let rightSideWallCompensation = NotchOverlayGeometry.rightSideWallSeamCompensation(
      notchWidth: notchWidth)
    let physicalLeftWall = rect.midX - notchWidth / 2
    let physicalRightWall = rect.midX + notchWidth / 2
    let verticalWallSampleY: CGFloat = 10
    let topOpeningSampleY: CGFloat = 1

    #expect(NotchOverlayGeometry.sideOverscan(for: notchWidth) == 0)
    #expect(leftSideWallCompensation == 1.0)
    #expect(rightSideWallCompensation == 0.5)
    #expect(
      path.contains(CGPoint(x: physicalLeftWall + 0.75, y: verticalWallSampleY), eoFill: false))
    #expect(
      path.contains(CGPoint(x: physicalLeftWall + 1.25, y: topOpeningSampleY), eoFill: false)
        == false
    )
    #expect(
      path.contains(CGPoint(x: physicalRightWall - 0.75, y: topOpeningSampleY), eoFill: false)
        == false
    )
  }

  @Test func notchOverlayKeepsFlatTopOutsideCutout() {
    let rect = CGRect(x: 0, y: 0, width: 400, height: 160)
    let path = NotchOverlayGeometry.overlayPath(
      in: rect, notchSize: CGSize(width: 120, height: 34))

    #expect(path.contains(CGPoint(x: 1, y: 1), eoFill: false))
    #expect(path.contains(CGPoint(x: rect.maxX - 1, y: 1), eoFill: false))
  }
}
