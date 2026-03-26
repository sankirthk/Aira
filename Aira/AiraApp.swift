import SwiftUI

@main
struct AiraApp: App {
    @StateObject private var appState = AppState()
    @State private var overlayController = OverlayWindowController()

    var body: some Scene {
        WindowGroup {
            ManagerWindowView(overlayController: overlayController)
                .environmentObject(appState)
                .environment(\.managerFontScale, CGFloat(appState.settings.managerTypography.scaleFactor))
                .preferredColorScheme(preferredColorScheme)
                .task(id: appState.settings.appearanceMode) {
                    applyAppAppearance()
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)

        MenuBarExtra("Aira", systemImage: "rectangle.topthird.inset.filled") {
            MenuBarQuickAccessView(overlayController: overlayController)
                .environmentObject(appState)
                .preferredColorScheme(preferredColorScheme)
                .id(appState.settings.appearanceMode)
        }
        .menuBarExtraStyle(.window)
    }

    private var preferredColorScheme: ColorScheme? {
        switch appState.settings.appearanceMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }

    private func applyAppAppearance() {
        switch appState.settings.appearanceMode {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
    }
}
