import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ManagerWindowView: View {
  @EnvironmentObject var appState: AppState
  let overlayController: OverlayWindowController
  @State private var managerShortcutCoordinator = ManagerShortcutCoordinator()
  @State private var selectedNav: SidebarNav = .allScripts
  @State private var activeScript: Script? = nil
  @State private var sidebarVisible: Bool = true
  @State private var creationErrorMessage: String? = nil
  @State private var importErrorMessage: String? = nil
  @State private var dismissErrorMessage: String? = nil
  @State private var overlayErrorMessage: String? = nil
  @State private var sessionRestrictionMessage: String? = nil
  @State private var collectionErrorMessage: String? = nil
  @State private var pendingDeleteCollection: AiraCollection? = nil
  @State private var managerWindow: NSWindow?
  var canGoBack: Bool { activeScript != nil }

  var body: some View {
    contentView
      .frame(minWidth: 900, minHeight: 600)
      .background(
        ManagerWindowAccessor { window in
          managerWindow = window
          AppWindowCoordinator.markManagerWindow(window)
        }
      )
      .modifier(
        ManagerWindowAlerts(
          creationErrorBinding: creationErrorBinding,
          creationErrorMessage: creationErrorMessage,
          importErrorBinding: importErrorBinding,
          importErrorMessage: importErrorMessage,
          dismissErrorBinding: dismissErrorBinding,
          dismissErrorMessage: dismissErrorMessage,
          sessionRestrictionBinding: sessionRestrictionBinding,
          sessionRestrictionMessage: sessionRestrictionMessage,
          collectionErrorBinding: collectionErrorBinding,
          collectionErrorMessage: collectionErrorMessage
        )
      )
      .overlay {
        if let pendingDeleteCollection {
          deleteCollectionOverlay(collection: pendingDeleteCollection)
        }
      }
      .overlay {
        if let overlayErrorMessage {
          AiraMessagePopup(
            content: .launchOverlayError(message: overlayErrorMessage),
            onDismiss: {
              self.overlayErrorMessage = nil
            }
          )
          .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
      }
      .onAppear {
        overlayController.appState = appState
        refreshShortcutMonitors()
      }
      .onChange(of: appState.sessionActive) { _, isActive in
        // Restore the manager window whenever a session ends — regardless of whether
        // it ended via keyboard shortcut, overlay context menu, or any other path.
        if !isActive {
          restoreManagerWindow()
        }
      }
      .onReceive(NotificationCenter.default.publisher(for: .airaNewScript)) { _ in
        createAndOpenScript()
      }
      .onReceive(NotificationCenter.default.publisher(for: .airaImportScript)) { _ in
        importScriptFromPicker()
      }
      .onReceive(NotificationCenter.default.publisher(for: .airaCloseCurrent)) { _ in
        handleCloseCommand()
      }
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
      ) { _ in
        if !appState.sessionActive {
          restoreManagerWindow()
        }
        // Re-install shortcut monitors each time the app becomes active.
        // This upgrades the NSEvent fallback to a proper CGEventTap if the
        // user just granted Accessibility in System Settings and switched back.
        refreshShortcutMonitors()
      }
      .task(id: managerShortcutConfiguration) {
        refreshShortcutMonitors()
      }
  }

  private var contentView: some View {
    VStack(spacing: 0) {
      topBar
      mainLayout
    }
  }

  private var topBar: some View {
    HStack(spacing: 4) {
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

      Button {
        dismissEditor()
      } label: {
        AiraIcon(
          type: .back,
          size: 20,
          color: Color("colorText").opacity(canGoBack ? 1 : 0.3)
        )
        .padding(8)
      }
      .buttonStyle(.plain)
      .disabled(!canGoBack)
      .help("Go Back")

      Button {
      } label: {
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
      Rectangle()
        .fill(Color("colorText").opacity(0.12))
        .frame(height: 1)
    }
  }

  private var mainLayout: some View {
    HStack(alignment: .top, spacing: 0) {
      if sidebarVisible {
        SidebarView(
          selectedNav: sidebarSelectionBinding,
          pendingDeleteCollection: $pendingDeleteCollection,
          collectionErrorMessage: $collectionErrorMessage,
          onOpenSettings: {
            presentSettings()
          },
          onNewScript: {
            createAndOpenScript()
          },
          onOpenScript: { id in
            openScriptFromSidebar(id: id)
          },
          onMoveScriptToCollection: { scriptID, collectionID in
            moveScript(scriptID, toCollection: collectionID)
          }
        )
        .frame(width: 230)
        .frame(maxHeight: .infinity, alignment: .top)

        Divider()
          .background(Color.black.opacity(0.4))
      }

      contentArea
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("colorBackground"))
    }
  }

  @ViewBuilder
  private var contentArea: some View {
    if activeScript != nil {
      ScriptEditorView(
        script: activeScriptBinding,
        managerFontScale: CGFloat(appState.settings.managerTypography.scaleFactor),
        isReadOnly: activeEditorIsLockedForSession,
        onCast: {
          castCurrentScriptToNotch()
        },
        onCastWithSatellite: { satelliteSelections in
          castCurrentScriptWithSatellite(satelliteSelections: satelliteSelections)
        },
        onBack: {
          dismissEditor()
        }
      )
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

  private var collectionErrorBinding: Binding<Bool> {
    Binding(
      get: { collectionErrorMessage != nil },
      set: { isPresented in
        if !isPresented {
          collectionErrorMessage = nil
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
    if case .collection(let id) = selectedNav {
      collectionID = id
    } else {
      collectionID = nil
    }

    appState.activeScript = nil
    activeScript = appState.makeDraftScript(inCollection: collectionID)
  }

  @ViewBuilder
  private func deleteCollectionOverlay(collection: AiraCollection) -> some View {
    ZStack {
      Color.black.opacity(0.18)
        .ignoresSafeArea()
        .onTapGesture {
          pendingDeleteCollection = nil
        }

      VStack(alignment: .leading, spacing: 12) {
        Text("Delete Collection?")
          .font(.custom("IndieFlower", size: 24))
          .foregroundStyle(Color("colorText"))

        Text("Deleting \"\(collection.name)\" will not delete any scripts.")
          .font(.custom("CrimsonText-Regular", size: 15))
          .foregroundStyle(Color("colorText").opacity(0.72))
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 10) {
          Button("Cancel") {
            pendingDeleteCollection = nil
          }
          .buttonStyle(AiraSecondaryButtonStyle())

          Button("Delete") {
            confirmDeleteCollection()
          }
          .buttonStyle(AiraPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .padding(20)
      .frame(width: 320)
      .background(Color("colorBackground"))
      .clipShape(RoundedRectangle(cornerRadius: 20))
      .overlay(
        RoundedRectangle(cornerRadius: 20)
          .stroke(Color("colorText").opacity(0.12), lineWidth: 1.5)
      )
      .shadow(color: Color.black.opacity(0.12), radius: 18, y: 10)
      .padding(16)
    }
  }

  private func confirmDeleteCollection() {
    guard let collection = pendingDeleteCollection else {
      return
    }

    do {
      try appState.deleteCollection(id: collection.id)
      selectedNav = CollectionSidebarLogic.selectedNavAfterDeletingCollection(
        collection.id,
        selectedNav: selectedNav
      )
      pendingDeleteCollection = nil
    } catch {
      collectionErrorMessage = error.localizedDescription
    }
  }

  private func moveScript(_ scriptID: UUID, toCollection collectionID: UUID) {
    do {
      let script = try appState.readScript(id: scriptID)
      let nextCollectionIDs = DocumentLibraryMoveScriptLogic.updatedCollectionIDs(
        existingCollectionIDs: script.collectionIds,
        adding: collectionID
      )
      try appState.updateScriptCollections(id: scriptID, collectionIDs: nextCollectionIDs)
    } catch {
      collectionErrorMessage = error.localizedDescription
    }
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
        activeScript ?? appState.activeScript
          ?? Script(
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

  private var managerShortcutConfiguration: ManagerShortcutCoordinator.Configuration {
    .init(
      toggleNotch: appState.settings.shortcutToggleNotch,
      togglePill: appState.settings.shortcutTogglePill
    )
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
      switch ScriptEditorSessionLogic.dismissDisposition(
        for: script, persistedScript: persistedScript)
      {
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
      AiraLogger.shared.error(error, category: "editor", context: "Failed to dismiss editor")
      dismissErrorMessage = error.localizedDescription
      return false
    }
  }

  private func importScriptFromPicker() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.plainText, .pdf, UTType(filenameExtension: "docx")].compactMap {
      $0
    }

    guard panel.runModal() == .OK, let url = panel.url else {
      return
    }

    do {
      let script = try appState.importScript(from: url, inCollection: selectedCollectionID)
      if selectedCollectionID == nil {
        selectedNav = .allScripts
      }
      activeScript = script
    } catch {
      AiraLogger.shared.error(
        error, category: "import", context: "Failed to import script from picker")
      importErrorMessage = error.localizedDescription
    }
  }

  private var selectedCollectionID: UUID? {
    if case .collection(let id) = selectedNav {
      return id
    }
    return nil
  }

  private func handleCloseCommand() {
    if activeScript != nil {
      _ = dismissEditor()
      return
    }

    managerWindow?.performClose(nil)
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
      AiraLogger.shared.error(
        error, category: "editor", context: "Failed to open script \(id.uuidString)")
      creationErrorMessage = error.localizedDescription
    }
  }

  private func castCurrentScriptToNotch() {
    guard !overlayController.hasActiveNotch else {
      overlayErrorMessage =
        "An overlay is already active. End the current session before casting again."
      return
    }
    guard let script = activeScript ?? appState.activeScript else {
      overlayErrorMessage = "Open a script before casting to the notch."
      return
    }

    startOverlaySession(with: script, launchIntent: .notchOnly)
  }

  private func castCurrentScriptWithSatellite(
    satelliteSelections: [SatelliteLaunchSelection]
  ) {
    guard !overlayController.hasActiveNotch else {
      overlayErrorMessage =
        "An overlay is already active. End the current session before casting again."
      return
    }
    guard let script = activeScript ?? appState.activeScript else {
      overlayErrorMessage = "Open a script before casting with Pill Windows."
      return
    }

    startOverlaySession(with: script, launchIntent: .assignedSatellites(satelliteSelections))
  }

  private func castScriptToNotch(id: UUID) {
    guard !overlayController.hasActiveNotch else {
      overlayErrorMessage =
        "An overlay is already active. End the current session before casting again."
      return
    }
    do {
      let script = try appState.loadScript(id: id)
      startOverlaySession(with: script, launchIntent: .notchOnly)
    } catch {
      AiraLogger.shared.error(
        error, category: "session", context: "Failed to cast script \(id.uuidString) to notch")
      overlayErrorMessage = error.localizedDescription
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
      startOverlaySession(with: script, launchIntent: .notchOnly)
    } catch {
      AiraLogger.shared.error(
        error, category: "session", context: "Failed to toggle notch shortcut")
      overlayErrorMessage = error.localizedDescription
    }
  }

  private func togglePillShortcut() {
    if overlayController.pillCount >= appState.settings.maxPillCount {
      overlayController.closeLastPill()
      return
    }

    do {
      let script = try defaultShortcutScript()
      guard PillLaunchPolicy.canLaunchPill(with: script) else {
        overlayErrorMessage = "Add script text before casting to a Pill Window."
        return
      }

      let launched = overlayController.addPill(
        mode: .voiceSync,
        script: script,
        appearance: appState.settings.effectiveSatelliteAppearance(
          forSlot: overlayController.pillCount + 1
        ),
        countdownDuration: appState.settings.countdownDuration,
        voiceSyncEnabled: appState.settings.voiceSyncEnabled,
        autoScrollWPM: ManualScrollConfiguration.clampedWPM(appState.settings.autoScrollWPM),
        voiceSyncMode: appState.settings.voiceSyncMode
      )
      if launched {
        miniaturizeManagerWindow()
      }
    } catch {
      AiraLogger.shared.error(error, category: "session", context: "Failed to toggle pill shortcut")
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
      throw NSError(
        domain: "Aira.Shortcuts", code: 1,
        userInfo: [
          NSLocalizedDescriptionKey: "Create or import a script before launching an overlay."
        ])
    }
    return try appState.loadScript(id: firstScript.id)
  }

  private func startOverlaySession(
    with script: Script,
    launchIntent: OverlaySessionLaunchIntent
  ) {
    guard ScriptEditorSessionLogic.canStartPresenterSession(withBody: script.body) else {
      overlayErrorMessage = "Add script text before casting to the notch."
      return
    }

    // Hide the manager window and remove from Dock/⌘+Tab before presenting overlays.
    // Doing this first ensures panels are ordered-front while the app is already in
    // accessory mode — switching policy AFTER panels appear can cause macOS to hide them.
    miniaturizeManagerWindow()
    switch launchIntent {
    case .notchOnly:
      overlayController.presentSession(
        script: script,
        appearance: appState.settings.defaultOverlayAppearance,
        countdownDuration: appState.settings.countdownDuration,
        voiceSyncEnabled: appState.settings.voiceSyncEnabled,
        autoScrollWPM: ManualScrollConfiguration.clampedWPM(appState.settings.autoScrollWPM),
        voiceSyncMode: appState.settings.voiceSyncMode
      )
    case .mirroredSatellites(let count):
      overlayController.presentMirroredSatelliteSession(
        script: script,
        appearance: appState.settings.defaultOverlayAppearance,
        countdownDuration: appState.settings.countdownDuration,
        satelliteCount: count,
        voiceSyncEnabled: appState.settings.voiceSyncEnabled,
        autoScrollWPM: ManualScrollConfiguration.clampedWPM(appState.settings.autoScrollWPM),
        voiceSyncMode: appState.settings.voiceSyncMode
      )
    case .assignedSatellites(let satelliteSelections):
      overlayController.presentAssignedSatelliteSession(
        script: script,
        appearance: appState.settings.defaultOverlayAppearance,
        countdownDuration: appState.settings.countdownDuration,
        voiceSyncEnabled: appState.settings.voiceSyncEnabled,
        autoScrollWPM: ManualScrollConfiguration.clampedWPM(appState.settings.autoScrollWPM),
        voiceSyncMode: appState.settings.voiceSyncMode,
        satelliteSelections: satelliteSelections
      )
    }
  }

  private func miniaturizeManagerWindow() {
    AppWindowCoordinator.hideManagerWindowForSession()
  }

  private func restoreManagerWindow() {
    AppWindowCoordinator.restoreManagerWindow(fallbackWindow: managerWindow)
    refreshShortcutMonitors()
  }

  private func refreshShortcutMonitors() {
    managerShortcutCoordinator.start(
      settings: appState.settings,
      onToggleNotch: { [self] in
        toggleNotchShortcut()
      },
      onTogglePill: { [self] in
        togglePillShortcut()
      }
    )
    overlayController.refreshSessionKeyboardMonitorsIfNeeded()
  }

  private func presentSettings() {
    restoreManagerWindow()
    SettingsWindowController.shared.present(appState: appState)
  }

}

enum ScriptEditorDismissDisposition: Equatable {
  case discardDraft
  case save
  case closeWithoutSaving
}

struct ScriptEditorSessionLogic {
  static func dismissDisposition(for editorScript: Script, persistedScript: Script?)
    -> ScriptEditorDismissDisposition
  {
    guard let persistedScript else {
      return shouldPersistDraft(editorScript) ? .save : .discardDraft
    }

    let hasChanges =
      editorScript.title != persistedScript.title || editorScript.body != persistedScript.body

    return hasChanges ? .save : .closeWithoutSaving
  }

  static func shouldPersistDraft(_ script: Script) -> Bool {
    let trimmedBody = script.body.trimmingCharacters(in: .whitespacesAndNewlines)
    return !trimmedBody.isEmpty || script.title != "Untitled Script"
  }

  static func canStartPresenterSession(withBody body: String) -> Bool {
    !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

private struct ManagerWindowAlerts: ViewModifier {
  let creationErrorBinding: Binding<Bool>
  let creationErrorMessage: String?
  let importErrorBinding: Binding<Bool>
  let importErrorMessage: String?
  let dismissErrorBinding: Binding<Bool>
  let dismissErrorMessage: String?
  let sessionRestrictionBinding: Binding<Bool>
  let sessionRestrictionMessage: String?
  let collectionErrorBinding: Binding<Bool>
  let collectionErrorMessage: String?

  func body(content: Content) -> some View {
    content
      .alert("Unable to Create Script", isPresented: creationErrorBinding) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(creationErrorMessage ?? "Please try again.")
      }
      .alert("Unable to Import Script", isPresented: importErrorBinding) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(importErrorMessage ?? "Please try again.")
      }
      .alert("Unable to Close Editor", isPresented: dismissErrorBinding) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(dismissErrorMessage ?? "Please try again.")
      }
      .alert("Action Unavailable During Live Session", isPresented: sessionRestrictionBinding) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(sessionRestrictionMessage ?? "End the active session and try again.")
      }
      .alert("Collection Action Failed", isPresented: collectionErrorBinding) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(collectionErrorMessage ?? "Please try again.")
      }
  }
}

private struct ManagerWindowAccessor: NSViewRepresentable {
  let onResolve: (NSWindow?) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    Task { @MainActor in
      AppWindowCoordinator.markManagerWindow(view.window)
      onResolve(view.window)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    Task { @MainActor in
      AppWindowCoordinator.markManagerWindow(nsView.window)
      onResolve(nsView.window)
    }
  }
}

@MainActor
final class ManagerShortcutCoordinator {
  struct Configuration: Equatable {
    let toggleNotch: String
    let togglePill: String
  }

  private let monitor = KeyboardShortcutMonitor()

  func start(
    settings: AppSettings,
    onToggleNotch: @escaping () -> Void,
    onTogglePill: @escaping () -> Void
  ) {
    monitor.start(
      bindings: Self.bindings(
        for: settings,
        onToggleNotch: onToggleNotch,
        onTogglePill: onTogglePill
      ),
      promptForAccessibility: false
    )
  }

  func stop() {
    monitor.stop()
  }

  static func bindings(
    for settings: AppSettings,
    onToggleNotch: @escaping () -> Void,
    onTogglePill: @escaping () -> Void
  ) -> [KeyboardShortcutMonitor.Binding] {
    [
      .init(shortcut: settings.shortcutToggleNotch, action: onToggleNotch),
      .init(shortcut: settings.shortcutTogglePill, action: onTogglePill),
    ]
  }
}

enum SidebarNav: Hashable {
  case allScripts
  case starred
  case recent
  case collection(UUID)
}
