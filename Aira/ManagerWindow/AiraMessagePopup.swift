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

  var body: some View {
    ZStack {
      Color.black.opacity(0.18)
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 22) {
        Text(content.eyebrow)
          .font(.custom("CrimsonText-Regular", size: 14))
          .foregroundStyle(Color("colorPrimary"))
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(
            Capsule(style: .continuous)
              .fill(Color("colorPrimary").opacity(0.12))
          )

        VStack(alignment: .leading, spacing: 10) {
          Text(content.title)
            .font(.custom("IndieFlower", size: 32))
            .foregroundStyle(Color("colorText"))

          Text(content.message)
            .font(.custom("CrimsonText-Regular", size: 19))
            .foregroundStyle(Color("colorText").opacity(0.82))
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
      .background(
        RoundedRectangle(cornerRadius: 30, style: .continuous)
          .fill(Color("colorBackground"))
          .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
              .stroke(Color("colorPrimary").opacity(0.35), lineWidth: 1.5)
          )
      )
      .shadow(color: .black.opacity(0.16), radius: 22, y: 12)
    }
  }
}
