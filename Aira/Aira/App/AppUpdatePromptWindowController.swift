import AppKit
import SwiftUI

@MainActor
final class AppUpdatePromptWindowController: NSWindowController, NSWindowDelegate {
    private var onPrimaryAction: (() -> Void)?
    private var onSecondaryAction: (() -> Void)?
    private var resolved = false

    init(
        content: AppUpdatePromptContent,
        onPrimaryAction: @escaping () -> Void,
        onSecondaryAction: @escaping () -> Void
    ) {
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction

        let panel = AiraUpdatePromptPanel(
            contentRect: CGRect(x: 0, y: 0, width: 360, height: 220),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .modalPanel
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        super.init(window: panel)

        panel.delegate = self
        panel.contentView = NSHostingView(
            rootView: AppUpdatePromptView(
                content: content,
                onPrimaryAction: { [weak self] in
                    self?.resolvePrimaryAction()
                },
                onSecondaryAction: { [weak self] in
                    self?.resolveSecondaryAction()
                }
            )
            .environment(\.managerFontScale, 1)
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }

        if let keyWindow = NSApp.keyWindow {
            let parentFrame = keyWindow.frame
            let origin = CGPoint(
                x: parentFrame.midX - window.frame.width / 2,
                y: parentFrame.midY - window.frame.height / 2
            )
            window.setFrameOrigin(origin)
        } else if let screenFrame = NSScreen.main?.visibleFrame {
            let origin = CGPoint(
                x: screenFrame.midX - window.frame.width / 2,
                y: screenFrame.midY - window.frame.height / 2
            )
            window.setFrameOrigin(origin)
        } else {
            window.center()
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func focus() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func closePrompt() {
        guard resolved == false else {
            window?.close()
            return
        }

        resolved = true
        onPrimaryAction = nil
        onSecondaryAction = nil
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as AnyObject? === window else { return }
        resolveSecondaryAction()
    }

    private func resolvePrimaryAction() {
        guard resolved == false else { return }
        resolved = true
        let action = onPrimaryAction
        onPrimaryAction = nil
        onSecondaryAction = nil
        closePrompt()
        action?()
    }

    private func resolveSecondaryAction() {
        guard resolved == false else { return }
        resolved = true
        let action = onSecondaryAction
        onPrimaryAction = nil
        onSecondaryAction = nil
        window?.orderOut(nil)
        action?()
    }
}

private final class AiraUpdatePromptPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private struct AppUpdatePromptView: View {
    let content: AppUpdatePromptContent
    let onPrimaryAction: () -> Void
    let onSecondaryAction: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color("colorBackground"))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color("colorPrimary").opacity(0.35), lineWidth: 1.5)
                )

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(content.versionLabel)
                        .font(.custom("CrimsonText-Regular", size: 14))
                        .foregroundStyle(Color("colorPrimary"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color("colorPrimary").opacity(0.12))
                        )

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(content.title)
                        .font(.custom("IndieFlower", size: 30))
                        .foregroundStyle(Color("colorText"))

                    Text(content.message)
                        .font(.custom("CrimsonText-Regular", size: 18))
                        .foregroundStyle(Color("colorText").opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    Spacer()

                    Button(content.secondaryActionTitle, action: onSecondaryAction)
                        .buttonStyle(AiraSecondaryButtonStyle())

                    Button(content.primaryActionTitle, action: onPrimaryAction)
                        .buttonStyle(AiraCardCastButtonStyle())
                }
            }
            .padding(22)
        }
        .frame(width: 360, height: 220)
    }
}
