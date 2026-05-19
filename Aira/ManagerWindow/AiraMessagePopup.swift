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
      Color.black.opacity(0.18)
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 22) {
        Text(content.eyebrow)
          .font(
            usesGlass
              ? .system(size: 13, weight: .medium)
              : .custom("CrimsonText-Regular", size: 14)
          )
          .foregroundStyle(Color("colorPrimary"))
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background {
            if usesGlass {
              ZStack {
                Capsule(style: .continuous).fill(.ultraThinMaterial)
                Capsule(style: .continuous).fill(
                  Color("colorPrimary").opacity(isDark ? 0.15 : 0.10))
              }
            } else {
              Capsule(style: .continuous)
                .fill(Color("colorPrimary").opacity(0.12))
            }
          }
          .clipShape(Capsule(style: .continuous))

        VStack(alignment: .leading, spacing: 10) {
          Text(content.title)
            .font(
              usesGlass
                ? .system(size: 26, weight: .bold)
                : .custom("IndieFlower", size: 32)
            )
            .foregroundStyle(usesGlass ? .primary : Color("colorText"))

          Text(content.message)
            .font(
              usesGlass
                ? .system(size: 16)
                : .custom("CrimsonText-Regular", size: 19)
            )
            .foregroundStyle(usesGlass ? .secondary : Color("colorText").opacity(0.82))
            .fixedSize(horizontal: false, vertical: true)
        }

        HStack {
          Spacer()

          Button(content.primaryActionTitle, action: onDismiss)
            .buttonStyle(AiraCardCastButtonStyle())
        }
      }
      .padding(28)
      .frame(width: 420)
      .managerSurface(
        cornerRadius: 30,
        classicFill: Color("colorBackground"),
        strokeOpacity: 0.18
      )
      .shadow(color: .black.opacity(0.16), radius: 22, y: 12)
    }
  }
}
