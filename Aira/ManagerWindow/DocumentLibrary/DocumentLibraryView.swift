import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DocumentLibraryView: View {
  private enum DeleteConfirmation: Identifiable {
    case single(ScriptMeta)
    case bulk(count: Int)

    var id: String {
      switch self {
      case .single(let meta):
        return "single-\(meta.id.uuidString)"
      case .bulk(let count):
        return "bulk-\(count)"
      }
    }
  }

  @EnvironmentObject var appState: AppState
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme
  let filter: SidebarNav
  var onEdit: (Script) -> Void
  var onNewScript: () -> Void
  var onCast: (UUID) -> Void
  var onCastWithSatellite: (UUID, [SatelliteLaunchSelection]) -> Void = { _, _ in }

  @State private var isDragTargeted: Bool = false
  @State private var deleteConfirmation: DeleteConfirmation? = nil
  @State private var libraryErrorMessage: String? = nil
  @State private var bulkSelection = DocumentLibraryBulkSelection()
  @State private var escapeKeyMonitor: Any?
  @State private var isSelectAllHovered: Bool = false
  @State private var collectionManagerScriptID: UUID? = nil
  @State private var isCreatingCollectionFromManager = false
  @State private var newCollectionName = ""
  @State private var satelliteCastScriptID: UUID? = nil
  @State private var isSatellitePanelPresented = false
  @State private var satelliteLaunchPanelState = ScriptEditorSatelliteLaunchPanelState(sections: [])

  var filteredScripts: [ScriptMeta] {
    DocumentLibraryFilterLogic.filteredScripts(
      scripts: appState.scripts,
      filter: filter,
      collections: appState.collections
    )
  }

  var pageTitle: String {
    switch filter {
    case .allScripts: return "Scripts"
    case .starred: return "Starred"
    case .recent: return "Recent"
    case .collection(let id):
      return appState.collections.first(where: { $0.id == id })?.name ?? "Collection"
    }
  }

  var pageSubtitle: String {
    switch filter {
    case .allScripts: return "Manage and organize your presentation scripts"
    case .starred: return "Scripts you've starred"
    case .recent: return "Recently edited scripts"
    case .collection: return "Scripts in this collection"
    }
  }

  private var visibleScriptIDs: [UUID] {
    filteredScripts.map(\.id)
  }

  private var selectedScriptCount: Int {
    bulkSelection.selectedScriptIDs.count
  }

  private var showsBulkSelectionControls: Bool {
    DocumentLibrarySessionRules.showsBulkSelectionControls(
      sessionActive: appState.sessionActive,
      visibleScriptCount: visibleScriptIDs.count
    )
  }

  private var deletionIsAvailable: Bool {
    DocumentLibrarySessionRules.allowsDeletion(sessionActive: appState.sessionActive)
  }

  private var usesGlass: Bool {
    managerTheme.surfaceTreatment == .nativeGlass
  }

  private var isDarkMode: Bool {
    colorScheme == .dark
  }

  private var headerTitleColor: Color {
    if managerTheme.colorPalette == .aira {
      return isDarkMode ? Color(hex: "#E8E2D6") : Color(hex: "#263126")
    }
    return Color("colorText")
  }

  private var headerSubtitleColor: Color {
    if managerTheme.colorPalette == .aira {
      return isDarkMode ? Color(hex: "#D8D0C2").opacity(0.72) : Color(hex: "#566454")
    }
    return Color("colorText").opacity(0.70)
  }

  private var scriptsAreaControlFill: Color {
    if managerTheme.colorPalette == .aira {
      return isDarkMode ? Color.black.opacity(0.12) : Color.white.opacity(0.25)
    }
    return managerTheme.controlFill(for: colorScheme)
  }

  private var selectAllLabelColor: Color {
    if managerTheme.colorPalette == .aira {
      return isDarkMode ? Color(hex: "#E8E2D6") : Color(hex: "#263126")
    }
    return Color("colorText")
  }

  private var selectAllIdleOpacity: Double {
    isDarkMode ? 0.78 : 0.92
  }

  private var headerTitleFont: Font {
    usesGlass
      ? .system(size: scaled(36), weight: .regular, design: .default)
      : .custom("IndieFlower", size: scaled(36))
  }

  private var headerSubtitleFont: Font {
    usesGlass
      ? .system(size: scaled(14), weight: .regular, design: .default)
      : .custom("CrimsonText-Regular", size: scaled(14))
  }

  private func scaled(_ size: CGFloat) -> CGFloat {
    size * managerFontScale
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {

      // MARK: Header
      HStack(alignment: .top) {
        Text(pageTitle)
          .font(headerTitleFont)
          .foregroundStyle(headerTitleColor)
        Spacer()
        if filter == .allScripts {
          Button {
            onNewScript()
          } label: {
            Label("New Script", systemImage: "plus")
              .lineLimit(1)
          }
          .buttonStyle(AiraLibraryHeaderPrimaryButtonStyle())
        }
      }
      .frame(height: ManagerLayoutParity.documentLibraryHeaderHeight, alignment: .topLeading)
      .padding(.horizontal, ManagerLayoutParity.documentLibraryOuterPadding)
      .padding(.top, ManagerLayoutParity.documentLibraryOuterPadding)
      .padding(.bottom, 12)

      selectionBar

      // MARK: Content
      if appState.scripts.isEmpty {
        Spacer()
        EmptyLibraryView(onNewScript: onNewScript)
        Spacer()
      } else if filteredScripts.isEmpty {
        Spacer()
        EmptyFilteredLibraryView(filter: filter, onNewScript: onNewScript)
        Spacer()
      } else {
        ScrollView {
          scriptGrid
            .padding(ManagerLayoutParity.documentLibraryGridPadding)
        }
        .padding(.bottom, ManagerLayoutParity.documentLibraryGridPadding)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(ManagerLayoutParity.documentLibraryOuterPadding)
    .onDrop(of: [UTType.fileURL], isTargeted: $isDragTargeted) { providers in
      handleDrop(providers: providers)
    }
    .overlay(alignment: .topLeading) {
      if isDragTargeted {
        RoundedRectangle(cornerRadius: 12)
          .stroke(managerTheme.actionAccent(for: colorScheme), lineWidth: 2)
          .padding(8)
          .allowsHitTesting(false)
      }
    }
    .alert("Library Action Failed", isPresented: libraryErrorBinding) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(libraryErrorMessage ?? "Please try again.")
    }
    .overlay {
      if let deleteConfirmation {
        deleteConfirmationOverlay(deleteConfirmation)
      } else if let collectionManagerScriptID {
        collectionManagerOverlay(scriptID: collectionManagerScriptID)
      } else if isSatellitePanelPresented {
        satelliteLaunchOverlay
      }
    }
    .onChange(of: visibleScriptIDs) { _, newVisibleIDs in
      bulkSelection.selectedScriptIDs = bulkSelection.selectedScriptIDs.intersection(
        Set(newVisibleIDs))
      if bulkSelection.selectedScriptIDs.isEmpty {
        bulkSelection.lastSelectedScriptID = nil
      }
    }
    .onChange(of: appState.sessionActive) { _, isActive in
      guard isActive else { return }
      bulkSelection = DocumentLibraryBulkSelection()
      deleteConfirmation = nil
    }
    .onAppear {
      installEscapeKeyMonitor()
    }
    .onDisappear {
      removeEscapeKeyMonitor()
    }

  }

  private var scriptGrid: some View {
    let scripts = filteredScripts
    let rowCount = (scripts.count + 1) / 2

    return VStack(spacing: 12) {
      ForEach(0..<rowCount, id: \.self) { rowIndex in
        HStack(spacing: 12) {
          scriptCard(for: scripts[rowIndex * 2])
          if rowIndex * 2 + 1 < scripts.count {
            scriptCard(for: scripts[rowIndex * 2 + 1])
          } else {
            Spacer()
              .frame(maxWidth: .infinity)
          }
        }
      }
    }
  }

  private func scriptCard(for meta: ScriptMeta) -> some View {
    ScriptCardView(
      meta: meta,
      isSelected: bulkSelection.selectedScriptIDs.contains(meta.id),
      showsSelectionControls: !appState.sessionActive && bulkSelection.isSelectionMode,
      selectionIsAvailable: !appState.sessionActive,
      editingIsAvailable: DocumentLibrarySessionRules.allowsEditing(
        scriptID: meta.id,
        activeSessionScriptIDs: appState.activeSessionScriptIDs
      ),
      deletionIsAvailable: deletionIsAvailable,
      onEdit: {
        editScript(meta.id)
      },
      onCast: {
        onCast(meta.id)
      },
      onRequestCastWithSatellite: {
        satelliteCastScriptID = meta.id
        satelliteLaunchPanelState = ScriptEditorSatelliteLaunchPanelState.make(
          enabledSatelliteCount: appState.settings.clampedMaxPillCount
        )
        isSatellitePanelPresented = true
      },
      onDelete: {
        if deletionIsAvailable {
          deleteConfirmation = .single(meta)
        } else {
          libraryErrorMessage = "End the active session before deleting scripts."
        }
      },
      onManageCollections: {
        presentCollectionManager(for: meta.id)
      },
      onToggleStarred: {
        toggleStarred(meta.id)
      },
      onToggleSelection: {
        bulkSelection.toggleSingle(meta.id)
      },
      onCardTap: {
        handleCardTap(for: meta.id)
      }
    )
    .frame(maxWidth: .infinity)
  }

  private var selectionBar: some View {
    HStack {
      Button {
        bulkSelection.toggleSelectAll(visibleScriptIDs: visibleScriptIDs)
      } label: {
        HStack(spacing: 10) {
          selectAllIndicator
          Text("Select All")
            .font(.custom("CrimsonText-Regular", size: scaled(15)))
            .foregroundStyle(selectAllLabelColor)
        }
      }
      .buttonStyle(.plain)
      .opacity(
        showsBulkSelectionControls
          ? ((isSelectAllHovered || bulkSelection.isSelectionMode) ? 1 : selectAllIdleOpacity)
          : 0.50
      )
      .disabled(!showsBulkSelectionControls)
      .onHover { isHovering in
        isSelectAllHovered = isHovering
      }

      Spacer()

      Button {
        deleteConfirmation = .bulk(count: selectedScriptCount)
      } label: {
        Image(systemName: "trash")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Color.red)
          .padding(10)
          .background(
            usesGlass
              ? AnyView(
                RoundedRectangle(cornerRadius: 10)
                  .fill(Color.white.opacity(0.10))
                  .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10)))
              : AnyView(scriptsAreaControlFill)
          )
          .clipShape(RoundedRectangle(cornerRadius: 10))
      }
      .buttonStyle(.plain)
      .opacity(
        showsBulkSelectionControls
          ? (bulkSelection.isSelectionMode ? 1 : 0.50)
          : 0.30
      )
      .disabled(!showsBulkSelectionControls || !bulkSelection.isSelectionMode)
    }
    .padding(.horizontal, ManagerLayoutParity.documentLibraryOuterPadding)
    .padding(.bottom, 12)
  }

  private var selectAllIndicator: some View {
    let state = bulkSelection.selectAllState(visibleScriptIDs: visibleScriptIDs)
    let isFilled = state != .none
    return ZStack {
      RoundedRectangle(cornerRadius: 4)
        .fill(
          usesGlass
            ? (isFilled ? managerTheme.actionAccent(for: colorScheme) : Color.primary.opacity(0.08))
            : (isFilled ? managerTheme.actionAccent(for: colorScheme) : scriptsAreaControlFill)
        )
        .frame(width: 18, height: 18)
        .overlay(
          RoundedRectangle(cornerRadius: 4)
            .stroke(
              usesGlass
                ? (isFilled ? Color.clear : Color.primary.opacity(0.45))
                : Color("colorText").opacity(0.28),
              lineWidth: 1.5
            )
        )

      switch state {
      case .none:
        EmptyView()
      case .mixed:
        RoundedRectangle(cornerRadius: 1)
          .fill(
            usesGlass
              ? managerTheme.readableAccentForeground(
                for: colorScheme,
                accent: managerTheme.actionAccent(for: colorScheme)
              )
              : managerTheme.actionAccent(for: colorScheme)
          )
          .frame(width: 10, height: 2.5)
      case .all:
        Image(systemName: "checkmark")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(
            usesGlass
              ? managerTheme.readableAccentForeground(
                for: colorScheme,
                accent: managerTheme.actionAccent(for: colorScheme)
              )
              : managerTheme.actionAccent(for: colorScheme))
      }
    }
  }

  private var libraryErrorBinding: Binding<Bool> {
    Binding(
      get: { libraryErrorMessage != nil },
      set: { isPresented in
        if !isPresented {
          libraryErrorMessage = nil
        }
      }
    )
  }

  private var satelliteLaunchOverlay: some View {
    ZStack {
      Color.black.opacity(0.22)
        .ignoresSafeArea()
        .onTapGesture {
          isSatellitePanelPresented = false
        }

      ScriptEditorSatelliteLaunchPanel(
        state: $satelliteLaunchPanelState,
        scripts: appState.scripts,
        onLaunch: {
          guard let scriptID = satelliteCastScriptID else { return }
          let selections = satelliteLaunchPanelState.launchRequest(
            scripts: appState.scripts
          ).satelliteSelections
          isSatellitePanelPresented = false
          satelliteCastScriptID = nil
          onCastWithSatellite(scriptID, selections)
        },
        onCancel: {
          isSatellitePanelPresented = false
          satelliteCastScriptID = nil
        }
      )
    }
  }

  @ViewBuilder
  private func deleteConfirmationOverlay(_ confirmation: DeleteConfirmation) -> some View {
    ZStack {
      Color.black.opacity(0.22)
        .ignoresSafeArea()
        .onTapGesture {
          deleteConfirmation = nil
        }

      VStack(alignment: .leading, spacing: 14) {
        Text(deleteConfirmationTitle(for: confirmation))
          .font(
            usesGlass
              ? .system(size: scaled(24), weight: .bold)
              : .custom("IndieFlower", size: scaled(28))
          )
          .foregroundStyle(usesGlass ? .primary : Color("colorText"))

        Text(deleteConfirmationMessage(for: confirmation))
          .font(
            usesGlass
              ? .system(size: scaled(15))
              : .custom("CrimsonText-Regular", size: scaled(16))
          )
          .foregroundStyle(usesGlass ? .secondary : Color("colorText").opacity(0.72))
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 10) {
          Button("Cancel") {
            deleteConfirmation = nil
          }
          .buttonStyle(AiraSecondaryButtonStyle())

          Button("Delete") {
            performDeleteConfirmation(confirmation)
          }
          .buttonStyle(AiraCardCastButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .padding(24)
      .frame(width: 360)
      .managerSurface(cornerRadius: 22, classicFill: Color("colorSurface"), strokeOpacity: 0.12)
      .shadow(color: Color.black.opacity(0.12), radius: 24, y: 12)
      .padding(24)
    }
  }

  private func deleteConfirmationTitle(for confirmation: DeleteConfirmation) -> String {
    switch confirmation {
    case .single:
      return "Delete Script?"
    case .bulk(let count):
      return "Delete \(count) \(count == 1 ? "script" : "scripts")?"
    }
  }

  private func deleteConfirmationMessage(for confirmation: DeleteConfirmation) -> String {
    switch confirmation {
    case .single(let meta):
      return "This will permanently delete \"\(meta.title)\" from your library."
    case .bulk:
      return "This cannot be undone."
    }
  }

  private func performDeleteConfirmation(_ confirmation: DeleteConfirmation) {
    switch confirmation {
    case .single(let meta):
      deleteScript(meta.id)
    case .bulk:
      confirmBulkDelete()
    }
    deleteConfirmation = nil
  }

  private func editScript(_ id: UUID) {
    guard
      DocumentLibrarySessionRules.allowsEditing(
        scriptID: id,
        activeSessionScriptIDs: appState.activeSessionScriptIDs
      )
    else {
      libraryErrorMessage = "End the active session before editing this script."
      return
    }

    do {
      let script = try appState.loadScript(id: id)
      onEdit(script)
    } catch {
      libraryErrorMessage = error.localizedDescription
    }
  }

  private func deleteScript(_ id: UUID) {
    guard deletionIsAvailable else {
      libraryErrorMessage = "End the active session before deleting scripts."
      return
    }

    do {
      try appState.deleteScript(id: id)
      bulkSelection.selectedScriptIDs.remove(id)
    } catch {
      libraryErrorMessage = error.localizedDescription
    }
  }

  private func duplicateScript(_ id: UUID) {
    do {
      let script = try appState.duplicateScript(id: id)
      onEdit(script)
    } catch {
      libraryErrorMessage = error.localizedDescription
    }
  }

  private func setScriptCollections(_ id: UUID, collectionIDs: [UUID]) {
    do {
      try appState.updateScriptCollections(id: id, collectionIDs: collectionIDs)
    } catch {
      libraryErrorMessage = error.localizedDescription
    }
  }

  private func scriptIsInCollection(_ scriptID: UUID, collectionID: UUID) -> Bool {
    do {
      let script = try appState.readScript(id: scriptID)
      return script.collectionIds.contains(collectionID)
    } catch {
      return appState.collections
        .first(where: { $0.id == collectionID })?
        .scriptIds
        .contains(scriptID) ?? false
    }
  }

  private func toggleStarred(_ id: UUID) {
    do {
      try appState.toggleStarred(id: id)
    } catch {
      libraryErrorMessage = error.localizedDescription
    }
  }

  private func handleDrop(providers: [NSItemProvider]) -> Bool {
    guard
      let provider = providers.first(where: {
        $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
      })
    else {
      return false
    }

    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
      if let error {
        Task { @MainActor in
          libraryErrorMessage = error.localizedDescription
        }
        return
      }

      let url: URL?
      switch item {
      case let data as Data:
        url = URL(dataRepresentation: data, relativeTo: nil)
      case let itemURL as URL:
        url = itemURL
      case let string as String:
        url = URL(string: string)
      default:
        url = nil
      }

      guard let url else {
        Task { @MainActor in
          libraryErrorMessage = "Aira could not read that dropped file."
        }
        return
      }

      Task { @MainActor in
        importScript(from: url)
      }
    }

    return true
  }

  private func presentCollectionManager(for scriptID: UUID) {
    collectionManagerScriptID = scriptID
    isCreatingCollectionFromManager = false
    newCollectionName = ""
  }

  private func dismissCollectionManager() {
    collectionManagerScriptID = nil
    isCreatingCollectionFromManager = false
    newCollectionName = ""
  }

  private func currentCollectionIDs(for scriptID: UUID) -> [UUID] {
    do {
      return try appState.readScript(id: scriptID).collectionIds
    } catch {
      return appState.collections
        .filter { $0.scriptIds.contains(scriptID) }
        .map(\.id)
    }
  }

  private func toggleCollectionMembership(
    scriptID: UUID,
    collectionID: UUID
  ) {
    let existingCollectionIDs = currentCollectionIDs(for: scriptID)
    var nextCollectionIDs = Set(existingCollectionIDs)

    if nextCollectionIDs.contains(collectionID) {
      nextCollectionIDs.remove(collectionID)
    } else {
      nextCollectionIDs.insert(collectionID)
    }

    setScriptCollections(
      scriptID,
      collectionIDs: nextCollectionIDs.sorted { $0.uuidString < $1.uuidString }
    )
  }

  private func createCollectionFromManager(for scriptID: UUID) {
    guard let normalizedName = CollectionSidebarLogic.normalizedName(newCollectionName) else {
      libraryErrorMessage = "Collection names can’t be empty."
      return
    }

    do {
      let collection = try appState.createCollection(name: normalizedName)
      let nextCollectionIDs = DocumentLibraryMoveScriptLogic.updatedCollectionIDs(
        existingCollectionIDs: currentCollectionIDs(for: scriptID),
        adding: collection.id
      )
      setScriptCollections(scriptID, collectionIDs: nextCollectionIDs)
      isCreatingCollectionFromManager = false
      newCollectionName = ""
    } catch {
      libraryErrorMessage = error.localizedDescription
    }
  }

  @ViewBuilder
  private func collectionManagerOverlay(scriptID: UUID) -> some View {
    let scriptTitle = appState.scripts.first(where: { $0.id == scriptID })?.title ?? "Script"

    ZStack {
      Color.black.opacity(0.22)
        .ignoresSafeArea()
        .onTapGesture {
          dismissCollectionManager()
        }

      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Add to Collection")
              .font(
                usesGlass
                  ? .system(size: scaled(24), weight: .bold)
                  : .custom("IndieFlower", size: scaled(28))
              )
              .foregroundStyle(usesGlass ? .primary : Color("colorText"))

            Text("Choose collections for \"\(scriptTitle)\".")
              .font(
                usesGlass
                  ? .system(size: scaled(15))
                  : .custom("CrimsonText-Regular", size: scaled(16))
              )
              .foregroundStyle(usesGlass ? .secondary : Color("colorText").opacity(0.72))
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer()

          Button {
            dismissCollectionManager()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(usesGlass ? .secondary : Color("colorText").opacity(0.7))
              .frame(width: 26, height: 26)
              .background {
                if usesGlass {
                  ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(
                      isDarkMode ? Color.white.opacity(0.08) : Color.white.opacity(0.40))
                  }
                } else {
                  Circle().fill(managerTheme.surfaceFill(for: colorScheme))
                }
              }
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
        }

        ScrollView {
          VStack(spacing: 8) {
            if appState.collections.isEmpty {
              Text("No collections yet. Create one below.")
                .font(
                  usesGlass
                    ? .system(size: scaled(15))
                    : .custom("CrimsonText-Regular", size: scaled(15))
                )
                .foregroundStyle(usesGlass ? .secondary : Color("colorText").opacity(0.62))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            } else {
              ForEach(appState.collections) { collection in
                let isMember = scriptIsInCollection(scriptID, collectionID: collection.id)

                Button {
                  toggleCollectionMembership(scriptID: scriptID, collectionID: collection.id)
                } label: {
                  HStack(spacing: 10) {
                    Image(systemName: isMember ? "checkmark.square.fill" : "square")
                      .font(.system(size: 15, weight: .semibold))
                      .foregroundStyle(
                        isMember
                          ? managerTheme.actionAccent(for: colorScheme)
                          : (usesGlass ? .secondary : Color("colorText").opacity(0.45))
                      )

                    Text(collection.name)
                      .font(
                        usesGlass
                          ? .system(size: scaled(15))
                          : .custom("CrimsonText-Regular", size: scaled(16))
                      )
                      .foregroundStyle(usesGlass ? .primary : Color("colorText"))

                    Spacer()
                  }
                  .padding(.horizontal, 14)
                  .padding(.vertical, 12)
                  .background {
                    if usesGlass {
                      ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                          .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                          .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white.opacity(0.30))
                      }
                    } else {
                      managerTheme.surfaceFill(for: colorScheme).opacity(0.92)
                    }
                  }
                  .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                  .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                      .strokeBorder(
                        usesGlass
                          ? (isDarkMode ? Color.white.opacity(0.12) : Color.white.opacity(0.35))
                          : Color("colorText").opacity(0.1),
                        lineWidth: usesGlass ? 0.5 : 1
                      )
                  )
                }
                .buttonStyle(.plain)
              }
            }
          }
        }
        .frame(maxHeight: 220)

        if isCreatingCollectionFromManager {
          HStack(spacing: 10) {
            TextField("Collection name", text: $newCollectionName)
              .textFieldStyle(.plain)
              .font(
                usesGlass
                  ? .system(size: scaled(15))
                  : .custom("CrimsonText-Regular", size: scaled(16))
              )
              .foregroundStyle(usesGlass ? .primary : Color("colorText"))
              .padding(.horizontal, 14)
              .padding(.vertical, 12)
              .background {
                if usesGlass {
                  ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                      .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                      .fill(isDarkMode ? Color.black.opacity(0.10) : Color.white.opacity(0.50))
                  }
                } else {
                  managerTheme.controlFill(for: colorScheme)
                }
              }
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
              .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .strokeBorder(
                    usesGlass
                      ? (isDarkMode ? Color.white.opacity(0.15) : Color.white.opacity(0.40))
                      : Color("colorText").opacity(0.12),
                    lineWidth: usesGlass ? 0.5 : 1.5
                  )
              )
              .onSubmit {
                createCollectionFromManager(for: scriptID)
              }

            Button("Add") {
              createCollectionFromManager(for: scriptID)
            }
            .buttonStyle(AiraPrimaryButtonStyle())

            Button("Cancel") {
              isCreatingCollectionFromManager = false
              newCollectionName = ""
            }
            .buttonStyle(AiraSecondaryButtonStyle())
          }
        } else {
          Button {
            isCreatingCollectionFromManager = true
          } label: {
            Label("New Collection", systemImage: "plus")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(AiraSecondaryButtonStyle())
        }
      }
      .padding(24)
      .frame(width: 420)
      .managerSurface(cornerRadius: 24, classicFill: Color("colorBackground"), strokeOpacity: 0.12)
      .shadow(color: Color.black.opacity(0.12), radius: 24, y: 12)
      .padding(24)
    }
  }

  private func importScript(from url: URL) {
    do {
      let script = try appState.importScript(
        from: url,
        inCollection: DocumentLibraryImportLogic.selectedCollectionID(for: filter)
      )
      onEdit(script)
    } catch {
      libraryErrorMessage = error.localizedDescription
    }
  }

  private func handleCardTap(for scriptID: UUID) {
    let modifier = selectionModifier(for: NSApp.currentEvent?.modifierFlags ?? [])
    guard modifier != .none else {
      return
    }

    bulkSelection.handleCardSelection(
      for: scriptID,
      visibleScriptIDs: visibleScriptIDs,
      modifier: modifier
    )
  }

  private func confirmBulkDelete() {
    guard deletionIsAvailable else {
      libraryErrorMessage = "End the active session before deleting scripts."
      return
    }

    do {
      try bulkSelection.resolveBulkDeleteConfirmation(confirm: true) { scriptID in
        try appState.deleteScript(id: scriptID)
      }
    } catch {
      libraryErrorMessage = error.localizedDescription
    }
  }

  private func selectionModifier(for flags: NSEvent.ModifierFlags)
    -> DocumentLibrarySelectionModifier
  {
    if flags.contains(.shift) {
      return .shift
    }
    if flags.contains(.command) {
      return .command
    }
    return .none
  }

  private func installEscapeKeyMonitor() {
    guard escapeKeyMonitor == nil else {
      return
    }

    escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      if KeyboardShortcutDisplay.matches(event: event, shortcut: "Escape"),
        bulkSelection.isSelectionMode
      {
        bulkSelection.clear()
        return nil
      }

      return event
    }
  }

  private func removeEscapeKeyMonitor() {
    if let escapeKeyMonitor {
      NSEvent.removeMonitor(escapeKeyMonitor)
      self.escapeKeyMonitor = nil
    }
  }
}

