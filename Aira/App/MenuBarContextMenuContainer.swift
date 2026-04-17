import SwiftUI
import AppKit

struct MenuBarContextMenuContainer<Content: View>: NSViewRepresentable {
    let onOpenAira: () -> Void
    let onQuit: () -> Void
    let content: Content

    init(
        onOpenAira: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.onOpenAira = onOpenAira
        self.onQuit = onQuit
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpenAira: onOpenAira, onQuit: onQuit)
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        context.coordinator.configureMenu(for: hostingView)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let hostingView = nsView.subviews.first as? NSHostingView<Content> else {
            return
        }
        hostingView.rootView = content
        context.coordinator.configureMenu(for: hostingView)
    }

    final class Coordinator: NSObject {
        private let onOpenAira: () -> Void
        private let onQuit: () -> Void

        init(onOpenAira: @escaping () -> Void, onQuit: @escaping () -> Void) {
            self.onOpenAira = onOpenAira
            self.onQuit = onQuit
        }

        func configureMenu(for view: NSView) {
            let menu = NSMenu()

            let openItem = NSMenuItem(
                title: "Open Aira",
                action: #selector(handleOpenAira),
                keyEquivalent: ""
            )
            openItem.target = self
            menu.addItem(openItem)

            menu.addItem(.separator())

            let quitItem = NSMenuItem(
                title: "Quit Aira",
                action: #selector(handleQuit),
                keyEquivalent: ""
            )
            quitItem.target = self
            menu.addItem(quitItem)

            view.menu = menu
        }

        @objc private func handleOpenAira() {
            onOpenAira()
        }

        @objc private func handleQuit() {
            onQuit()
        }
    }
}
