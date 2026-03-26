import SwiftUI

private struct ManagerFontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var managerFontScale: CGFloat {
        get { self[ManagerFontScaleKey.self] }
        set { self[ManagerFontScaleKey.self] = newValue }
    }
}
