import SwiftUI

struct AiraMessagePopupContent: Equatable, Sendable {
  let eyebrow: String
  let title: String
  let message: String
  let primaryActionTitle: String

  static let emptyScriptLaunchError = AiraMessagePopupContent(
    eyebrow: "Cast paused",
    title: "Add script text first",
    message: "Write or paste a few words before casting to the notch.",
    primaryActionTitle: "OK"
  )

  static let emptySatelliteLaunchError = AiraMessagePopupContent(
    eyebrow: "Pill Window paused",
    title: "Add script text first",
    message: "Choose a Pill Window script with at least a few words before launching.",
    primaryActionTitle: "OK"
  )

  static func launchOverlayError(message: String) -> AiraMessagePopupContent {
    if message == "Add script text before casting to the notch." {
      return emptyScriptLaunchError
    }
    if message == "Add script text before casting to a Pill Window." {
      return emptySatelliteLaunchError
    }

    return AiraMessagePopupContent(
      eyebrow: "Launch issue",
      title: "Unable to launch overlay",
      message: message,
      primaryActionTitle: "OK"
    )
  }
}

struct AiraMessagePopup: View {
  let content: AiraMessagePopupContent
  let onDismiss: () -> Void
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  private var usesGlass: Bool { managerTheme.usesLiquidGlassMode }
  private var isDark: Bool { colorScheme == .dark }

  var body: some View {
    ZStack {
      Color.black.opacity(usesGlass ? 0.25 : 0.18)
        .ignoresSafeArea()

      popupCard
        .shadow(color: .black.opacity(0.16), radius: 22, y: 12)
    }
  }

  private var popupCard: some View {
    VStack(alignment: .leading, spacing: 22) {
      eyebrowBadge

      VStack(alignment: .leading, spacing: 10) {
        Text(content.title)
          .font(.system(size: usesGlass ? 26 : 24, weight: .bold))
          .foregroundStyle(usesGlass ? .primary : Color("colorText"))

        Text(content.message)
          .font(.system(size: usesGlass ? 16 : 15))
          .foregroundStyle(usesGlass ? .secondary : Color("colorText").opacity(0.82))
          .fixedSize(horizontal: false, vertical: true)
      }

      HStack {
        Spacer()
        dismissButton
      }
    }
    .padding(28)
    .frame(width: 420)
    .modifier(PopupSurfaceModifier(usesGlass: usesGlass, isDark: isDark))
  }

  private var eyebrowBadge: some View {
    Text(content.eyebrow)
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(usesGlass ? .secondary : managerTheme.primaryAccent(for: colorScheme))
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background {
        if usesGlass {
          ZStack {
            Capsule(style: .continuous).fill(.ultraThinMaterial)
            Capsule(style: .continuous).fill(
              managerTheme.primaryAccent(for: colorScheme).opacity(isDark ? 0.15 : 0.10))
          }
        } else {
          Capsule(style: .continuous)
            .fill(managerTheme.primaryAccent(for: colorScheme).opacity(0.12))
        }
      }
      .clipShape(Capsule(style: .continuous))
  }

  @ViewBuilder
  private var dismissButton: some View {
    Button(content.primaryActionTitle, action: onDismiss)
      .buttonStyle(AiraCardCastButtonStyle())
  }
}

private struct PopupSurfaceModifier: ViewModifier {
  let usesGlass: Bool
  let isDark: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

    if usesGlass {
      if #available(macOS 26.0, *) {
        content
          .glassEffect(
            .regular.tint(isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.3)),
            in: .rect(cornerRadius: 30)
          )
      } else {
        content
          .background {
            ZStack {
              shape.fill(.ultraThinMaterial)
              shape.fill(isDark ? Color.black.opacity(0.18) : Color.white.opacity(0.45))
            }
          }
          .clipShape(shape)
          .overlay(
            shape.strokeBorder(
              isDark ? Color.white.opacity(0.22) : Color.white.opacity(0.50),
              lineWidth: 0.5
            )
          )
      }
    } else {
      content
        .managerSurface(
          cornerRadius: 30,
          classicFill: Color("colorBackground"),
          strokeOpacity: 0.18
        )
    }
  }
}
