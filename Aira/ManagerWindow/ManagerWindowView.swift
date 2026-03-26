import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ManagerWindowView: View {
    @EnvironmentObject var appState: AppState
    let overlayController: OverlayWindowController
    @State private var selectedNav: SidebarNav = .allScripts
    @State private var activeScript: Script? = nil
    @State private var showSettings: Bool = false
    @State private var sidebarVisible: Bool = true
    @State private var creationErrorMessage: String? = nil
    @State private var importErrorMessage: String? = nil
    @State private var dismissErrorMessage: String? = nil
    @State private var overlayErrorMessage: String? = nil
    @State private var sessionRestrictionMessage: String? = nil
    @State private var localShortcutMonitor: Any?
    @State private var globalShortcutMonitor: Any?
    @State private var voiceSyncKeyboardMonitor = VoiceSyncKeyboardMonitor()
    @State private var managerWindow: NSWindow?
    var canGoBack: Bool { activeScript != nil }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Top navigation bar
            HStack(spacing: 4) {
                // Sidebar toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sidebarVisible.toggle()
                    }
                } label: {
                    AiraIcon(type: .sidebar, size: 20, color: Color("colorText"), animated: false)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .help(sidebarVisible ? "Collapse Sidebar" : "Expand Sidebar")

                // Back
                Button {
                    dismissEditor()
                } label: {
                    AiraIcon(type: .back, size: 20,
                             color: Color("colorText").opacity(canGoBack ? 1 : 0.3))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .disabled(!canGoBack)
                .help("Go Back")

                // Forward (placeholder — no forward history in single-level nav)
                Button { } label: {
                    AiraIcon(type: .forward, size: 20, color: Color("colorText").opacity(0.3))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .disabled(true)
                .help("Go Forward")

                Spacer()
            }
            .padding(.horizontal, 4)
            .frame(height: 44)
            .background(Color("colorBackground"))
            .overlay(alignment: .bottom) {
                Divider().opacity(0.15)
            }

            // MARK: Main layout
            HStack(spacing: 0) {
                if sidebarVisible {
                    SidebarView(
                        selectedNav: sidebarSelectionBinding,
                        showSettings: $showSettings,
                        onNewScript: {
                            createAndOpenScript()
                        },
                        onOpenScript: { id in
                            openScriptFromSidebar(id: id)
                        }
                    )
                    .frame(width: 230)

                    Divider()
                        .background(Color.black.opacity(0.4))
                }

                Group {
                    if activeScript != nil {
                        ScriptEditorView(
                            script: activeScriptBinding,
                            managerFontScale: CGFloat(appState.settings.managerTypography.scaleFactor),
                            isReadOnly: activeEditorIsLockedForSession,
                            onCast: {
                                castCurrentScriptToNotch()
                            }
                        ) {
                            dismissEditor()
                        }
                    } else {
                        DocumentLibraryView(
                            filter: selectedNav,
                            onEdit: { script in activeScript = script },
                            onNewScript: {
                                createAndOpenScript()
                            },
                            onCast: { id in
                                castScriptToNotch(id: id)
                            },
                            onImportScript: {
                                importScriptFromPicker()
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("colorBackground"))
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(
            ManagerWindowAccessor { window in
                managerWindow = window
            }
        )
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
        }

        .alert("Unable to Create Script", isPresented: creationErrorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(creationErrorMessage ?? "Please try again.")
        }
        .alert("Unable to Import Script", isPresented: importErrorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importErrorMessage ?? "Please try again.")
        }
        .alert("Unable to Close Editor", isPresented: dismissErrorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(dismissErrorMessage ?? "Please try again.")
        }
        .alert("Unable to Launch Overlay", isPresented: overlayErrorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(overlayErrorMessage ?? "Please try again.")
        }
        .alert("Action Unavailable During Live Session", isPresented: sessionRestrictionBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(sessionRestrictionMessage ?? "End the active session and try again.")
        }
        .onAppear {
            overlayController.appState = appState
            installShortcutMonitors()
        }
        .onDisappear {
            removeShortcutMonitors()
            voiceSyncKeyboardMonitor.stop()
        }
        .onChange(of: appState.sessionActive) { _, isActive in
            // Restore the manager window whenever a session ends — regardless of whether
            // it ended via keyboard shortcut, overlay context menu, or any other path.
            if isActive {
                startVoiceSyncKeyboardMonitor()
            } else {
                voiceSyncKeyboardMonitor.stop()
                restoreManagerWindow()
            }
        }
        .onChange(of: appState.settings.shortcutToggleVoiceSync) { _, _ in
            if appState.sessionActive {
                startVoiceSyncKeyboardMonitor()
            }
        }
        .onChange(of: appState.settings.shortcutScrollUp) { _, _ in
            if appState.sessionActive {
                startVoiceSyncKeyboardMonitor()
            }
        }
        .onChange(of: appState.settings.shortcutScrollDown) { _, _ in
            if appState.sessionActive {
                startVoiceSyncKeyboardMonitor()
            }
        }
    }

    private var creationErrorBinding: Binding<Bool> {
        Binding(
            get: { creationErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    creationErrorMessage = nil
                }
            }
        )
    }

    private var sidebarSelectionBinding: Binding<SidebarNav> {
        Binding(
            get: { selectedNav },
            set: { newSelection in
                navigateToSidebarDestination(newSelection)
            }
        )
    }

    private func createAndOpenScript() {
        if activeScript != nil {
            guard dismissEditor() else {
                return
            }
        }

        let collectionID: UUID?
        if case let .collection(id) = selectedNav {
            collectionID = id
        } else {
            collectionID = nil
        }

        appState.activeScript = nil
        activeScript = appState.makeDraftScript(inCollection: collectionID)
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    importErrorMessage = nil
                }
            }
        )
    }

    private var activeScriptBinding: Binding<Script> {
        Binding(
            get: {
                activeScript ?? appState.activeScript ?? Script(
                    id: UUID(),
                    title: "",
                    body: "",
                    cues: [],
                    collectionIds: [],
                    createdAt: Date(),
                    lastEdited: Date()
                )
            },
            set: { updatedScript in
                activeScript = updatedScript
            }
        )
    }

    private var activeEditorIsLockedForSession: Bool {
        guard let activeScript else { return false }
        return appState.isScriptLockedForSessionEditing(activeScript.id)
    }

    private var dismissErrorBinding: Binding<Bool> {
        Binding(
            get: { dismissErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    dismissErrorMessage = nil
                }
            }
        )
    }

    private var overlayErrorBinding: Binding<Bool> {
        Binding(
            get: { overlayErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    overlayErrorMessage = nil
                }
            }
        )
    }

    private var sessionRestrictionBinding: Binding<Bool> {
        Binding(
            get: { sessionRestrictionMessage != nil },
            set: { isPresented in
                if !isPresented {
                    sessionRestrictionMessage = nil
                }
            }
        )
    }

    private func navigateToSidebarDestination(_ destination: SidebarNav) {
        if activeScript != nil {
            guard dismissEditor() else {
                return
            }
        }

        selectedNav = destination
    }

    @discardableResult
    private func dismissEditor() -> Bool {
        guard let script = activeScript else {
            activeScript = nil
            return true
        }

        let persistedScript = appState.activeScript?.id == script.id ? appState.activeScript : nil

        do {
            switch ScriptEditorSessionLogic.dismissDisposition(for: script, persistedScript: persistedScript) {
            case .discardDraft:
                appState.activeScript = nil
            case .save:
                try appState.saveScript(script)
            case .closeWithoutSaving:
                break
            }
            activeScript = nil
            return true
        } catch {
            dismissErrorMessage = error.localizedDescription
            return false
        }
    }

    private func importScriptFromPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let script = try appState.importScript(from: url)
            selectedNav = .allScripts
            activeScript = script
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func openScriptFromSidebar(id: UUID) {
        guard !appState.isScriptLockedForSessionEditing(id) else {
            sessionRestrictionMessage = "End the active session before editing this script."
            return
        }

        if activeScript != nil {
            guard dismissEditor() else {
                return
            }
        }

        do {
            let script = try appState.loadScript(id: id)
            activeScript = script
        } catch {
            creationErrorMessage = error.localizedDescription
        }
    }

    private var enabledPillModes: [PillContentMode] {
        appState.settings.enabledPillModes
    }

    private func castCurrentScriptToNotch() {
        guard !overlayController.hasActiveNotch else {
            overlayErrorMessage = "An overlay is already active. End the current session before casting again."
            return
        }
        guard let script = activeScript ?? appState.activeScript else {
            overlayErrorMessage = "Open a script before casting to the notch."
            return
        }

        startOverlaySession(with: script)
    }

    private func castScriptToNotch(id: UUID) {
        guard !overlayController.hasActiveNotch else {
            overlayErrorMessage = "An overlay is already active. End the current session before casting again."
            return
        }
        do {
            let script = try appState.loadScript(id: id)
            startOverlaySession(with: script)
        } catch {
            overlayErrorMessage = error.localizedDescription
        }
    }


    private func installShortcutMonitors() {
        guard localShortcutMonitor == nil, globalShortcutMonitor == nil else {
            return
        }

        localShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleShortcutEvent(event)
            return event
        }

        globalShortcutMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            handleShortcutEvent(event)
        }
    }

    private func removeShortcutMonitors() {
        if let localShortcutMonitor {
            NSEvent.removeMonitor(localShortcutMonitor)
            self.localShortcutMonitor = nil
        }

        if let globalShortcutMonitor {
            NSEvent.removeMonitor(globalShortcutMonitor)
            self.globalShortcutMonitor = nil
        }
    }

    private func handleShortcutEvent(_ event: NSEvent) {
        let settings = appState.settings

        if KeyboardShortcutDisplay.matches(event: event, shortcut: settings.shortcutEndSession) {
            overlayController.endSession()
            restoreManagerWindow()
            return
        }

        if KeyboardShortcutDisplay.matches(event: event, shortcut: settings.shortcutToggleNotch) {
            toggleNotchShortcut()
            return
        }

        if KeyboardShortcutDisplay.matches(event: event, shortcut: settings.shortcutTogglePill) {
            togglePillShortcut()
            return
        }
    }

    private func toggleNotchShortcut() {
        if overlayController.hasActiveNotch {
            overlayController.endSession()
            restoreManagerWindow()
            return
        }

        do {
            let script = try defaultShortcutScript()
            startOverlaySession(with: script)
        } catch {
            overlayErrorMessage = error.localizedDescription
        }
    }

    private func togglePillShortcut() {
        guard appState.settings.pillsEnabled else {
            return
        }

        if overlayController.pillCount >= appState.settings.maxPillCount {
            overlayController.closeLastPill()
            return
        }

        do {
            let script = try defaultShortcutScript()
            overlayController.addPill(
                mode: .voiceSync,
                script: script,
                appearance: appState.settings.defaultOverlayAppearance,
                countdownDuration: appState.settings.countdownDuration,
                voiceSyncEnabled: appState.settings.voiceSyncEnabled,
                autoScrollWPM: ManualScrollConfiguration.clampedWPM(appState.settings.autoScrollWPM),
                voiceSyncMode: appState.settings.voiceSyncMode
            )
            miniaturizeManagerWindow()
        } catch {
            overlayErrorMessage = error.localizedDescription
        }
    }

    private func defaultShortcutScript() throws -> Script {
        if let activeScript {
            return activeScript
        }
        if let loadedScript = appState.activeScript {
            return loadedScript
        }
        guard let firstScript = appState.scripts.first else {
            throw NSError(domain: "Aira.Shortcuts", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Create or import a script before launching an overlay."
            ])
        }
        return try appState.loadScript(id: firstScript.id)
    }

    private func startOverlaySession(with script: Script) {
        overlayController.presentSession(
            script: script,
            appearance: appState.settings.defaultOverlayAppearance,
            countdownDuration: appState.settings.countdownDuration,
            voiceSyncEnabled: appState.settings.voiceSyncEnabled,
            autoScrollWPM: ManualScrollConfiguration.clampedWPM(appState.settings.autoScrollWPM),
            voiceSyncMode: appState.settings.voiceSyncMode,
            pillModes: enabledPillModes
        )
        miniaturizeManagerWindow()
    }

    private func startVoiceSyncKeyboardMonitor() {
        let settings = appState.settings
        voiceSyncKeyboardMonitor.start(
            toggleShortcut: settings.shortcutToggleVoiceSync,
            scrollUpShortcut: settings.shortcutScrollUp,
            scrollDownShortcut: settings.shortcutScrollDown,
            onToggle: {
                Task { @MainActor in
                    self.overlayController.voiceSync.togglePause()
                }
            },
            onScrollUp: {
                Task { @MainActor in
                    self.overlayController.voiceSync.requestManualLineNudge(direction: -1)
                }
            },
            onScrollDown: {
                Task { @MainActor in
                    self.overlayController.voiceSync.requestManualLineNudge(direction: 1)
                }
            }
        )
    }

    private func miniaturizeManagerWindow() {
        NSApp.hide(nil)
    }

    private func restoreManagerWindow() {
        let candidateWindow =
            managerWindow
            ?? NSApp.windows.first(where: { !($0 is NSPanel) })

        guard let managerWindow = candidateWindow else {
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        NSApp.unhide(nil)
        managerWindow.deminiaturize(nil)
        managerWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

}

enum ScriptEditorDismissDisposition: Equatable {
    case discardDraft
    case save
    case closeWithoutSaving
}

struct ScriptEditorSessionLogic {
    static func dismissDisposition(for editorScript: Script, persistedScript: Script?) -> ScriptEditorDismissDisposition {
        guard let persistedScript else {
            return shouldPersistDraft(editorScript) ? .save : .discardDraft
        }

        let hasChanges =
            editorScript.title != persistedScript.title ||
            editorScript.body != persistedScript.body

        return hasChanges ? .save : .closeWithoutSaving
    }

    static func shouldPersistDraft(_ script: Script) -> Bool {
        let trimmedBody = script.body.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedBody.isEmpty || script.title != "Untitled Script"
    }
}

private struct ManagerWindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            onResolve(nsView.window)
        }
    }
}

enum SidebarNav: Hashable {
    case allScripts
    case starred
    case recent
    case collection(UUID)
}
