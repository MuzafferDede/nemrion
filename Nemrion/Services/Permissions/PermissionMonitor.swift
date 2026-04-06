import ApplicationServices
import AppKit
import Combine
import Foundation

@MainActor
final class PermissionMonitor: ObservableObject {
    @Published private(set) var isTrusted = AXIsProcessTrusted()

    private var timer: Timer?

    func start() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isTrusted = AXIsProcessTrusted()
            }
        }
    }

    func requestAccessPrompt() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        isTrusted = AXIsProcessTrusted()
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
