import SwiftUI

struct ScriptCardView: View {
  @Environment(\.managerFontScale) private var managerFontScale
  @Environment(\.managerTheme) private var managerTheme
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
    usesGlass ? .secondary : Color("colorSecondary")
  }

  private var inactiveStarColor: Color {
    usesGlass ? Color.secondary.opacity(0.6) : Color.secondary
  }

  private var titleFont: Font {
    usesGlass
      ? .system(size: scaled(17), weight: .semibold)
      : .custom("IndieFlower", size: scaled(22))
  }

  private var metadataFont: Font {
    usesGlass
      ? .system(size: scaled(11), weight: .regular, design: .default)
      : .custom("CrimsonText-Regular", size: scaled(12))
  }

  private var cardMinHeight: CGFloat {
    max(130, scaled(130))
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
          .opacity(selectionIsAvailable && (showsSelectionControls || isHovered) ? 1 : 0)
          .allowsHitTesting(selectionIsAvailable && (showsSelectionControls || isHovered))

        Text(meta.title)
          .font(titleFont)
          .foregroundStyle(primaryTextColor)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
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
    .padding(14)
    .frame(minHeight: cardMinHeight, alignment: .top)
    .modifier(ScriptCardBackgroundModifier(isSelected: isSelected, usesGlass: usesGlass))
    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
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
            ? Color("colorPrimary")
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
          .foregroundStyle(meta.starred ? Color("colorSecondary") : inactiveStarColor)
      }
      .buttonStyle(.plain)

      Button {
        onDelete()
      } label: {
        Image(systemName: "trash")
          .font(.system(size: usesGlass ? 12 : 14))
          .foregroundStyle(utilityIconColor)
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
  private var classicSecondary: Color {
    ManagerClassicAccentPalette.secondary(for: colorScheme)
  }
  private var controlShape: RoundedRectangle {
    RoundedRectangle(
      cornerRadius: ScriptCardActionButtonAffordances.cornerRadius,
      style: .continuous
    )
  }

  private var actionFont: Font {
    usesGlass
      ? .system(size: 14 * managerFontScale, weight: .regular, design: .default)
      : .custom("CrimsonText-Regular", size: 14 * managerFontScale)
  }

  private var menuFont: Font {
    usesGlass
      ? .system(size: 14 * managerFontScale, weight: .regular, design: .default)
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
            color: .white,
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
        Button {
          isCastMenuPresented = false
          onRequestCastWithSatellite()
        } label: {
          Text("Cast with Pill Windows")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .font(menuFont)
        .foregroundStyle(Color("colorText"))
        .frame(width: 210)
      }
    }
    .font(actionFont)
    .foregroundStyle(.white)
    .background {
      if usesGlass {
        let opacity: Double = isDark ? 0.48 : 0.76
        controlShape
          .fill(Color("colorSecondary").opacity(opacity))
          .background(.ultraThinMaterial, in: controlShape)
      } else {
        controlShape
          .fill(classicSecondary)
      }
    }
    .overlay {
      if usesGlass {
        controlShape
          .strokeBorder(Color("colorSecondary").opacity(isDark ? 0.45 : 0.60), lineWidth: 1)
      } else {
        controlShape
          .inset(by: 2)
          .stroke(
            Color.white.opacity(0.8),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [2, 1])
          )
      }
    }
    .clipShape(controlShape)
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Card Background

/// Handles the card's background, stroke, and selection highlight.
/// In glass mode: a transparent Liquid Glass card surface.
/// In classic mode: the same library colors with the hand-drawn card treatment.
private struct ScriptCardBackgroundModifier: ViewModifier {
  let isSelected: Bool
  let usesGlass: Bool
  @Environment(\.colorScheme) private var colorScheme

  private var cardTint: Color {
    let isDark = colorScheme == .dark
    return isSelected
      ? Color("colorSecondary").opacity(isDark ? 0.20 : 0.14)
      : (isDark ? Color.black.opacity(0.12) : Color.white.opacity(0.25))
  }

  private var cardStroke: Color {
    isSelected ? Color("colorPrimary").opacity(0.40) : Color.white.opacity(0.35)
  }

  private var classicSeparatorStroke: Color {
    colorScheme == .dark
      ? Color.white.opacity(0.30)
      : Color(hex: "#263126").opacity(0.16)
  }

  private var classicOuterStroke: Color {
    if isSelected {
      return Color("colorPrimary").opacity(0.46)
    }
    return colorScheme == .dark
      ? Color.white.opacity(0.35)
      : Color(hex: "#263126").opacity(0.18)
  }

  private var classicInnerStroke: Color {
    if isSelected {
      return Color("colorPrimary").opacity(0.34)
    }
    return colorScheme == .dark
      ? Color.white.opacity(0.21)
      : Color(hex: "#263126").opacity(0.10)
  }

  func body(content: Content) -> some View {
    if usesGlass {
      glassCard(content: content)
    } else {
      classicCard(content: content)
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
          .strokeBorder(cardStroke, lineWidth: 0.5)
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
            .stroke(classicOuterStroke, lineWidth: 3)

          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .inset(by: 4)
            .stroke(
              classicInnerStroke,
              style: StrokeStyle(
                lineWidth: 2.5,
                lineCap: .round,
                dash: [4, 2]
              )
            )

          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isSelected ? Color("colorPrimary").opacity(0.40) : Color.clear, lineWidth: 3)

          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(
              isSelected ? Color("colorPrimary").opacity(0.46) : classicSeparatorStroke,
              lineWidth: 0.75)
        }
      )
  }
}
