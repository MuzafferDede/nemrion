import AppKit
import SwiftUI

@MainActor
final class RewritePanelCoordinator {
    private let viewModel: RewritePanelViewModel
    private var panel: NSPanel?

    init(viewModel: RewritePanelViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        fit(panel: panel)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let hostingController = NSHostingController(
            rootView: RewritePanelView(viewModel: viewModel)
                .environmentObject(AppContainer.shared)
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.titled, .resizable, .closable],
            backing: .buffered,
            defer: true
        )

        panel.contentViewController = hostingController
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.toolbar = nil
        panel.setContentSize(NSSize(width: 760, height: 560))
        panel.contentMinSize = NSSize(width: 680, height: 500)
        panel.standardWindowButton(.closeButton)?.isHidden = false
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        return panel
    }

    private func fit(panel: NSPanel) {
        guard let screen = NSScreen.main ?? panel.screen else { return }
        let visible = screen.visibleFrame
        let width = min(760, max(680, floor(visible.width * 0.62)))
        let height = min(560, max(500, floor(visible.height * 0.72)))
        panel.setContentSize(NSSize(width: width, height: height))
    }
}
