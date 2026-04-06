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

        let panel = RewriteFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        panel.contentViewController = hostingController
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.toolbar = nil
        panel.setContentSize(NSSize(width: 760, height: 560))
        panel.contentMinSize = NSSize(width: 680, height: 500)
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

private final class RewriteFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class SettingsWindowCoordinator {
    private var window: NSPanel?
    private var hostingController: NSHostingController<AnyView>?

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        fit(window: window)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func makeWindow() -> NSPanel {
        let hostingController = NSHostingController(
            rootView: AnyView(
                SettingsView()
                    .environmentObject(AppContainer.shared)
            )
        )
        self.hostingController = hostingController

        let window = RewriteFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        window.contentViewController = hostingController
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.toolbar = nil
        window.setContentSize(NSSize(width: 760, height: 560))
        window.contentMinSize = NSSize(width: 680, height: 1)
        return window
    }

    private func fit(window: NSPanel) {
        guard
            let screen = NSScreen.main ?? window.screen,
            let hostingController
        else { return }

        let visible = screen.visibleFrame
        let width = min(760, max(680, floor(visible.width * 0.62)))

        hostingController.rootView = AnyView(
            SettingsView()
                .environmentObject(AppContainer.shared)
                .frame(width: width, alignment: .topLeading)
        )

        window.setContentSize(NSSize(width: width, height: window.frame.height))
        hostingController.view.layoutSubtreeIfNeeded()
        let fittingHeight = ceil(hostingController.view.fittingSize.height)
        let targetHeight = min(max(fittingHeight, 1), floor(visible.height * 0.82))

        window.contentMaxSize = NSSize(width: visible.width, height: targetHeight)
        window.setContentSize(NSSize(width: width, height: targetHeight))
    }
}
