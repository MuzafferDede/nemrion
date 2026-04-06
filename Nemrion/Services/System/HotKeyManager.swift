import AppKit

@MainActor
final class HotKeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start(handler: @escaping () -> Void) {
        stop()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if Self.matches(event: event) {
                handler()
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Self.matches(event: event) {
                handler()
                return nil
            }
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    private static func matches(event: NSEvent) -> Bool {
        event.keyCode == 49 && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command, .shift]
    }
}
