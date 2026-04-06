import AppKit
import SwiftUI

@main
struct NemrionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var app = AppContainer.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(app)
                .task {
                    await app.refreshProviderState()
                }
        } label: {
            Image(nsImage: Self.menuBarStatusImage)
        }
        .menuBarExtraStyle(.window)
    }
}

private extension NemrionApp {
    static let menuBarStatusImage: NSImage = {
        let renderer = ImageRenderer(
            content: NemrionMark(
                primary: .black,
                secondary: Color.black.opacity(0.72),
                lineWidth: 0.11
            )
            .frame(width: 16, height: 16)
        )
        renderer.scale = 2

        let image = renderer.nsImage ?? NSImage(size: NSSize(width: 16, height: 16))
        image.isTemplate = true
        return image
    }()
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let app = AppContainer.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        app.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in
            await app.refreshProviderState()
        }
    }
}
