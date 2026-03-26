import SwiftUI

struct OverlayAppearancePopover: View {
    @Binding var appearance: OverlayAppearance
    let defaultAppearance: OverlayAppearance
    let windowTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(windowTitle)
                .font(.custom("Manrope-Bold", size: 13))

            // Mini live preview
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: appearance.backgroundColor).opacity(appearance.opacity))
                .frame(height: 32)
                .overlay(
                    Text("Sample script text")
                        .font(.custom(appearance.fontName, size: min(appearance.fontSize * 0.6, 13)))
                        .foregroundStyle(Color(hex: appearance.textColor))
                )

            // Opacity
            VStack(alignment: .leading, spacing: 4) {
                Text("Opacity").font(.caption).foregroundStyle(.secondary)
                Slider(value: $appearance.opacity, in: 0.2...1.0)
            }

            // Font size
            VStack(alignment: .leading, spacing: 4) {
                Text("Font Size").font(.caption).foregroundStyle(.secondary)
                Slider(value: $appearance.fontSize, in: 14...32)
            }

            // Font picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Font").font(.caption).foregroundStyle(.secondary)
                Picker("Font", selection: $appearance.fontName) {
                    Text("Crimson Text").tag("CrimsonText-Regular")
                    Text("Manrope").tag("Manrope-Bold")
                    Text("Inter").tag("Inter-Regular")
                }
                .pickerStyle(.segmented)
            }

            Divider()

            Button("Reset to Defaults") {
                appearance = defaultAppearance
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 240)
    }
}
