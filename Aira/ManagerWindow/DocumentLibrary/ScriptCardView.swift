import SwiftUI

struct ScriptCardView: View {
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme
  let meta: ScriptMeta
  let isSelected: Bool
  let showsSelectionControls: Bool
  let selectionIsAvailable: Bool
  let editingIsAvailable: Bool
  let deletionIsAvailable: Bool
  var onEdit: () -> Void
  var onCast: () -> Void
  var onRequestCastWithSatellite: () -> Void = {}
  var onDelete: () -> Void
  var onManageCollections: () -> Void
  var onToggleStarred: () -> Void
  var onToggleSelection: () -> Void
  var onCardTap: () -> Void

  @State private var isHovered = false
  @State private var isCastMenuPresented = false

  private func scaled(_ size: CGFloat) -> CGFloat {
    size * managerFontScale
  }

  var estimatedDuration: String {
    let minutes = max(1, meta.wordCount / 130)
    return "\(minutes) min"
  }

  var lastEditedFormatted: String {
    meta.lastEdited.formatted(
      Date.FormatStyle()
        .month(.abbreviated).day().year())
  }

  private var usesGlass: Bool {
    managerTheme.usesLiquidGlassMode
  }

  private var primaryTextColor: Color {
    usesGlass ? .primary : Color("colorText")
  }

  private var secondaryTextColor: Color {
    usesGlass ? .secondary : Color("colorMuted")
  }

  private var utilityIconColor: Color {
    usesGlass
      ? managerTheme.actionAccent(for: colorScheme) : managerTheme.actionAccent(for: colorScheme)
  }

  private var inactiveStarColor: Color {
    usesGlass ? Color.secondary.opacity(0.6) : Color.secondary
  }

  private var titleFont: Font {
    usesGlass
      ? .system(size: scaled(22), weight: .medium)
      : .custom("IndieFlower", size: scaled(28))
  }

  private var metadataFont: Font {
    usesGlass
      ? .system(size: scaled(12), weight: .regular, design: .default)
      : .custom("CrimsonText-Regular", size: scaled(12))
  }

  private var cardHeight: CGFloat {
    max(142, scaled(142))
  }

  private var selectionCheckboxTopPadding: CGFloat {
    usesGlass ? 4 : 8
  }

  var body: some View {
    AppKitContextMenuHost {
      cardBody
    } menuItems: {
      cardContextMenu
    }
  }

  private var cardBody: some View {
    VStack(alignment: .leading, spacing: 0) {

      // MARK: Title row
      HStack(alignment: .top, spacing: 8) {
        selectionCheckbox
          .padding(.top, selectionCheckboxTopPadding)
          .opacity(selectionIsAvailable && (showsSelectionControls || isHovered) ? 1 : 0)
          .allowsHitTesting(selectionIsAvailable && (showsSelectionControls || isHovered))

        Text(meta.title)
          .font(titleFont)
          .fontWeight(usesGlass ? nil : .bold)
          .foregroundStyle(primaryTextColor)
          .lineLimit(ScriptCardTitleLayout.lineLimit)
          .truncationMode(.tail)
          .layoutPriority(1)
          .frame(maxWidth: .infinity, alignment: .leading)

        cardUtilityButtons
      }

      Spacer().frame(height: 4)

      // MARK: Metadata
      Text("Last edited: \(lastEditedFormatted)")
        .font(metadataFont)
        .foregroundStyle(secondaryTextColor)

      Text("Duration: \(estimatedDuration)")
        .font(metadataFont)
        .foregroundStyle(secondaryTextColor)

      Spacer(minLength: 0)

      // MARK: Action buttons
      ViewThatFits(in: .horizontal) {
        cardActionRow
        cardActionStack
      }
      .opacity(showsSelectionControls ? 0 : 1)
      .allowsHitTesting(!showsSelectionControls)
    }
    .padding(12)
    .frame(height: cardHeight, alignment: .top)
    .modifier(ScriptCardBackgroundModifier(isSelected: isSelected, usesGlass: usesGlass))
    .shadow(
      color: darkCardSurfaceIsSolid ? .clear : .black.opacity(0.06),
      radius: darkCardSurfaceIsSolid ? 0 : 8,
      y: darkCardSurfaceIsSolid ? 0 : 2
    )
    .contentShape(RoundedRectangle(cornerRadius: 12))
    .onTapGesture {
      onCardTap()
    }
    .onHover { isHovering in
      isHovered = isHovering
    }
    .onDrag {
      NSItemProvider(object: meta.id.uuidString as NSString)
    }
  }

