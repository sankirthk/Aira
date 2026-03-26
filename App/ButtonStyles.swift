import SwiftUI

struct AiraPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Manrope-Bold", size: 14))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(hex: "#849688").opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct AiraSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Manrope-Bold", size: 14))
            .foregroundStyle(Color(hex: "#C98B7A"))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(hex: "#F5F2EC").opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#C98B7A"), lineWidth: 1)
            )
    }
}

struct AiraCueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Inter-Regular", size: 13))
            .foregroundStyle(Color(hex: "#C98B7A"))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "#F5F2EC").opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(hex: "#C98B7A"), lineWidth: 1)
            )
    }
}