// MARK: - Empty State

struct EmptyLibraryView: View {
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.managerTheme) private var managerTheme
  var onNewScript: () -> Void

  private var usesGlass: Bool { managerTheme.usesLiquidGlassMode }

  private func scaled(_ size: CGFloat) -> CGFloat {
    size * managerFontScale
  }

  private var foreground: Color {
    colorScheme == .dark ? .white : Color("colorText")
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "doc.text")
        .font(.system(size: 48))
        .foregroundStyle(foreground.opacity(0.58))
      Text("Your first script is waiting")
        .font(
          usesGlass
            ? .system(size: scaled(28), weight: .semibold)
            : .custom("IndieFlower", size: scaled(28))
        )
        .foregroundStyle(foreground)
      Text("Create a script to get started.")
        .font(
          usesGlass
            ? .system(size: scaled(15))
            : .custom("CrimsonText-Regular", size: scaled(16))
        )
        .foregroundStyle(foreground.opacity(0.62))
      Button("Create Script") {
        onNewScript()
      }
      .buttonStyle(AiraPrimaryButtonStyle())
    }
    .frame(maxWidth: .infinity)
  }
}

struct EmptyFilteredLibraryView: View {
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.managerTheme) private var managerTheme
  let filter: SidebarNav
  var onNewScript: () -> Void

  private var usesGlass: Bool { managerTheme.usesLiquidGlassMode }

  private func scaled(_ size: CGFloat) -> CGFloat {
    size * managerFontScale
  }

  private var foreground: Color {
    colorScheme == .dark ? .white : Color("colorText")
  }

  private var title: String {
    switch filter {
    case .collection:
      return "This collection is empty"
    case .starred:
      return "No starred scripts yet"
    case .recent:
      return "No recent scripts yet"
    case .allScripts:
      return "Your first script is waiting"
    }
  }

  private var subtitle: String {
    switch filter {
    case .collection:
      return "Scripts only appear here when they explicitly belong to this collection."
    case .starred:
      return "Star a script to keep it close at hand."
    case .recent:
      return "Your recently edited scripts will appear here."
    case .allScripts:
      return "Create a script to get started."
    }
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "folder")
        .font(.system(size: 44))
        .foregroundStyle(foreground.opacity(0.58))
      Text(title)
        .font(
          usesGlass
            ? .system(size: scaled(28), weight: .semibold)
            : .custom("IndieFlower", size: scaled(28))
        )
        .foregroundStyle(foreground)
      Text(subtitle)
        .font(
          usesGlass
            ? .system(size: scaled(15))
            : .custom("CrimsonText-Regular", size: scaled(16))
        )
        .foregroundStyle(foreground.opacity(0.62))
        .multilineTextAlignment(.center)
        .frame(maxWidth: 320)
      if showsCreateButton {
        Button("Create Script") {
          onNewScript()
        }
        .buttonStyle(AiraPrimaryButtonStyle())
      }
    }
    .frame(maxWidth: .infinity)
  }

  private var showsCreateButton: Bool {
    if case .collection = filter {
      return true
    }

    return false
  }
}
