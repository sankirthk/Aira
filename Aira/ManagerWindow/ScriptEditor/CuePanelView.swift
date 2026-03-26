import SwiftUI

struct CuePanelView: View {
    let isReadOnly: Bool
    let onInsertCue: (String) -> Void

    let cueTypes = ["Smile", "Pause 2s", "Eye Contact", "Gesture", "Breathe", "Emphasize"]

    var body: some View {
        ScriptEditorPanel(backgroundColor: Color("colorPrimary")) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Insert Performance Cues")
                    .font(.custom("IndieFlower", size: 28))
                    .foregroundStyle(Color("colorBackground"))
                    .padding(.bottom, 16)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(cueTypes, id: \.self) { cue in
                        Button("[\(cue)]") {
                            onInsertCue(cue)
                        }
                        .buttonStyle(AiraCueTileButtonStyle())
                        .disabled(isReadOnly)
                    }
                }

                Rectangle()
                    .fill(Color("colorBackground").opacity(0.3))
                    .frame(height: 2)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                Text(
                    isReadOnly
                        ? "This script is live in an active session. End the session before inserting cues or editing text."
                        : "Performance cue insertion is available directly from this panel while you draft."
                )
                    .font(.custom("CrimsonText-Regular", size: 15))
                    .foregroundStyle(Color("colorBackground").opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
