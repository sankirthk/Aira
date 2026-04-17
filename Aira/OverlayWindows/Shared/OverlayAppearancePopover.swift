import SwiftUI

struct OverlayAppearancePopover: View {
  @Binding var appearance: OverlayAppearance
  let defaultAppearance: OverlayAppearance
  let windowTitle: String

  var body: some View {
    VStack(alignment: .center, spacing: 16) {
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
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
        )

      // Opacity
      VStack(alignment: .center, spacing: 4) {
        Text("Opacity").font(.caption).foregroundStyle(.secondary)
        Slider(value: $appearance.opacity, in: 0.2...1.0)
      }
      .frame(maxWidth: .infinity, alignment: .center)

      // Font size
      VStack(alignment: .center, spacing: 4) {
        Text("Font Size").font(.caption).foregroundStyle(.secondary)
        Slider(value: $appearance.fontSize, in: 14...32)
      }
      .frame(maxWidth: .infinity, alignment: .center)

      // Font picker
      VStack(alignment: .center, spacing: 4) {
        Text("Font").font(.caption).foregroundStyle(.secondary)
        HStack(spacing: 8) {
          fontOptionButton(title: "Crimson", fontName: "CrimsonText-Regular")
          fontOptionButton(title: "Manrope", fontName: "Manrope-Bold")
          fontOptionButton(title: "Inter", fontName: "Inter-Regular")
        }
        .frame(maxWidth: .infinity)
      }
      .frame(maxWidth: .infinity, alignment: .center)

      Divider()

      Button("Reset to Defaults") {
        appearance = defaultAppearance
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .padding(16)
    .frame(width: 240)
  }

  @ViewBuilder
  private func fontOptionButton(title: String, fontName: String) -> some View {
    let isSelected = appearance.fontName == fontName

    Button {
      appearance.fontName = fontName
    } label: {
      Text(title)
        .font(.custom("Inter-Regular", size: 11))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Color("colorPrimary") : Color("colorSurface"))
        .foregroundStyle(isSelected ? Color.white : Color("colorText"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color("colorText").opacity(isSelected ? 0 : 0.12), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
  }
}
