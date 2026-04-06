import AppKit
import ApplicationServices
import Carbon
import Foundation

actor SelectionService {
    private let pasteboard = NSPasteboard.general
    private let selectionProbeBundleIdentifiers: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.brave.Browser",
        "company.thebrowser.Browser",
        "com.microsoft.edgemac",
        "org.mozilla.firefox",
        "company.thebrowser.Browser.beta",
        "com.tinyspeck.slackmacgap",
        "com.tinyspeck.slackmacgap.helper"
    ]

    struct BubbleAnchor: Sendable {
        let rect: CGRect
        let isPrecise: Bool
    }

    func captureSelection() async throws -> CapturedSelection {
        guard AXIsProcessTrusted() else {
            throw NemrionError.accessibilityDenied
        }

        let app = NSWorkspace.shared.frontmostApplication

        if let selection = try captureUsingAccessibility(frontmostApp: app) {
            return selection
        }

        if let selection = try await captureUsingClipboard(frontmostApp: app) {
            return selection
        }

        throw NemrionError.noSelection
    }

    func bubbleAnchor() async throws -> BubbleAnchor? {
        guard let element = focusedElement() else { return nil }

        let selectedText = selectedText(from: element)
        guard let selectedText, selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }

        if let range = selectedTextRange(from: element),
           let rect = bounds(for: range, element: element),
           rect.width < 240,
           rect.height < 80 {
            return BubbleAnchor(rect: rect, isPrecise: true)
        }

        let mouse = NSEvent.mouseLocation
        let fallbackRect = CGRect(x: mouse.x - 18, y: mouse.y - 10, width: 36, height: 20)
        return BubbleAnchor(rect: fallbackRect, isPrecise: false)
    }

    func frontmostAppSupportsSelectionProbe() -> Bool {
        guard let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return selectionProbeBundleIdentifiers.contains(bundleIdentifier)
    }

    func probedBubbleAnchor(mouseLocation: CGPoint) async throws -> BubbleAnchor? {
        guard frontmostAppSupportsSelectionProbe() else { return nil }

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        if let selection = try await captureUsingClipboard(frontmostApp: frontmostApp) {
            let fallbackRect = CGRect(x: mouseLocation.x - 18, y: mouseLocation.y - 10, width: 36, height: 20)
            return BubbleAnchor(rect: selection.bounds ?? fallbackRect, isPrecise: selection.bounds != nil)
        }

        return nil
    }

    func replaceSelection(with text: String, targetBundleIdentifier: String?) async throws {
        guard AXIsProcessTrusted() else {
            throw NemrionError.accessibilityDenied
        }

        if let targetBundleIdentifier,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: targetBundleIdentifier).first {
            app.activate(options: [])
            try await Task.sleep(for: .milliseconds(140))
        }

        if try replaceUsingAccessibility(text: text) {
            return
        }

        try await replaceUsingClipboard(text: text)
    }

    private func captureUsingAccessibility(frontmostApp: NSRunningApplication?) throws -> CapturedSelection? {
        guard let element = focusedElement() else { return nil }

        var rawValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &rawValue
        )

        guard result == .success, let text = rawValue as? String, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }

        let bounds = bounds(for: selectedTextRange(from: element), element: element)
        return CapturedSelection(
            text: text,
            appName: frontmostApp?.localizedName ?? "Current App",
            bundleIdentifier: frontmostApp?.bundleIdentifier,
            bounds: bounds
        )
    }

    private func captureUsingClipboard(frontmostApp: NSRunningApplication?) async throws -> CapturedSelection? {
        let snapshot = pasteboard.string(forType: .string)
        let count = pasteboard.changeCount

        try sendShortcut(keyCode: UInt16(kVK_ANSI_C), modifiers: [.maskCommand])
        try await Task.sleep(for: .milliseconds(180))

        let copied = pasteboard.string(forType: .string)
        let didChange = pasteboard.changeCount != count
        let differsFromSnapshot = copied != snapshot

        guard (didChange || differsFromSnapshot),
              let copied,
              copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }

        restorePasteboard(to: snapshot)

        return CapturedSelection(
            text: copied,
            appName: frontmostApp?.localizedName ?? "Current App",
            bundleIdentifier: frontmostApp?.bundleIdentifier,
            bounds: nil
        )
    }

    private func replaceUsingAccessibility(text: String) throws -> Bool {
        guard let element = focusedElement() else { return false }

        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        return result == .success
    }

    private func replaceUsingClipboard(text: String) async throws {
        let snapshot = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        try sendShortcut(keyCode: UInt16(kVK_ANSI_V), modifiers: [.maskCommand])
        try await Task.sleep(for: .milliseconds(180))

        restorePasteboard(to: snapshot)
    }

    private func restorePasteboard(to string: String?) {
        pasteboard.clearContents()
        if let string {
            pasteboard.setString(string, forType: .string)
        }
    }

    private func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var rawValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &rawValue
        )

        guard result == .success, let rawValue else { return nil }
        return unsafeDowncast(rawValue, to: AXUIElement.self)
    }

    private func selectedText(from element: AXUIElement) -> String? {
        var rawValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &rawValue
        )

        guard result == .success else { return nil }
        return rawValue as? String
    }

    private func selectedTextRange(from element: AXUIElement) -> CFRange? {
        var rawValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rawValue
        )

        guard result == .success,
              let axValue = rawValue,
              CFGetTypeID(axValue) == AXValueGetTypeID() else {
            return nil
        }

        let value = axValue as! AXValue
        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range) else { return nil }
        guard range.length > 0 else { return nil }
        return range
    }

    private func bounds(for range: CFRange?, element: AXUIElement) -> CGRect? {
        guard let range else { return nil }
        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else {
            return nil
        }

        var rawValue: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &rawValue
        )

        guard result == .success,
              let value = rawValue,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = value as! AXValue
        var rect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &rect) else { return nil }
        return rect
    }

    private func sendShortcut(keyCode: UInt16, modifiers: CGEventFlags) throws {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw NemrionError.replacementFailed
        }

        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = modifiers
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = modifiers
        up?.post(tap: .cghidEventTap)
    }
}
