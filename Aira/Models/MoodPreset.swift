import Foundation

struct MoodPreset: Identifiable {
    let id: UUID
    let name: String
    let appearance: OverlayAppearance

    static let day = MoodPreset(
        id: UUID(),
        name: "Day",
        appearance: OverlayAppearance(
            textColor: "#F5F2EC",
            backgroundColor: "#849688",
            opacity: 0.75,
            fontName: "CrimsonText-Regular",
            fontSize: 20
        )
    )

    static let night = MoodPreset(
        id: UUID(),
        name: "Night",
        appearance: OverlayAppearance(
            textColor: "#D4A574",
            backgroundColor: "#2B2B2B",
            opacity: 0.90,
            fontName: "CrimsonText-Regular",
            fontSize: 20
        )
    )

    static let all: [MoodPreset] = [.day, .night]
}