  private var darkCardSurfaceIsSolid: Bool {
    colorScheme == .dark
  }

  @ViewBuilder
  private var cardContextMenu: some View {
    if !showsSelectionControls {
      Button("Edit") { onEdit() }
        .disabled(!editingIsAvailable)
      Button(meta.starred ? "Unstar" : "Star") { onToggleStarred() }
      Button("Add to Collection…") { onManageCollections() }
      Button("Cast to Notch") { onCast() }
      Button("Cast with Pill Windows") { onRequestCastWithSatellite() }
      if deletionIsAvailable {
        Divider()
        Button("Delete", role: .destructive) { onDelete() }
      }
    }
  }

  private var selectionCheckbox: some View {
    Button {
      onToggleSelection()
    } label: {
      Image(systemName: isSelected ? "checkmark.square.fill" : "square")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(
          isSelected
            ? managerTheme.actionAccent(for: colorScheme)
            : Color("colorText").opacity(0.55)
        )
    }
    .buttonStyle(.plain)
    .frame(width: 18, height: 18)
  }

  private var cardActionRow: some View {
    HStack(spacing: 8) {
      editButton
      castSplitButton
    }
    .frame(minHeight: 40)
  }

  private var cardActionStack: some View {
    HStack(spacing: 8) {
      editButton
      castSplitButton
    }
    .frame(minHeight: 40)
  }

  private var cardUtilityButtons: some View {
    HStack(spacing: 8) {
      Button {
        onManageCollections()
      } label: {
        Image(systemName: "folder.badge.plus")
          .font(.system(size: usesGlass ? 12 : 14))
          .foregroundStyle(utilityIconColor)
      }
      .buttonStyle(.plain)
      .opacity(isHovered && !showsSelectionControls ? 1 : 0)
      .allowsHitTesting(isHovered && !showsSelectionControls)

      Button {
        onToggleStarred()
      } label: {
        Image(systemName: meta.starred ? "star.fill" : "star")
          .font(.system(size: usesGlass ? 12 : 14))
          .foregroundStyle(
            meta.starred ? managerTheme.actionAccent(for: colorScheme) : inactiveStarColor)
      }
      .buttonStyle(.plain)

      Button {
        onDelete()
      } label: {
        Image(systemName: "trash")
          .font(.system(size: usesGlass ? 12 : 14))
          .foregroundStyle(Color.red)
      }
      .buttonStyle(.plain)
    }
    .frame(width: 66, alignment: .trailing)
    .opacity((showsSelectionControls || !deletionIsAvailable) ? 0 : 1)
    .allowsHitTesting(!showsSelectionControls && deletionIsAvailable)
  }

  private var editButton: some View {
    Button {
      onEdit()
    } label: {
      Label("Edit", systemImage: "pencil")
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(AiraCardEditButtonStyle())
    .frame(maxWidth: .infinity, minHeight: 36)
    .disabled(!editingIsAvailable)
    .opacity(editingIsAvailable ? 1 : 0.55)
  }

  private var castSplitButton: some View {
    ScriptCardCastSplitButton(
      isCastMenuPresented: $isCastMenuPresented,
      onCast: onCast,
      onRequestCastWithSatellite: onRequestCastWithSatellite
    )
  }

}

enum ScriptCardTitleLayout {
  static let lineLimit = 1
  static let truncatesLongTitlesAtTail = true
}

private struct ScriptCardCastSplitButton: View {
  @Binding var isCastMenuPresented: Bool
  let onCast: () -> Void
  let onRequestCastWithSatellite: () -> Void
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  private var usesGlass: Bool {
    managerTheme.usesLiquidGlassMode
  }

