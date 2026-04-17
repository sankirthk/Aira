import SwiftUI
import AppKit

struct AppKitContextMenuHost<Content: View, MenuItems: View>: NSViewRepresentable {
    let content: Content
    let menuItems: MenuItems

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder menuItems: () -> MenuItems
    ) {
        self.content = content()
        self.menuItems = menuItems()
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        let menu = NSHostingMenu(rootView: Group { menuItems })
        container.menu = menu
        hostingView.menu = menu
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let hostingView = nsView.subviews.first as? NSHostingView<Content> else {
            return
        }
        hostingView.rootView = content
        let menu = NSHostingMenu(rootView: Group { menuItems })
        nsView.menu = menu
        hostingView.menu = menu
    }
}
