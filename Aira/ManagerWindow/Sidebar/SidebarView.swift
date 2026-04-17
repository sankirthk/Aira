import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.managerFontScale) private var managerFontScale
    @Binding var selectedNav: SidebarNav
    var onOpenSettings: () -> Void
    var onNewScript: () -> Void
    var onOpenScript: (UUID) -> Void

    @State private var collectionsExpanded: Bool = false
    @State private var starredExpanded: Bool = false
    @State private var recentExpanded: Bool = false
    @State private var isCreatingCollection: Bool = false
    @State private var newCollectionName: String = ""
    @State private var editingCollectionID: UUID? = nil
    @State private var editingCollectionName: String = ""
    @State private var pendingDeleteCollection: AiraCollection? = nil
    @State private var collectionErrorMessage: String? = nil

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
                        Text("Stealth can’t be guaranteed on this Mac. Overlay windows may appear in screen capture.")
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
        .alert("Collection Action Failed", isPresented: collectionErrorBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(collectionErrorMessage ?? "Please try again.")
        }
        .overlay {
            if let pendingDeleteCollection {
                deleteCollectionOverlay(collection: pendingDeleteCollection)
            }
        }
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
                        Button {
                            selectedNav = .collection(collection.id)
                        } label: {
                            HStack {
                                Text(collection.name)
                                    .font(.custom("CrimsonText-Regular", size: scaled(15)))
                                    .foregroundStyle(isActive ? .white : .white.opacity(0.75))
                                Spacer()
                                if scriptCount > 0 {
                                    Text("\(scriptCount)")
                                        .font(.custom("CrimsonText-Regular", size: scaled(12)))
                                        .foregroundStyle(Color("colorBackground"))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color("colorSecondary"))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.leading, 52)
                        .padding(.trailing, 16)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(isActive ? Color.white.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .buttonStyle(.plain)
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
                    .font(.custom("IndieFlower", size: scaled(24)))
                    .foregroundStyle(Color("colorText"))

                Text("Deleting \"\(collection.name)\" will not delete any scripts.")
                    .font(.custom("CrimsonText-Regular", size: scaled(15)))
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
            .frame(width: 280)
            .background(Color("colorSurface"))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color("colorText").opacity(0.12), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 18, y: 10)
            .padding(16)
        }
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

    // MARK: - Generic Nav Row

    private func navRow(label: String, iconType: AiraIconType, nav: SidebarNav) -> some View {
        let isActive = selectedNav == nav
        return Button {
            selectedNav = nav
        } label: {
            HStack(spacing: 8) {
                AiraIcon(type: iconType, size: 20,
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
