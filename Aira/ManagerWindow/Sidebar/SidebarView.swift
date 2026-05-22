import SwiftUI
import UniformTypeIdentifiers

enum SidebarTrafficLightAffordances {
  static let keepsNativeButtonsVisible = true
  static let drawsHoverGlyphOverlay = false
  static let usesSystemHoverGlyphs = true
  static let keepsTitledWindowStyleForNativeControls = true
  static let makesWindowCanvasTransparent = true
}

struct SidebarView: View {
  @EnvironmentObject var appState: AppState
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme
  @Binding var sidebarVisible: Bool
  @Binding var selectedNav: SidebarNav
  @Binding var pendingDeleteCollection: AiraCollection?
  @Binding var collectionErrorMessage: String?
  let canGoBack: Bool
  let canGoForward: Bool
  var onOpenSettings: () -> Void
  var onNewScript: () -> Void
  var onOpenScript: (UUID) -> Void
  var onMoveScriptToCollection: (UUID, UUID) -> Void
  var onGoBack: () -> Void
  var onGoForward: () -> Void

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

  private var usesLiquidSidebar: Bool {
    managerTheme.usesLiquidGlassMode
  }

  private var sidebarForegroundColor: Color {
    managerTheme.colorPalette == .aira || colorScheme == .dark ? .white : Color("colorText")
  }

  private var sidebarMutedForegroundColor: Color {
    sidebarForegroundColor.opacity(
      managerTheme.colorPalette == .aira || colorScheme == .dark ? 0.75 : 0.68)
  }

  private var selectedSidebarForegroundColor: Color {
    if managerTheme.colorPalette == .aira {
      return .white
    }
    if usesLiquidSidebar {
      return .white
    }
    return managerTheme.readableAccentForeground(
      for: colorScheme,
      accent: managerTheme.actionAccent(for: colorScheme)
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      SidebarChromeBand(
        sidebarVisible: $sidebarVisible,
        canGoBack: canGoBack,
        canGoForward: canGoForward,
        onGoBack: onGoBack,
        onGoForward: onGoForward
      )
      .frame(height: SidebarChromeMetrics.height)

      if sidebarVisible {
        if appState.stealthWarning {
          VStack(spacing: 8) {
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
          .padding(usesLiquidSidebar ? 8 : 18)
          .padding(.horizontal, usesLiquidSidebar ? 2 : 0)
          .padding(.bottom, usesLiquidSidebar ? 4 : 0)
        }

        ScrollView {
          VStack(spacing: 5) {
            navRow(label: "Scripts", iconType: .script, nav: .allScripts)
            collectionsSection
            starredSection
            recentSection
          }
          .padding(.horizontal, 10)
          .padding(.top, 16)
        }
        .scrollIndicators(.never)

        Spacer()

        sidebarSeparator()

        // MARK: — Section 3: Settings
        Button {
          onOpenSettings()
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "gearshape")
              .font(.system(size: 17, weight: .medium))
              .foregroundStyle(sidebarForegroundColor.opacity(0.85))
              .frame(width: 20, height: 20)
            Text("Settings")
              .font(.custom("CrimsonText-Regular", size: scaled(16)))
              .foregroundStyle(sidebarForegroundColor.opacity(0.85))
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .modifier(
            SidebarGlassPanelModifier(
              usesLiquidSidebar: usesLiquidSidebar,
              cornerRadius: 14,
              tintColor: nil,
              tintOpacity: 0,
              interactive: true
            ))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .padding(.bottom, 8)
      }
    }
    .modifier(ManagerSidebarBackgroundModifier())
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(
          usesLiquidSidebar
            ? (colorScheme == .dark
              ? Color.white.opacity(0.10) : Color(hex: "#627363").opacity(0.35))
            : (colorScheme == .dark
              ? Color.white.opacity(0.20)
              : (managerTheme.colorPalette == .aira
                ? Color.black.opacity(0.08)
                : Color.black.opacity(0.16))),
          lineWidth: !usesLiquidSidebar && colorScheme == .dark ? 1.25 : 1
        )
    }
  }

