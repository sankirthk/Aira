import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.managerFontScale) private var managerFontScale
  @Binding var selectedNav: SidebarNav
  @Binding var pendingDeleteCollection: AiraCollection?
  @Binding var collectionErrorMessage: String?
  var onOpenSettings: () -> Void
  var onNewScript: () -> Void
  var onOpenScript: (UUID) -> Void
  var onMoveScriptToCollection: (UUID, UUID) -> Void

  @State private var collectionsExpanded: Bool = false
  @State private var starredExpanded: Bool = false
  @State private var recentExpanded: Bool = false
  @State private var isCreatingCollection: Bool = false
  @State private var newCollectionName: String = ""
  @State private var editingCollectionID: UUID? = nil
  @State private var editingCollectionName: String = ""
  @State private var collectionDropTargetID: UUID? = nil

  private func scaled(_ size: CGFloat) -> CGFloat {
    size * managerFontScale
  }

  var body: some View {
    VStack(spacing: 0) {

      // MARK: — Section 1: Action buttons
      VStack(spacing: 8) {
        Button {
          onNewScript()
        } label: {
          HStack(spacing: 8) {
            AiraIcon(type: .new, size: 20, color: .white)
            Text("New Script")
              .font(.custom("CrimsonText-Regular", size: scaled(16)))
          }
        }
        .buttonStyle(AiraSidebarActionButtonStyle())

        if appState.stealthWarning {
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 12))
              .foregroundStyle(Color("colorText"))
              .padding(.top, 2)
            Text(
              "Stealth can’t be guaranteed on this Mac. Overlay windows may appear in screen capture."
            )
            .font(.custom("CrimsonText-Regular", size: scaled(13)))
            .foregroundStyle(Color("colorText"))
            .fixedSize(horizontal: false, vertical: true)
          }
          .padding(10)
          .background(Color("colorWarm"))
          .clipShape(RoundedRectangle(cornerRadius: 10))
        }

      }
      .padding(18)

      WavySeparator(
        color: .white,
        opacity: 0.3,
        lineHeight: 3,
        amplitudeScale: 0.16,
        verticalPadding: 0
      )

      // MARK: — Section 2: Library
      Text("LIBRARY")
        .font(.custom("Manrope-Bold", size: scaled(12)))
        .tracking(1.5)
        .foregroundStyle(.white.opacity(0.5))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 6)

      ScrollView {
        VStack(spacing: 2) {
          navRow(label: "Scripts", iconType: .script, nav: .allScripts)
          collectionsSection
          starredSection
          recentSection
        }
      }
      .scrollIndicators(.never)

      Spacer()

      WavySeparator(color: .white, opacity: 0.3, lineHeight: 3, amplitudeScale: 0.16)

      // MARK: — Section 3: Preferences
      Button {
        onOpenSettings()
      } label: {
        HStack(spacing: 8) {
          AiraIcon(type: .settings, size: 20, color: .white.opacity(0.85))
          Text("Preferences")
            .font(.custom("CrimsonText-Regular", size: scaled(16)))
            .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
      }
      .buttonStyle(.plain)
    }
    .background(Color("colorPrimary"))
  }

  // MARK: - Collections Section

  @ViewBuilder
  private var collectionsSection: some View {
    VStack(spacing: 0) {
      sectionHeader(
        title: "Collections",
        iconType: .collection,
        disclosureText: collectionsExpanded ? "hide" : "show"
      ) {
        Button {
          isCreatingCollection = true
          collectionsExpanded = true
          editingCollectionID = nil
          editingCollectionName = ""
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.6))
        }
        .buttonStyle(.plain)
      } toggleAction: {
        withAnimation(.easeInOut(duration: 0.15)) {
          collectionsExpanded.toggle()
        }
      }

      if collectionsExpanded {
        if isCreatingCollection {
          collectionEditorRow(
            placeholder: "Collection name",
            text: $newCollectionName,
            onSubmit: createCollection,
            onCancel: cancelCreateCollection
          )
        }

        sidebarItemScrollContainer(items: appState.collections, maxHeight: 220) { collection in
          let isActive = selectedNav == .collection(collection.id)
          let scriptCount = DocumentLibraryFilterLogic.scriptCount(
            for: collection.id,
            scripts: appState.scripts,
            collections: appState.collections
          )
          if editingCollectionID == collection.id {
            collectionEditorRow(
              placeholder: "Rename collection",
              text: $editingCollectionName,
              onSubmit: { renameCollection(collection.id) },
              onCancel: cancelRenamingCollection
            )
          } else {
            HStack(spacing: 8) {
              Button {
                selectedNav = .collection(collection.id)
              } label: {
                Text(collection.name)
                  .font(.custom("CrimsonText-Regular", size: scaled(15)))
                  .foregroundStyle(isActive ? .white : .white.opacity(0.75))
                  .lineLimit(1)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .buttonStyle(.plain)

              if scriptCount > 0 {
                Text("\(scriptCount)")
                  .font(.custom("CrimsonText-Regular", size: scaled(12)))
                  .foregroundStyle(Color("colorBackground"))
                  .padding(.horizontal, 8)
                  .padding(.vertical, 2)
                  .background(Color("colorSecondary"))
                  .clipShape(Capsule())
              }

              Button {
                pendingDeleteCollection = collection
              } label: {
                Image(systemName: "xmark")
                  .font(.system(size: 8, weight: .bold))
                  .foregroundStyle(.white.opacity(0.7))
                  .frame(width: 16, height: 16)
                  .background(Color.white.opacity(0.08))
                  .clipShape(Circle())
              }
              .buttonStyle(.plain)
              .help("Delete Collection")
            }
            .padding(.leading, 52)
            .padding(.trailing, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              collectionDropTargetID == collection.id
                ? Color.white.opacity(0.22)
                : (isActive ? Color.white.opacity(0.15) : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contextMenu {
              Button("Rename") {
                editingCollectionID = collection.id
                editingCollectionName = collection.name
                isCreatingCollection = false
                newCollectionName = ""
              }
              Button("Delete", role: .destructive) {
                pendingDeleteCollection = collection
              }
            }
            .onDrop(
              of: [UTType.plainText],
              isTargeted: collectionDropBinding(for: collection.id)
            ) { providers in
              handleScriptDrop(providers: providers, onto: collection.id)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var starredSection: some View {
    VStack(spacing: 0) {
      sectionHeader(
        title: "Starred",
        iconType: .star,
        filledIcon: true,
        disclosureText: starredExpanded ? "hide" : "show"
      ) {
        Color.clear
      } toggleAction: {
        withAnimation(.easeInOut(duration: 0.15)) {
          starredExpanded.toggle()
        }
      }

      if starredExpanded {
        sidebarItemScrollContainer(
          items: DocumentLibraryFilterLogic.starredScripts(from: appState.scripts),
          maxHeight: 180
        ) { script in
          HStack(spacing: 8) {
            Button {
              selectedNav = .starred
              onOpenScript(script.id)
            } label: {
              HStack(spacing: 8) {
                Text(script.title)
                  .font(.custom("CrimsonText-Regular", size: scaled(15)))
                  .foregroundStyle(.white.opacity(0.8))
                  .lineLimit(1)
                Spacer()
                Text(script.lastEdited.formatted(.dateTime.month(.abbreviated).day()))
                  .font(.custom("CrimsonText-Regular", size: scaled(11)))
                  .foregroundStyle(.white.opacity(0.55))
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Color.white.opacity(0.08))
                  .clipShape(RoundedRectangle(cornerRadius: 5))
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
              toggleStarred(script.id)
            } label: {
              AiraIcon(type: .star, size: 18, color: .white, animated: false, filled: true)
                .opacity(0.9)
                .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Unstar")
          }
          .padding(.leading, 40)
          .padding(.trailing, 16)
          .padding(.vertical, 6)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }

  @ViewBuilder
  private var recentSection: some View {
    VStack(spacing: 0) {
      sectionHeader(
        title: "Recent",
        iconType: .recent,
        disclosureText: recentExpanded ? "hide" : "show"
      ) {
        Color.clear
      } toggleAction: {
        withAnimation(.easeInOut(duration: 0.15)) {
          recentExpanded.toggle()
        }
      }

      if recentExpanded {
        sidebarItemScrollContainer(
          items: DocumentLibraryFilterLogic.recentScripts(from: appState.scripts),
          maxHeight: 320
        ) { script in
          Button {
            onOpenScript(script.id)
          } label: {
            HStack(spacing: 8) {
              Text(script.title)
                .font(.custom("CrimsonText-Regular", size: scaled(15)))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
              Spacer()
              Text(script.lastEdited.formatted(.dateTime.month(.abbreviated).day()))
                .font(.custom("CrimsonText-Regular", size: scaled(11)))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .padding(.leading, 40)
            .padding(.trailing, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func sectionHeader<TrailingAccessory: View>(
    title: String,
    iconType: AiraIconType,
    filledIcon: Bool = false,
    disclosureText: String,
    @ViewBuilder trailingAccessory: () -> TrailingAccessory,
    toggleAction: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 8) {
      Button(action: toggleAction) {
        HStack(spacing: 8) {
          AiraIcon(type: iconType, size: 20, color: .white, filled: filledIcon)
          Text(title)
            .font(.custom("CrimsonText-Regular", size: scaled(16)))
            .foregroundStyle(.white.opacity(0.9))
          Spacer()
          Text(disclosureText)
            .font(.custom("CrimsonText-Regular", size: scaled(13)))
            .italic()
            .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)

      trailingAccessory()
        .frame(width: 16)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }

  private func collectionDropBinding(for collectionID: UUID) -> Binding<Bool> {
    Binding(
      get: { collectionDropTargetID == collectionID },
      set: { isTargeted in
        collectionDropTargetID = isTargeted ? collectionID : nil
      }
    )
  }

  private func handleScriptDrop(providers: [NSItemProvider], onto collectionID: UUID) -> Bool {
    guard
      let provider = providers.first(where: {
        $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
      })
    else {
      return false
    }

    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
      guard error == nil else { return }

      let payload: String?
      if let text = item as? String {
        payload = text
      } else if let data = item as? Data {
        payload = String(data: data, encoding: .utf8)
      } else if let text = item as? NSString {
        payload = text as String
      } else {
        payload = nil
      }

      guard
        let payload,
        let scriptID = DocumentLibraryMoveScriptLogic.parsedScriptID(from: payload)
      else { return }

      Task { @MainActor in
        onMoveScriptToCollection(scriptID, collectionID)
      }
    }

    return true
  }

  @ViewBuilder
  private func sidebarItemScrollContainer<Item: Identifiable, Content: View>(
    items: [Item],
    maxHeight: CGFloat,
    @ViewBuilder content: @escaping (Item) -> Content
  ) -> some View {
    ScrollView {
      VStack(spacing: 2) {
        ForEach(items) { item in
          content(item)
        }
      }
    }
    .frame(maxHeight: maxHeight)
  }

  private func collectionEditorRow(
    placeholder: String,
    text: Binding<String>,
    onSubmit: @escaping () -> Void,
    onCancel: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 8) {
      TextField(placeholder, text: text)
        .textFieldStyle(.plain)
        .font(.custom("CrimsonText-Regular", size: scaled(15)))
        .foregroundStyle(.white)
        .onSubmit(onSubmit)

      Button(action: onSubmit) {
        Image(systemName: "checkmark")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.white.opacity(0.85))
      }
      .buttonStyle(.plain)

      Button(action: onCancel) {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.white.opacity(0.6))
      }
      .buttonStyle(.plain)
    }
    .padding(.leading, 52)
    .padding(.trailing, 16)
    .padding(.vertical, 6)
    .background(Color.white.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  private func createCollection() {
    guard let name = CollectionSidebarLogic.normalizedName(newCollectionName) else {
      collectionErrorMessage = "Collection names can’t be empty."
      return
    }

    do {
      let collection = try appState.createCollection(name: name)
      newCollectionName = ""
      isCreatingCollection = false
      selectedNav = .collection(collection.id)
    } catch {
      collectionErrorMessage = error.localizedDescription
    }
  }

  private func cancelCreateCollection() {
    newCollectionName = ""
    isCreatingCollection = false
  }

  private func renameCollection(_ id: UUID) {
    guard let name = CollectionSidebarLogic.normalizedName(editingCollectionName) else {
      collectionErrorMessage = "Collection names can’t be empty."
      return
    }

    do {
      try appState.renameCollection(id: id, to: name)
      editingCollectionID = nil
      editingCollectionName = ""
    } catch {
      collectionErrorMessage = error.localizedDescription
    }
  }

  private func cancelRenamingCollection() {
    editingCollectionID = nil
    editingCollectionName = ""
  }

  private func toggleStarred(_ scriptID: UUID) {
    do {
      try appState.toggleStarred(id: scriptID)
    } catch {
      collectionErrorMessage = error.localizedDescription
    }
  }

  // MARK: - Generic Nav Row

  private func navRow(label: String, iconType: AiraIconType, nav: SidebarNav) -> some View {
    let isActive = selectedNav == nav
    return Button {
      selectedNav = nav
    } label: {
      HStack(spacing: 8) {
        AiraIcon(
          type: iconType, size: 20,
          color: isActive ? .white : .white.opacity(0.7))
        Text(label)
          .font(.custom("CrimsonText-Regular", size: scaled(16)))
          .foregroundStyle(isActive ? .white : .white.opacity(0.75))
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity)
      .background(isActive ? Color.white.opacity(0.15) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
  }
}
