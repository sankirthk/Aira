import SwiftUI

struct PillSetupView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var mode: PillContentMode = .voiceSync
    @State private var selectedScriptId: UUID? = nil

    var onLaunch: (PillContentMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Pill Window")
                .font(.custom("Manrope-Bold", size: 18))

            // Content mode picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Content Mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Mode", selection: Binding(
                        get: { mode == .voiceSync ? "sync" : "manual" },
                        set: { val in
                            if val == "sync" { mode = .voiceSync }
                            else { mode = .manual(scriptId: selectedScriptId ?? UUID()) }
                        }
                )) {
                    Text("Sync").tag("sync")
                    Text("Manual").tag("manual")
                }
                .pickerStyle(.segmented)
            }

            // Script picker (manual mode only)
            if case .manual = mode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Script")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Script", selection: $selectedScriptId) {
                        Text("Select a script").tag(Optional<UUID>.none)
                        ForEach(appState.scripts) { meta in
                            Text(meta.title).tag(Optional(meta.id))
                        }
                    }
                    .onAppear {
                        selectedScriptId = appState.scripts.first?.id
                    }
                    .onChange(of: selectedScriptId) { _, id in
                        if let id { mode = .manual(scriptId: id) }
                    }
                }
            }

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Launch") {
                    onLaunch(mode)
                    dismiss()
                }
                .buttonStyle(AiraPrimaryButtonStyle())
                .disabled(mode != .voiceSync && selectedScriptId == nil)
            }
        }
        .padding(24)
        .frame(width: 400, height: 260)
    }
}
