import SwiftUI

struct CuePopoverView: View {
  let isReadOnly: Bool
  var usesGlass: Bool = false
  let onInsertCue: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: usesGlass ? 12 : 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Insert Cues")
          .font(
            usesGlass
              ? .system(size: 15, weight: .semibold)
              : .custom("IndieFlower", size: 20)
          )
          .foregroundStyle(usesGlass ? .primary : Color("colorText"))

        helperText
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
        ForEach(ScriptEditorCueOptions.defaults, id: \.self) { cue in
          Button("[\(cue)]") {
            onInsertCue(cue)
          }
          .buttonStyle(AiraCueTileButtonStyle())
          .disabled(isReadOnly)
        }
      }
    }
    .padding(14)
    .frame(width: usesGlass ? 300 : 320)
    .background {
      if usesGlass {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(.ultraThinMaterial)
      } else {
        RoundedRectangle(cornerRadius: 12)
          .fill(Color("colorBackground"))
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: usesGlass ? 14 : 12, style: .continuous)
        .strokeBorder(
          usesGlass ? Color.primary.opacity(0.14) : Color("colorText").opacity(0.18),
          lineWidth: 1
        )
    }
  }

  private var helperText: some View {
    Text(
      isReadOnly
        ? "End the live session before inserting cues."
        : "Custom cues still work by typing square brackets, like [Look up]."
    )
    .font(
      usesGlass
        ? .system(size: 12)
        : .custom("CrimsonText-Regular", size: 13)
    )
    .foregroundStyle(usesGlass ? .secondary : Color("colorMuted"))
  }
}