  private var isDark: Bool { colorScheme == .dark }
  private var castAccent: Color {
    managerTheme.actionAccent(for: colorScheme)
  }
  private var actionForeground: Color {
    managerTheme.readableAccentForeground(for: colorScheme, accent: castAccent)
  }
  private var controlShape: RoundedRectangle {
    RoundedRectangle(
      cornerRadius: ScriptCardActionButtonAffordances.cornerRadius,
      style: .continuous
    )
  }

  private var actionFont: Font {
    usesGlass
      ? .system(size: 15 * managerFontScale, weight: .regular, design: .default)
      : .custom("CrimsonText-Regular", size: 15 * managerFontScale)
  }

  private var menuFont: Font {
    usesGlass
      ? .system(size: 15 * managerFontScale, weight: .regular, design: .default)
      : .custom("CrimsonText-Regular", size: 15 * managerFontScale)
  }

  var body: some View {
    HStack(spacing: 0) {
      Button {
        isCastMenuPresented = false
        onCast()
      } label: {
        HStack(spacing: 6) {
          AiraIcon(
            type: .notch,
            size: 16,
            color: actionForeground,
            animated: false
          )
          Text("Cast")
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Rectangle()
        .fill(Color.white.opacity(0.28))
        .frame(width: 1, height: 18)

      Button {
        isCastMenuPresented.toggle()
      } label: {
        Image(systemName: "chevron.down")
          .font(.system(size: 9, weight: .semibold))
          .frame(width: 32)
          .padding(.vertical, 10)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .popover(isPresented: $isCastMenuPresented, arrowEdge: .bottom) {
        castPopoverContent
      }
    }
    .font(actionFont)
    .foregroundStyle(actionForeground)
    .background {
      if usesGlass {
        TerracottaGlassBackground(
          isPressed: false,
          isDark: isDark,
          tintColor: castAccent,
          tintStrength: 1.0,
          shape: controlShape
        )
      } else {
        controlShape
          .fill(managerTheme.classicSelectedActionFill(for: colorScheme))
      }
    }
    .clipShape(controlShape)
    .overlay {
      if usesGlass {
        controlShape.strokeBorder(castAccent.opacity(0.72), lineWidth: 1)
      } else {
        controlShape
          .inset(by: 2)
          .stroke(
            Color.white.opacity(0.8),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [2, 1])
          )
      }
    }
    .frame(maxWidth: .infinity, minHeight: 36)
  }

  private var castPopoverContent: some View {
    Button {
      isCastMenuPresented = false
      onRequestCastWithSatellite()
    } label: {
      HStack(spacing: 10) {
        Text("Cast with Pill Windows")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .buttonStyle(.plain)
    .font(menuFont)
    .foregroundStyle(usesGlass ? .primary : Color("colorText"))
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(
          usesGlass
            ? AnyShapeStyle(.background)
            : AnyShapeStyle(managerTheme.controlFill(for: colorScheme))
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(
          (usesGlass ? managerTheme.actionAccent(for: colorScheme) : Color("colorText")).opacity(
            0.18),
          lineWidth: 1
        )
    )
    .padding(8)
    .frame(width: 210)
  }
}

// MARK: - Card Background

/// Handles the card's background, stroke, and selection highlight.
/// In glass mode: a transparent Liquid Glass card surface.
/// In classic mode: the same library colors with the hand-drawn card treatment.
private struct ScriptCardBackgroundModifier: ViewModifier {
  let isSelected: Bool
  let usesGlass: Bool
  @Environment(\.managerTheme) private var managerTheme
  @Environment(\.colorScheme) private var colorScheme

  private var usesSolidDarkTreatment: Bool {
    colorScheme == .dark
  }

  private var cardSurfaceFill: Color {
    managerTheme.surfaceFill(for: colorScheme)
  }

  private var darkSurfaceStroke: Color {
    Color.white.opacity(0.18)
  }

  private var cardTint: Color {
    let isDark = colorScheme == .dark
    let isQuietNeutralLight = colorScheme == .light && managerTheme.colorPalette != .aira
    return isSelected
      ? managerTheme.actionAccent(for: colorScheme).opacity(
        isDark ? 0.30 : (isQuietNeutralLight ? 0.12 : 0.24))
      : (isDark
        ? Color.white.opacity(0.08)
        : Color.white.opacity(managerTheme.colorPalette == .aira ? 0.42 : 0.32))
  }

  private var cardStroke: Color {
    if isSelected {
      return colorScheme == .light && managerTheme.colorPalette != .aira
        ? Color(hex: "#263126").opacity(0.24)
        : managerTheme.actionAccent(for: colorScheme).opacity(0.54)
    }
    return colorScheme == .dark
      ? Color.white.opacity(managerTheme.colorPalette == .aira ? 0.32 : 0.24)
      : Color(hex: "#263126").opacity(managerTheme.colorPalette == .aira ? 0.22 : 0.16)
  }

  private var classicSeparatorStroke: Color {
    colorScheme == .dark
      ? Color.white.opacity(0.16)
      : Color(hex: "#263126").opacity(0.12)
  }

  private var classicOuterStroke: Color {
    if colorScheme == .dark, managerTheme.colorPalette != .aira {
      return isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.13)
    }
    if colorScheme == .light, managerTheme.colorPalette != .aira, isSelected {
      return Color(hex: "#263126").opacity(0.16)
    }
    if isSelected {
      return managerTheme.actionAccent(for: colorScheme).opacity(0.32)
    }
    return colorScheme == .dark
      ? Color.white.opacity(0.18)
      : Color(hex: "#263126").opacity(0.13)
  }

  func body(content: Content) -> some View {
    if usesSolidDarkTreatment {
      solidEditorMatchedCard(content: content)
    } else if usesGlass {
      glassCard(content: content)
    } else {
      classicCard(content: content)
    }
  }

  private func solidEditorMatchedCard(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    return
      content
      .background(cardSurfaceFill)
      .clipShape(shape)
      .overlay {
        shape.strokeBorder(
          isSelected
            ? managerTheme.actionAccent(for: colorScheme).opacity(0.74) : darkSurfaceStroke,
          lineWidth: 1
        )
      }
  }

  @ViewBuilder
  private func glassCard(content: Content) -> some View {
    content
      .background {
        ZStack {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)

          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(cardTint)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(cardStroke, lineWidth: colorScheme == .dark ? 1 : 1.5)
      }
  }

  private func classicCard(content: Content) -> some View {
    content
      .managerSurface(
        cornerRadius: 14,
        classicFill: cardTint,
        strokeOpacity: 0
      )
      .overlay(
        ZStack {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(classicOuterStroke, lineWidth: colorScheme == .dark ? 1.5 : 2)

          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(
              isSelected && !(colorScheme == .dark && managerTheme.colorPalette != .aira)
                ? managerTheme.actionAccent(for: colorScheme).opacity(
                  managerTheme.colorPalette != .aira && colorScheme == .light
                    ? 0.12 : (colorScheme == .dark ? 0.22 : 0.26)) : Color.clear,
              lineWidth: colorScheme == .dark ? 1.5 : 2)

          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(
              isSelected && !(colorScheme == .dark && managerTheme.colorPalette != .aira)
                ? managerTheme.actionAccent(for: colorScheme).opacity(
                  managerTheme.colorPalette != .aira && colorScheme == .light
                    ? 0.16 : (colorScheme == .dark ? 0.26 : 0.34))
                : classicSeparatorStroke,
              lineWidth: colorScheme == .dark ? 0.5 : 0.6)
        }
      )
  }
}
