import SwiftUI

// MARK: - Manager App Buttons

struct AiraPrimaryButtonStyle: ButtonStyle {
    @Environment(\.managerFontScale) private var managerFontScale

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Manrope-Bold", size: 14 * managerFontScale))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color("colorPrimary").opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct AiraSecondaryButtonStyle: ButtonStyle {
    @Environment(\.managerFontScale) private var managerFontScale

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Manrope-Bold", size: 14 * managerFontScale))
            .foregroundStyle(Color("colorSecondary"))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color("colorBackground").opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("colorSecondary"), lineWidth: 1)
            )
    }
}

struct AiraWobblyToolbarButtonStyle: ButtonStyle {
    @Environment(\.managerFontScale) private var managerFontScale

    enum Variant {
        case secondary
        case tertiary
    }

    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        let fillColor: Color
        let foregroundColor: Color
        let borderColor: Color

        switch variant {
        case .secondary:
            fillColor = Color("colorSecondary")
            foregroundColor = .white
            borderColor = Color.white.opacity(0.8)
        case .tertiary:
            fillColor = Color("colorBackground")
            foregroundColor = Color("colorText")
            borderColor = Color("colorText")
        }

        return configuration.label
            .font(.custom("IndieFlower", size: 15 * managerFontScale))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(fillColor.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .inset(by: 2)
                    .stroke(
                        borderColor,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [2, 1])
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct AiraCueButtonStyle: ButtonStyle {
    @Environment(\.managerFontScale) private var managerFontScale

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Inter-Regular", size: 13 * managerFontScale))
            .foregroundStyle(Color("colorSecondary"))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color("colorBackground").opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color("colorSecondary"), lineWidth: 1)
            )
    }
}

struct AiraCueTileButtonStyle: ButtonStyle {
    @Environment(\.managerFontScale) private var managerFontScale

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("IndieFlower", size: 14 * managerFontScale))
            .foregroundStyle(Color(hex: "#F5F2EC"))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color("colorSecondary").opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color("colorText"), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Sidebar Buttons

/// Organic wobbly-border button matching SidebarButton.tsx.
/// SVG path source space: 200 × 46. Stroke: cream/white at 25 % opacity.
struct AiraSidebarActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0))
            .overlay(
                OrganicButtonBorder()
                    .stroke(
                        Color.white.opacity(configuration.isPressed ? 0.6 : 0.25),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
            )
    }
}

/// Matches SidebarButton.tsx path:
/// M 4,12 Q 3,7 9,5 L 190,6 Q 196,7 195,13 L 194,35 Q 195,40 189,41 L 9,40 Q 3,39 4,33 Z
/// Source view-box: 200 × 46
private struct OrganicButtonBorder: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width  / 200.0
        let sy = rect.height / 46.0
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
        var p = Path()
        p.move(to: pt(4, 12))
        p.addQuadCurve(to: pt(9,  5),  control: pt(3,  7))
        p.addLine(to: pt(190, 6))
        p.addQuadCurve(to: pt(195, 13), control: pt(196, 7))
        p.addLine(to: pt(194, 35))
        p.addQuadCurve(to: pt(189, 41), control: pt(195, 40))
        p.addLine(to: pt(9,  40))
        p.addQuadCurve(to: pt(4,  33), control: pt(3,  39))
        p.closeSubpath()
        return p
    }
}

// MARK: - Script Card Buttons

/// Sage-green fill, expands to fill available width — Edit button
struct AiraCardEditButtonStyle: ButtonStyle {
    @Environment(\.managerFontScale) private var managerFontScale

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Manrope-Bold", size: 14 * managerFontScale))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color("colorPrimary").opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Terracotta fill — Cast button
struct AiraCardCastButtonStyle: ButtonStyle {
    @Environment(\.managerFontScale) private var managerFontScale

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Manrope-Bold", size: 14 * managerFontScale))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color("colorSecondary").opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
