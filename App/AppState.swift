import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var scripts: [ScriptMeta] = []
    @Published var collections: [AiraCollection] = []
    @Published var activeScript: Script? = nil
    @Published var sessionActive: Bool = false
    @Published var settings: AppSettings = AppSettings()
    @Published var stealthWarning: Bool = false
}