  enum SidebarChromeMetrics {
    static let height: CGFloat = 46
    static let appControlWidth: CGFloat = 96
    static let appControlLeading: CGFloat = 120
  }

  private struct SidebarChromeBand: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var sidebarVisible: Bool
    let canGoBack: Bool
    let canGoForward: Bool
    let onGoBack: () -> Void
    let onGoForward: () -> Void

    var body: some View {
      ZStack(alignment: .topLeading) {
        SidebarTrafficLightBridge(sidebarVisible: $sidebarVisible)
          .frame(maxWidth: .infinity, maxHeight: .infinity)

        HStack(spacing: 6) {
          chromeButton(
            help: sidebarVisible ? "Collapse Sidebar" : "Expand Sidebar",
            isEnabled: true,
            icon: .sidebar,
            iconOpacity: 0.80,
            action: {
              withAnimation(.easeInOut(duration: 0.2)) {
                sidebarVisible.toggle()
              }
            }
          )

          chromeButton(
            help: "Go Back",
            isEnabled: canGoBack,
            icon: .back,
            iconOpacity: canGoBack ? 0.80 : 0.28,
            action: onGoBack
          )

          chromeButton(
            help: "Go Forward",
            isEnabled: canGoForward,
            icon: .forward,
            iconOpacity: canGoForward ? 0.80 : 0.28,
            action: onGoForward
          )
        }
        .frame(width: SidebarChromeMetrics.appControlWidth, height: 28, alignment: .leading)
        .padding(.leading, SidebarChromeMetrics.appControlLeading + 16)
        .padding(.top, 16)
      }
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(Color.white.opacity(0.10))
          .frame(height: 1)
      }
    }

    private func chromeButton(
      help: String,
      isEnabled: Bool,
      icon: AiraIconType,
      iconOpacity: Double,
      action: @escaping () -> Void
    ) -> some View {
      Button(action: action) {
        AiraIcon(
          type: icon,
          size: 17,
          color: (colorScheme == .dark ? Color.white : Color("colorText")).opacity(iconOpacity),
          animated: false
        )
        .frame(width: 26, height: 26)
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(!isEnabled)
      .help(help)
    }
  }

  struct SidebarTrafficLightBridge: NSViewRepresentable {
    @Binding var sidebarVisible: Bool

    func makeNSView(context: Context) -> SidebarTrafficLightHostView {
      SidebarTrafficLightHostView()
    }

    func updateNSView(_ nsView: SidebarTrafficLightHostView, context: Context) {
      nsView.sidebarVisible = sidebarVisible
      nsView.syncTrafficLights()
    }
  }

  final class SidebarTrafficLightHostView: NSView {
    var sidebarVisible: Bool = true
    private var windowObservers: [NSObjectProtocol] = []
    /// Natural (macOS-set) origin of the traffic light row, shared across all instances
    /// so that toggling the sidebar (which destroys one host and creates another) never
    /// re-captures an already-shifted value.
    private static var trafficLightBaseY: CGFloat?
    /// Per-button natural X origins, keyed by button identity (pointer).
    private static var trafficLightBaseXByButton: [ObjectIdentifier: CGFloat] = [:]
    /// The window whose base position we captured — reset the cached values if the window changes.
    private static weak var baseYWindow: NSWindow?
    /// How far to shift the traffic lights downward (AppKit: decrease y = visually lower).
    private let trafficLightDownShift: CGFloat = 22
    /// How far to shift the traffic lights to the right.
    private let trafficLightRightShift: CGFloat = 8

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      removeWindowObservers()
      if let window {
        installWindowObservers(window)
      }
      // Defer initial sync to ensure the view has a valid frame from layout.
      DispatchQueue.main.async { [weak self] in
        self?.captureAndSyncTrafficLights()
      }
    }

    override func removeFromSuperview() {
      removeWindowObservers()
      super.removeFromSuperview()
    }

    deinit {
      removeWindowObservers()
    }

    override func layout() {
      super.layout()
      DispatchQueue.main.async { [weak self] in
        self?.syncTrafficLights()
      }
    }

    // MARK: — Click forwarding for repositioned traffic lights

    /// The traffic light buttons are shifted outside their titlebar container's bounds,
    /// so normal hit testing never reaches them. We intercept clicks on this host view
    /// and forward to the appropriate button based on position.
    override func mouseDown(with event: NSEvent) {
      guard let window else {
        super.mouseDown(with: event)
        return
      }
      let buttons: [(NSWindow.ButtonType, NSButton)] = [
        (.closeButton, window.standardWindowButton(.closeButton)),
        (.miniaturizeButton, window.standardWindowButton(.miniaturizeButton)),
        (.zoomButton, window.standardWindowButton(.zoomButton)),
      ].compactMap { type, btn in btn.map { (type, $0) } }

      let locationInSelf = convert(event.locationInWindow, from: nil)

      for (buttonType, button) in buttons {
        let buttonFrameInSelf = button.convert(button.bounds, to: self)
        // Use a slightly expanded rect for easier targeting
        let hitRect = buttonFrameInSelf.insetBy(dx: -3, dy: -3)
        if hitRect.contains(locationInSelf) {
          switch buttonType {
          case .closeButton:
            window.performClose(nil)
          case .miniaturizeButton:
            window.miniaturize(nil)
          case .zoomButton:
            window.zoom(nil)
          default:
            break
          }
          return
        }
      }

      super.mouseDown(with: event)
    }

    // MARK: — Window event observers

    private func installWindowObservers(_ window: NSWindow) {
      let nc = NotificationCenter.default

      // Normal window state changes — just re-sync traffic light position/visibility.
      let syncNames: [Notification.Name] = [
        NSWindow.didDeminiaturizeNotification,
        NSWindow.didBecomeKeyNotification,
        NSWindow.didBecomeMainNotification,
        NSWindow.didResizeNotification,
        NSWindow.didEndLiveResizeNotification,
        NSWindow.didExitFullScreenNotification,
      ]
      for name in syncNames {
        windowObservers.append(
          nc.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
            self?.syncTrafficLights()
          }
        )
      }

      // Fullscreen prevention: re-enforce collection behavior the moment macOS
      // tries to push the window into fullscreen.
      windowObservers.append(
        nc.addObserver(
          forName: NSWindow.willEnterFullScreenNotification,
          object: window, queue: .main
        ) { [weak self, weak window] _ in
          guard let window else { return }
          // Re-apply no-fullscreen policy (macOS may have reset it).
          window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenNone]
          self?.syncTrafficLights()
        }
      )

      // Emergency exit: if the window enters fullscreen despite prevention,
      // immediately toggle back out.
      windowObservers.append(
        nc.addObserver(
          forName: NSWindow.didEnterFullScreenNotification,
          object: window, queue: .main
        ) { [weak window] _ in
          window?.toggleFullScreen(nil)
        }
      )
    }

    private func removeWindowObservers() {
      let nc = NotificationCenter.default
      for observer in windowObservers {
        nc.removeObserver(observer)
      }
      windowObservers.removeAll()
    }

    // MARK: — Traffic light management

    private func captureAndSyncTrafficLights() {
      guard let window else { return }
      preserveNativeTitlebarForSystemControls(in: window)
      syncTrafficLights()
    }

    func syncTrafficLights() {
      guard let window else { return }
      preserveNativeTitlebarForSystemControls(in: window)
      let buttons = [
        window.standardWindowButton(.closeButton),
        window.standardWindowButton(.miniaturizeButton),
        window.standardWindowButton(.zoomButton),
      ].compactMap { $0 }

      buttons.forEach { button in
        button.isHidden = false
        button.alphaValue = 1
        button.isEnabled = true
      }

      shiftTrafficLightsDown(buttons: buttons)
    }

    private func shiftTrafficLightsDown(buttons: [NSButton]) {
      guard let reference = buttons.first else { return }
      let currentY = reference.frame.origin.y

      // Reset the cached base when the window changes (e.g. window replacement).
      if let win = window, Self.baseYWindow !== win {
        Self.trafficLightBaseY = nil
        Self.trafficLightBaseXByButton.removeAll()
        Self.baseYWindow = win
      }

      // Capture natural position once across ALL instances so toggling the sidebar
      // (which creates a fresh host view) cannot re-capture an already-shifted value.
      if Self.trafficLightBaseY == nil {
        Self.trafficLightBaseY = currentY
      }
      for button in buttons {
        let key = ObjectIdentifier(button)
        if Self.trafficLightBaseXByButton[key] == nil {
          Self.trafficLightBaseXByButton[key] = button.frame.origin.x
        }
      }

      let targetY = Self.trafficLightBaseY! - trafficLightDownShift

      buttons.forEach { button in
        var frame = button.frame
        let key = ObjectIdentifier(button)
        let baseX = Self.trafficLightBaseXByButton[key] ?? frame.origin.x
        let targetX = baseX + trafficLightRightShift
        var needsUpdate = false

        if abs(frame.origin.y - targetY) > 0.5 {
          frame.origin.y = targetY
          needsUpdate = true
        }
        if abs(frame.origin.x - targetX) > 0.5 {
          frame.origin.x = targetX
          needsUpdate = true
        }
        if needsUpdate {
          button.frame = frame
        }
        button.needsDisplay = true
      }
    }

    private func preserveNativeTitlebarForSystemControls(in window: NSWindow) {
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
      // Re-enforce no-fullscreen policy on every sync — macOS 26 may reset it.
      if window.collectionBehavior.contains(.fullScreenPrimary)
        || !window.collectionBehavior.contains(.fullScreenNone)
      {
        window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenNone]
      }
    }

  }

  @ViewBuilder
  private func sidebarSeparator(verticalPadding: CGFloat = 6) -> some View {
    if usesLiquidSidebar {
      Rectangle()
        .fill(
          LinearGradient(
            colors: [.clear, .white.opacity(0.34), .clear],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .frame(height: 1)
        .padding(.horizontal, 14)
        .padding(.vertical, verticalPadding)
    } else {
      WavySeparator(
        color: .white,
        opacity: 0.3,
        lineHeight: 3,
        amplitudeScale: 0.16,
        verticalPadding: verticalPadding
      )
    }
  }

  // MARK: - Collections Section

  @ViewBuilder
  private var collectionsSection: some View {
    VStack(spacing: 0) {
      sectionHeader(
        title: "Collections",
        iconType: .collection,
        isExpanded: collectionsExpanded
      ) {
        Button {
          isCreatingCollection = true
          collectionsExpanded = true
          editingCollectionID = nil
          editingCollectionName = ""
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 11))
            .foregroundStyle(sidebarMutedForegroundColor)
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
            HStack(alignment: .top, spacing: 8) {
              Button {
                selectedNav = .collection(collection.id)
              } label: {
                Text(collection.name)
                  .font(.custom("CrimsonText-Regular", size: scaled(15)))
                  .foregroundStyle(
                    isActive ? selectedSidebarForegroundColor : sidebarMutedForegroundColor
                  )
                  .lineLimit(nil)
                  .multilineTextAlignment(.leading)
                  .fixedSize(horizontal: false, vertical: true)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .buttonStyle(.plain)

              if scriptCount > 0 {
                Text("\(scriptCount)")
                  .font(.custom("CrimsonText-Regular", size: scaled(12)))
                  .foregroundStyle(
                    managerTheme.readableAccentForeground(
                      for: colorScheme,
                      accent: managerTheme.actionAccent(for: colorScheme)
                    )
                  )
                  .padding(.horizontal, 8)
                  .padding(.vertical, 2)
                  .background(managerTheme.actionAccent(for: colorScheme))
                  .clipShape(Capsule())
              }

              Button {
                pendingDeleteCollection = collection
              } label: {
                Image(systemName: "xmark")
                  .font(.system(size: 8, weight: .bold))
                  .foregroundStyle(Color.red.opacity(0.82))
                  .frame(width: 16, height: 16)
                  .background(Color.red.opacity(0.10))
                  .clipShape(Circle())
              }
              .buttonStyle(.plain)
              .help("Delete Collection")
            }
            .padding(.leading, 52)
            .padding(.trailing, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(
              SidebarCollectionRowGlassModifier(
                usesLiquidSidebar: usesLiquidSidebar,
                isActive: isActive,
                isDropTarget: collectionDropTargetID == collection.id
              )
            )
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
        isExpanded: starredExpanded
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
                  .foregroundStyle(sidebarForegroundColor.opacity(0.88))
                  .lineLimit(1)
                Spacer()
                Text(script.lastEdited.formatted(.dateTime.month(.abbreviated).day()))
                  .font(.custom("CrimsonText-Regular", size: scaled(11)))
                  .foregroundStyle(sidebarMutedForegroundColor.opacity(0.78))
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(managerTheme.controlFill(for: colorScheme).opacity(0.72))
                  .clipShape(RoundedRectangle(cornerRadius: 5))
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
              toggleStarred(script.id)
            } label: {
              AiraIcon(
                type: .star,
                size: 18,
                color: managerTheme.actionAccent(for: colorScheme),
                animated: false,
                filled: true
              )
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
    .padding(.top, 6)
  }

  @ViewBuilder
  private var recentSection: some View {
    VStack(spacing: 0) {
      sectionHeader(
        title: "Recent",
        iconType: .recent,
        isExpanded: recentExpanded
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
                .foregroundStyle(sidebarForegroundColor.opacity(0.88))
                .lineLimit(1)
              Spacer()
              Text(script.lastEdited.formatted(.dateTime.month(.abbreviated).day()))
                .font(.custom("CrimsonText-Regular", size: scaled(11)))
                .foregroundStyle(sidebarMutedForegroundColor.opacity(0.78))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(managerTheme.controlFill(for: colorScheme).opacity(0.72))
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
    .padding(.top, 8)
  }

  private func sectionHeader<TrailingAccessory: View>(
    title: String,
    iconType: AiraIconType,
    filledIcon: Bool = false,
    isExpanded: Bool,
    @ViewBuilder trailingAccessory: () -> TrailingAccessory,
    toggleAction: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 8) {
      Button(action: toggleAction) {
        HStack(spacing: 8) {
          AiraIcon(type: iconType, size: 20, color: sidebarForegroundColor, filled: filledIcon)
          Text(title)
            .font(.custom("CrimsonText-Regular", size: scaled(16)))
            .foregroundStyle(sidebarForegroundColor.opacity(0.9))
            .lineLimit(1)
          Spacer(minLength: 2)
          Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(sidebarMutedForegroundColor.opacity(0.75))
            .frame(width: 12, height: 12)
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
    .background(usesLiquidSidebar ? Color.white.opacity(0.12) : Color.white.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: usesLiquidSidebar ? 12 : 6, style: .continuous))
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
          color: isActive ? selectedSidebarForegroundColor : sidebarMutedForegroundColor)
        Text(label)
          .font(.custom("CrimsonText-Regular", size: scaled(16)))
          .foregroundStyle(isActive ? selectedSidebarForegroundColor : sidebarMutedForegroundColor)
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity)
      .modifier(
        SidebarNavRowGlassModifier(
          usesLiquidSidebar: usesLiquidSidebar,
          isActive: isActive
        )
      )
      .overlay(alignment: .leading) {
        if usesLiquidSidebar && isActive {
          Capsule()
            .fill(managerTheme.actionAccent(for: colorScheme))
            .frame(width: 4, height: 22)
            .padding(.leading, 6)
            .allowsHitTesting(false)
        }
      }
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Sidebar Glass Modifiers

/// Applies a translucent panel background in liquid mode (no glassEffect — the outer sidebar
/// container already provides the single glass layer). Classic mode passes through unchanged.
private struct SidebarGlassPanelModifier: ViewModifier {
  let usesLiquidSidebar: Bool
  let cornerRadius: CGFloat
  let tintColor: Color?
  let tintOpacity: Double
  var interactive: Bool = false
  var showsBorder: Bool = true

  @State private var isHovered = false

  @ViewBuilder
  func body(content: Content) -> some View {
    if usesLiquidSidebar {
      let fill = tintColor?.opacity(tintOpacity) ?? Color.white.opacity(0.06)
      let hoverFill = interactive ? Color.white.opacity(isHovered ? 0.06 : 0) : Color.clear
      content
        .background(
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill.opacity(1).blendMode(.normal))
        )
        .background(
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(hoverFill)
        )
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(showsBorder ? Color.white.opacity(0.12) : Color.clear, lineWidth: 0.5)
        )
        .onHover { hovering in
          if interactive { isHovered = hovering }
        }
    } else {
      content
    }
  }
}

/// Nav row styling: active rows get terracotta tint fill, inactive rows are transparent.
/// No glassEffect — relies on the outer sidebar glass layer.
private struct SidebarNavRowGlassModifier: ViewModifier {
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme
  let usesLiquidSidebar: Bool
  let isActive: Bool

  @State private var isHovered = false

  @ViewBuilder
  func body(content: Content) -> some View {
    if usesLiquidSidebar {
      let bgColor: Color = {
        if isActive {
          return managerTheme.actionAccent(for: colorScheme)
            .opacity(colorScheme == .dark ? 0.48 : 0.62)
        } else if isHovered {
          return Color.white.opacity(0.10)
        } else {
          return Color.clear
        }
      }()
      let strokeColor: Color =
        isActive
        ? managerTheme.actionAccent(for: colorScheme).opacity(0.70)
        : (isHovered ? Color.white.opacity(0.12) : Color.clear)
      content
        .background(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(bgColor)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(strokeColor, lineWidth: 0.5)
        )
        .onHover { hovering in isHovered = hovering }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    } else {
      let bgColor: Color = {
        if isActive {
          return managerTheme.colorPalette == .aira
            ? managerTheme.actionAccent(for: colorScheme)
              .opacity(colorScheme == .dark ? 0.74 : 0.92)
            : managerTheme.actionAccent(for: colorScheme)
        }
        if isHovered {
          return managerTheme.colorPalette == .aira
            ? Color.white.opacity(0.10)
            : Color("colorText").opacity(0.06)
        }
        return Color.clear
      }()
      content
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
          if managerTheme.colorPalette == .aira && isActive {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
          }
        }
        .onHover { hovering in isHovered = hovering }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
  }
}

/// Collection row styling with drop-target highlight. No glassEffect — uses translucent fills.
private struct SidebarCollectionRowGlassModifier: ViewModifier {
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme
  let usesLiquidSidebar: Bool
  let isActive: Bool
  let isDropTarget: Bool

  @State private var isHovered = false

  @ViewBuilder
  func body(content: Content) -> some View {
    if usesLiquidSidebar {
      let bgColor: Color = {
        if isDropTarget { return managerTheme.actionAccent(for: colorScheme).opacity(0.30) }
        if isActive {
          return managerTheme.actionAccent(for: colorScheme)
            .opacity(colorScheme == .dark ? 0.44 : 0.56)
        }
        if isHovered { return Color.white.opacity(0.08) }
        return Color.clear
      }()
      let strokeColor: Color = {
        if isDropTarget || isActive {
          return managerTheme.actionAccent(for: colorScheme).opacity(0.62)
        }
        if isHovered { return Color.white.opacity(0.10) }
        return Color.clear
      }()
      content
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(bgColor)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(strokeColor, lineWidth: 0.5)
        )
        .onHover { hovering in isHovered = hovering }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    } else {
      let fill: Color = {
        if isDropTarget { return Color.white.opacity(0.22) }
        if isActive {
          return managerTheme.colorPalette == .aira
            ? managerTheme.actionAccent(for: colorScheme)
              .opacity(colorScheme == .dark ? 0.74 : 0.92)
            : managerTheme.actionAccent(for: colorScheme)
        }
        if isHovered {
          return managerTheme.colorPalette == .aira
            ? Color.white.opacity(0.10)
            : Color("colorText").opacity(0.06)
        }
        return Color.clear
      }()
      content
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
          if managerTheme.colorPalette == .aira && isActive {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
          }
        }
        .onHover { hovering in isHovered = hovering }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
  }
}
