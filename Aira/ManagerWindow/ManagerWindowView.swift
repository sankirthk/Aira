import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ManagerWindowView: View {
  private enum SidebarLayoutMetrics {
    static let expandedWidth: CGFloat = 230
  }

  @EnvironmentObject var appState: AppState
  @Environment(\.managerTheme) private var managerTheme
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
      .ignoresSafeArea(.container, edges: .top)
      .modifier(GlassToolbarModifier(enabled: true))
      .environment(
        \.managerTheme,
        ManagerTheme(interfaceStyle: appState.settings.managerInterfaceStyle)
      )
      .background(
        ManagerWindowAccessor { window in
          managerWindow = window
          AppWindowCoordinator.markManagerWindow(window)
          configureWindowChrome(window)
        }
      )
      .onChange(of: appState.settings.managerInterfaceStyle) { _, _ in
        configureWindowChrome(managerWindow)
      }
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
    mainLayout
  }

  private var usesLiquidGlassMode: Bool {
    appState.settings.managerInterfaceStyle == .liquidGlass
  }

  private enum LayoutMetrics {
    static let outerHorizontal: CGFloat = 8
    static let outerBottom: CGFloat = 8
    static let topInset: CGFloat = 0
    /// Vertical space the chrome band occupies — content area top aligns here.
    static let chromeBandHeight: CGFloat = SidebarView.SidebarChromeMetrics.height
    static let gap: CGFloat = 10
  }

  /// Unified layout for both modes:
  /// - Sidebar spans full height with chrome band at top.
  /// - Content area starts below the app chrome band while the root substrate
  ///   paints into the transparent native titlebar.
  /// - When collapsed, the sidebar disappears entirely. A compact toggle
  ///   pill sits top-left (overlaid), and the content area fills the width.
  ///   Traffic lights remain in the window's standard position.
  /// Visual treatment (glass effects vs solid colors) varies by mode.
  private var mainLayout: some View {
    ZStack(alignment: .topLeading) {
      HStack(alignment: .top, spacing: sidebarVisible ? LayoutMetrics.gap : 0) {
        if sidebarVisible {
          SidebarView(
            sidebarVisible: $sidebarVisible,
            selectedNav: sidebarSelectionBinding,
            pendingDeleteCollection: $pendingDeleteCollection,
            collectionErrorMessage: $collectionErrorMessage,
            canGoBack: canGoBack,
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
            },
            onGoBack: {
              dismissEditor()
            }
          )
          .frame(width: SidebarLayoutMetrics.expandedWidth)
          .frame(maxHeight: .infinity, alignment: .top)
          .padding(.bottom, LayoutMetrics.outerBottom)
          .transition(.move(edge: .leading).combined(with: .opacity))
        }

        contentArea
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .modifier(GlassContentAreaModifier())
          .padding(.top, LayoutMetrics.chromeBandHeight + LayoutMetrics.topInset)
          .padding(.bottom, LayoutMetrics.outerBottom)
      }

      // Collapsed: compact chrome strip at top-left with traffic lights + buttons
      if !sidebarVisible {
        collapsedSidebarPill
          .transition(.opacity)
      }
    }
    .padding(.top, LayoutMetrics.topInset)
    .padding(.horizontal, LayoutMetrics.outerHorizontal)
    .modifier(GlassWindowBackgroundModifier())
    .animation(.easeInOut(duration: 0.25), value: sidebarVisible)
  }

  /// Compact chrome strip shown when the sidebar is collapsed.
  /// Contains a traffic-light host (buttons appear on hover) followed by
  /// sidebar toggle, back, and forward buttons in a small pill.
  private var collapsedSidebarPill: some View {
    ZStack(alignment: .leading) {
      // Traffic light host — reparents the window buttons into this area.
      // They appear/hide via the host view's tracking area hover logic.
      SidebarView.SidebarTrafficLightBridge(sidebarVisible: $sidebarVisible)
        .frame(
          width: SidebarView.SidebarChromeMetrics.appControlLeading,
          height: SidebarView.SidebarChromeMetrics.height)

      // App control buttons — positioned after the traffic lights.
      HStack(spacing: 6) {
        collapsedChromeButton(
          help: "Show Sidebar",
          icon: .sidebar,
          iconOpacity: 0.80,
          action: {
            withAnimation(.easeInOut(duration: 0.2)) {
              sidebarVisible = true
            }
          }
        )

        collapsedChromeButton(
          help: "Go Back",
          icon: .back,
          iconOpacity: canGoBack ? 0.80 : 0.28,
          isEnabled: canGoBack,
          action: { dismissEditor() }
        )

        collapsedChromeButton(
          help: "Go Forward",
          icon: .forward,
          iconOpacity: 0.28,
          isEnabled: false,
          action: {}
        )
      }
      .padding(.leading, SidebarView.SidebarChromeMetrics.appControlLeading)
    }
    .frame(height: SidebarView.SidebarChromeMetrics.height)
  }

  private func collapsedChromeButton(
    help: String,
    icon: AiraIconType,
    iconOpacity: Double,
    isEnabled: Bool = true,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      AiraIcon(
        type: icon,
        size: 17,
        color: Color("colorText").opacity(iconOpacity),
        animated: false
      )
      .frame(width: 26, height: 26)
      .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .help(help)
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
        onCastWithSatellite: { id, selections in
          castScriptWithSatellite(id: id, satelliteSelections: selections)
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
          .font(
            managerTheme.usesLiquidGlassMode
              ? .system(size: 22, weight: .bold)
              : .custom("IndieFlower", size: 24)
          )
          .foregroundStyle(managerTheme.usesLiquidGlassMode ? .primary : Color("colorText"))

        Text("Deleting \"\(collection.name)\" will not delete any scripts.")
          .font(
            managerTheme.usesLiquidGlassMode
              ? .system(size: 14)
              : .custom("CrimsonText-Regular", size: 15)
          )
          .foregroundStyle(
            managerTheme.usesLiquidGlassMode ? .secondary : Color("colorText").opacity(0.72)
          )
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 10) {
          Button("Cancel") {
            pendingDeleteCollection = nil
          }
          .buttonStyle(AiraSecondaryButtonStyle())

          Button("Delete") {
            confirmDeleteCollection()
          }
          .buttonStyle(AiraCardCastButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .padding(20)
      .frame(width: 320)
      .managerSurface(cornerRadius: 20, classicFill: Color("colorBackground"), strokeOpacity: 0.12)
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

  private func configureWindowChrome(_ window: NSWindow?) {
    guard let window else { return }
    configureManagerFullscreenBehavior(window)
    configureManagerTitlebar(window)
  }

  private func configureManagerTitlebar(_ window: NSWindow) {
    if !window.styleMask.contains(.titled) {
      window.styleMask.insert(.titled)
    }
    if !window.styleMask.contains(.fullSizeContentView) {
      window.styleMask.insert(.fullSizeContentView)
    }
    if window.titleVisibility != .hidden {
      window.titleVisibility = .hidden
    }
    if window.titlebarAppearsTransparent == false {
      window.titlebarAppearsTransparent = true
    }
    if window.titlebarSeparatorStyle != .none {
      window.titlebarSeparatorStyle = .none
    }
    if window.toolbar != nil {
      window.toolbar = nil
    }
    if window.isOpaque {
      window.isOpaque = false
    }
    if window.backgroundColor != .clear {
      window.backgroundColor = .clear
    }
  }

  private func configureManagerFullscreenBehavior(_ window: NSWindow) {
    window.collectionBehavior.remove(.fullScreenPrimary)
    window.collectionBehavior.remove(.fullScreenAuxiliary)
    window.collectionBehavior.insert(.fullScreenNone)
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

  private func castScriptWithSatellite(id: UUID, satelliteSelections: [SatelliteLaunchSelection]) {
    guard !overlayController.hasActiveNotch else {
      overlayErrorMessage =
        "An overlay is already active. End the current session before casting again."
      return
    }
    do {
      let script = try appState.loadScript(id: id)
      startOverlaySession(with: script, launchIntent: .assignedSatellites(satelliteSelections))
    } catch {
      AiraLogger.shared.error(
        error, category: "session",
        context: "Failed to cast script \(id.uuidString) with satellites")
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
        voiceSyncEnabled: appState.settings.voiceDrivenScrollEnabled,
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
        voiceSyncEnabled: appState.settings.voiceDrivenScrollEnabled,
        autoScrollWPM: ManualScrollConfiguration.clampedWPM(appState.settings.autoScrollWPM),
        voiceSyncMode: appState.settings.voiceSyncMode
      )
    case .mirroredSatellites(let count):
      overlayController.presentMirroredSatelliteSession(
        script: script,
        appearance: appState.settings.defaultOverlayAppearance,
        countdownDuration: appState.settings.countdownDuration,
        satelliteCount: count,
        voiceSyncEnabled: appState.settings.voiceDrivenScrollEnabled,
        autoScrollWPM: ManualScrollConfiguration.clampedWPM(appState.settings.autoScrollWPM),
        voiceSyncMode: appState.settings.voiceSyncMode
      )
    case .assignedSatellites(let satelliteSelections):
      overlayController.presentAssignedSatelliteSession(
        script: script,
        appearance: appState.settings.defaultOverlayAppearance,
        countdownDuration: appState.settings.countdownDuration,
        voiceSyncEnabled: appState.settings.voiceDrivenScrollEnabled,
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

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    Task { @MainActor in
      context.coordinator.resolveIfNeeded(view.window, onResolve: onResolve)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    Task { @MainActor in
      context.coordinator.resolveIfNeeded(nsView.window, onResolve: onResolve)
    }
  }

  @MainActor
  final class Coordinator {
    private weak var resolvedWindow: NSWindow?

    func resolveIfNeeded(_ window: NSWindow?, onResolve: (NSWindow?) -> Void) {
      guard window !== resolvedWindow else { return }
      resolvedWindow = window
      AppWindowCoordinator.markManagerWindow(window)
      onResolve(window)
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

/// Removes visible SwiftUI title chrome while keeping the native window
/// controls alive. Hiding the entire window toolbar also hides the traffic
/// lights on current macOS.
private struct GlassToolbarModifier: ViewModifier {
  let enabled: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled {
      if #available(macOS 15.0, *) {
        content
          .toolbar(removing: .title)
          .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
      } else {
        content
      }
    } else {
      content
    }
  }
}

/// Styled frame for the main content area.
/// Glass mode: frosted sage glass backing. Classic mode: solid cream.
private struct GlassContentAreaModifier: ViewModifier {
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  private var usesGlass: Bool { managerTheme.usesLiquidGlassMode }
  private var isDark: Bool { colorScheme == .dark }
  private var cornerRadius: CGFloat { ManagerLayoutParity.contentAreaCornerRadius }

  @ViewBuilder
  func body(content: Content) -> some View {
    if usesGlass {
      content
        .background {
          ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              .fill(
                isDark ? Color(hex: "#3E4A40").opacity(0.25) : Color(hex: "#D5DCCF").opacity(0.18))
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
              isDark ? Color.white.opacity(0.18) : Color.white.opacity(0.50),
              lineWidth: 0.5
            )
        }
    } else {
      content
        .background(Color("colorBackground"))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
  }
}

/// Background for the entire window container.
/// Glass mode: app-owned sage/dark-green substrate. Classic mode: solid sage.
private struct GlassWindowBackgroundModifier: ViewModifier {
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  private var usesGlass: Bool { managerTheme.usesLiquidGlassMode }
  private var isDark: Bool { colorScheme == .dark }

  private var baseColor: Color {
    isDark ? Color(hex: "#253D2E") : Color(hex: "#849688")
  }

  @ViewBuilder
  func body(content: Content) -> some View {
    if usesGlass {
      content
        .background {
          ZStack {
            // Opaque root substrate normalizes wallpaper bleed before child glass samples it.
            baseColor

            if isDark {
              Color.black.opacity(0.10)
            }

            // Subtle depth gradient
            RadialGradient(
              colors: [
                Color.white.opacity(isDark ? 0.04 : 0.18),
                Color.black.opacity(isDark ? 0.12 : 0.04),
              ],
              center: .center, startRadius: 80, endRadius: 520
            )
          }
          .ignoresSafeArea(.container, edges: .top)
        }
    } else {
      content
        .background(isDark ? Color(hex: "#465649") : Color("colorPrimary"))
        .ignoresSafeArea(.container, edges: .top)
    }
  }
}

enum SidebarNav: Hashable {
  case allScripts
  case starred
  case recent
  case collection(UUID)
}
