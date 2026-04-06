import AppKit
import SwiftUI

@MainActor
final class SelectionBubbleController {
    var onActivate: (() -> Void)?

    private var panel: NSPanel?
    private var timer: Timer?
    private var selectionService: SelectionService?
    private var globalMouseUpMonitor: Any?
    private var globalMouseDownMonitor: Any?
    private var localMouseUpMonitor: Any?
    private var localMouseDownMonitor: Any?
    private var fallbackAnchor: CGRect?
    private var fallbackAnchorExpiry: Date?
    private var lockedImpreciseAnchor: CGRect?

    func start(selectionService: SelectionService) {
        self.selectionService = selectionService
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAnchor()
            }
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.probeBrowserSelection()
            }
        }

        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            Task { @MainActor [weak self] in
                await self?.probeBrowserSelection()
            }
            return event
        }

        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.clearFallbackAnchor()
                self?.hide()
            }
        }

        localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.clearFallbackAnchor()
                self?.hide()
            }
            return event
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        clearFallbackAnchor()
        lockedImpreciseAnchor = nil
        if let globalMouseUpMonitor { NSEvent.removeMonitor(globalMouseUpMonitor) }
        if let globalMouseDownMonitor { NSEvent.removeMonitor(globalMouseDownMonitor) }
        if let localMouseUpMonitor { NSEvent.removeMonitor(localMouseUpMonitor) }
        if let localMouseDownMonitor { NSEvent.removeMonitor(localMouseDownMonitor) }
        globalMouseUpMonitor = nil
        globalMouseDownMonitor = nil
        localMouseUpMonitor = nil
        localMouseDownMonitor = nil
        hide()
    }

    private func refreshAnchor() async {
        guard NSApp.isActive == false else {
            hide()
            return
        }

        guard let selectionService else { return }
        guard let anchor = try? await selectionService.bubbleAnchor() else {
            if let fallbackAnchor,
               let fallbackAnchorExpiry,
               fallbackAnchorExpiry > Date(),
               await selectionService.frontmostAppIsBrowser() {
                show(at: fallbackAnchor)
                return
            }
            lockedImpreciseAnchor = nil
            hide()
            return
        }

        clearFallbackAnchor()
        if anchor.isPrecise {
            lockedImpreciseAnchor = nil
            show(at: anchor.rect)
            return
        }

        if let lockedImpreciseAnchor {
            show(at: lockedImpreciseAnchor)
        } else {
            lockedImpreciseAnchor = anchor.rect
            show(at: anchor.rect)
        }
    }

    private func probeBrowserSelection() async {
        guard NSApp.isActive == false else { return }
        guard let selectionService else { return }
        guard await selectionService.frontmostAppIsBrowser() else { return }

        try? await Task.sleep(for: .milliseconds(120))

        guard let anchor = try? await selectionService.browserBubbleAnchor(mouseLocation: NSEvent.mouseLocation) else {
            clearFallbackAnchor()
            lockedImpreciseAnchor = nil
            return
        }

        fallbackAnchor = anchor.rect
        fallbackAnchorExpiry = Date().addingTimeInterval(4)
        if anchor.isPrecise == false {
            lockedImpreciseAnchor = anchor.rect
        }
        show(at: anchor.rect)
    }

    private func clearFallbackAnchor() {
        fallbackAnchor = nil
        fallbackAnchorExpiry = nil
    }

    private func show(at rect: CGRect) {
        let panel = panel ?? makePanel()
        self.panel = panel

        let size = NSSize(width: 36, height: 36)
        let origin = CGPoint(
            x: rect.maxX - size.width + 2,
            y: rect.maxY + 4
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let button = BubbleButton {
            self.onActivate?()
        }

        let hosting = NSHostingController(rootView: button)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 36, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        panel.contentViewController = hosting
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }
}

private struct BubbleButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            NemrionMark(
                primary: hovering ? Color.white : Color.white.opacity(0.96),
                secondary: hovering ? Color.white.opacity(0.64) : Color.white.opacity(0.56),
                lineWidth: 0.11
            )
            .padding(8)
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                    .fill(hovering ? Color.black.opacity(0.84) : Color.black.opacity(0.74))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
    }
}
