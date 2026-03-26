import SwiftUI

struct ScriptCardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.managerFontScale) private var managerFontScale
    let meta: ScriptMeta
    let isSelected: Bool
    let showsSelectionControls: Bool
    let selectionIsAvailable: Bool
    let editingIsAvailable: Bool
    let deletionIsAvailable: Bool
    var onEdit: () -> Void
    var onCast: () -> Void
    var onDelete: () -> Void
    var onDuplicate: () -> Void
    var onToggleStarred: () -> Void
    var onToggleSelection: () -> Void
    var onCardTap: () -> Void

    @State private var isHovered = false

    private func scaled(_ size: CGFloat) -> CGFloat {
        size * managerFontScale
    }

    var estimatedDuration: String {
        let minutes = max(1, meta.wordCount / 130)
        return "\(minutes) min"
    }

    var lastEditedFormatted: String {
        meta.lastEdited.formatted(Date.FormatStyle()
            .month(.abbreviated).day().year())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: Title row
            HStack(alignment: .top, spacing: 8) {
                selectionCheckbox
                    .opacity(selectionIsAvailable && (showsSelectionControls || isHovered) ? 1 : 0)
                    .allowsHitTesting(selectionIsAvailable && (showsSelectionControls || isHovered))

                Text(meta.title)
                    .font(.custom("IndieFlower", size: scaled(22)))
                    .foregroundStyle(Color("colorText"))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                cardUtilityButtons
            }

            Spacer().frame(height: 10)

            // MARK: Metadata
            Text("Last edited: \(lastEditedFormatted)")
                .font(.custom("Inter-Regular", size: scaled(12)))
                .foregroundStyle(Color("colorMuted"))

            Text("Duration: \(estimatedDuration)")
                .font(.custom("Inter-Regular", size: scaled(12)))
                .foregroundStyle(Color("colorMuted"))

            Spacer()

            // MARK: Action buttons
            ViewThatFits(in: .horizontal) {
                cardActionRow
                cardActionStack
            }
            .opacity(showsSelectionControls ? 0 : 1)
            .allowsHitTesting(!showsSelectionControls)
        }
        .padding(20)
        .frame(minHeight: 160)
        .background(
            isSelected
                ? Color("colorPrimary").opacity(0.12)
                : Color("colorSurface")
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("colorText"), lineWidth: 3)

                RoundedRectangle(cornerRadius: 10)
                    .inset(by: 4)
                    .stroke(
                        Color("colorText").opacity(0.3),
                        style: StrokeStyle(
                            lineWidth: 2.5,
                            lineCap: .round,
                            dash: [4, 2]
                        )
                    )

                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected
                            ? Color("colorPrimary")
                            : Color.clear,
                        lineWidth: 3
                    )
            }
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            onCardTap()
        }
        .onHover { isHovering in
            isHovered = isHovering
        }
        .contextMenu {
            if !showsSelectionControls {
                Button("Edit") { onEdit() }
                    .disabled(!editingIsAvailable)
                Button(meta.starred ? "Unstar" : "Star") { onToggleStarred() }
                Button("Duplicate") { onDuplicate() }
                Button("Cast to Notch") { onCast() }
                if deletionIsAvailable {
                    Divider()
                    Button("Delete", role: .destructive) { onDelete() }
                }
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
            castButton
            duplicateButton
        }
        .frame(minHeight: 40)
    }

    private var cardActionStack: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                editButton
                castButton
            }

            duplicateButton
        }
        .frame(minHeight: 88)
    }

    private var cardUtilityButtons: some View {
        HStack(spacing: 8) {
            Button {
                onToggleStarred()
            } label: {
                Image(systemName: meta.starred ? "star.fill" : "star")
                    .font(.system(size: 14))
                    .foregroundStyle(meta.starred ? Color("colorSecondary") : Color.secondary)
            }
            .buttonStyle(.plain)

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(Color("colorSecondary"))
            }
            .buttonStyle(.plain)
        }
        .frame(width: 44, alignment: .trailing)
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

    private var castButton: some View {
        Button {
            onCast()
        } label: {
            HStack(spacing: 6) {
                AiraIcon(type: .notch, size: 16, color: .white, animated: false)
                Text("Cast")
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(AiraCardCastButtonStyle())
    }

    private var duplicateButton: some View {
        Button {
            onDuplicate()
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(AiraSecondaryButtonStyle())
    }
}
