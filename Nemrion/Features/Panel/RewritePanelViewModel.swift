import AppKit
import Combine
import Foundation

@MainActor
final class RewritePanelViewModel: ObservableObject {
    @Published var phase: RewritePhase = .idle
    @Published var sourceText = ""
    @Published var outputText = ""
    @Published var instruction = ""
    @Published var sourceAppName = "Current App"
    @Published var isApplying = false
    @Published var isThinking = false
    @Published var thinkingText = ""

    private var capturedSelection: CapturedSelection?
    private let pasteboard = NSPasteboard.general

    private var selectionService: SelectionService?
    private var permissionMonitor: PermissionMonitor?
    private var provider: AIProvider?
    private var settingsSource: (() -> AppSettings)?
    private var dependencySource: (() -> DependencyStatus)?
    private var shouldStopGeneration = false

    func configure(
        selectionService: SelectionService,
        permissionMonitor: PermissionMonitor,
        provider: AIProvider,
        settingsSource: @escaping () -> AppSettings,
        dependencySource: @escaping () -> DependencyStatus
    ) {
        self.selectionService = selectionService
        self.permissionMonitor = permissionMonitor
        self.provider = provider
        self.settingsSource = settingsSource
        self.dependencySource = dependencySource
    }

    func runPolishFlow(revealPanel: @escaping @MainActor () -> Void) async {
        var hasRevealedPanel = false

        func revealIfNeeded() {
            guard hasRevealedPanel == false else { return }
            hasRevealedPanel = true
            revealPanel()
        }

        clearSession()

        guard dependencySource?() == .ready else {
            phase = .failure(dependencySource?().title ?? "Provider unavailable")
            revealIfNeeded()
            return
        }

        guard permissionMonitor?.isTrusted == true else {
            phase = .failure(NemrionError.accessibilityDenied.localizedDescription)
            revealIfNeeded()
            return
        }

        phase = .capturing
        outputText = ""

        do {
            guard let selectionService else { return }
            let selection = try await selectionService.captureSelection()
            capturedSelection = selection
            sourceText = selection.text
            sourceAppName = selection.appName
            revealIfNeeded()
            phase = .generating
            try await generate()
        } catch {
            phase = .failure(error.localizedDescription)
            revealIfNeeded()
        }
    }

    func retry() async {
        guard sourceText.isEmpty == false else { return }
        phase = .generating
        outputText = ""
        thinkingText = ""
        shouldStopGeneration = false

        do {
            try await generate()
        } catch {
            phase = .failure(error.localizedDescription)
        }
    }

    func reset() async {
        instruction = ""
        guard sourceText.isEmpty == false else {
            outputText = ""
            phase = .idle
            return
        }
        await retry()
    }

    func submitInstruction() async {
        let submittedInstruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sourceText.isEmpty == false, submittedInstruction.isEmpty == false else { return }

        phase = .generating
        outputText = ""
        thinkingText = ""
        shouldStopGeneration = false
        instruction = ""

        do {
            try await generate(instructionOverride: submittedInstruction)
        } catch {
            phase = .failure(error.localizedDescription)
        }
    }

    func copyOutput() {
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
    }

    func clearSession() {
        phase = .idle
        sourceText = ""
        outputText = ""
        instruction = ""
        sourceAppName = "Current App"
        isApplying = false
        isThinking = false
        thinkingText = ""
        capturedSelection = nil
        shouldStopGeneration = false
    }

    func stopGeneration() {
        guard phase == .generating else { return }
        shouldStopGeneration = true
        isThinking = false
        phase = outputText.isEmpty ? .idle : .ready
    }

    func applyOutput() async {
        guard outputText.isEmpty == false, let selectionService, let capturedSelection else { return }

        isApplying = true
        defer { isApplying = false }

        do {
            try await selectionService.replaceSelection(
                with: outputText,
                targetBundleIdentifier: capturedSelection.bundleIdentifier
            )
        } catch {
            phase = .failure(error.localizedDescription)
        }
    }

    private func generate(instructionOverride: String? = nil) async throws {
        guard let provider, let settings = settingsSource?() else { return }
        isThinking = false
        defer { isThinking = false }
        thinkingText = ""
        shouldStopGeneration = false

        let request = GenerationRequest(
            sourceText: sourceText,
            instruction: instructionOverride ?? instruction,
            model: settings.modelName,
            isThinkingEnabled: settings.isThinkingEnabled
        )

        var outputBuffer = ""
        var thinkingBuffer = ""
        var lastFlush = Date()

        func flushBufferedText(force: Bool = false) {
            let now = Date()
            guard force || now.timeIntervalSince(lastFlush) >= 0.04 else { return }

            if outputBuffer.isEmpty == false {
                outputText.append(outputBuffer)
                outputBuffer = ""
            }
            if thinkingBuffer.isEmpty == false {
                thinkingText.append(thinkingBuffer)
                thinkingBuffer = ""
            }
            lastFlush = now
        }

        for try await event in provider.streamRewrite(request: request) {
            if shouldStopGeneration {
                break
            }
            switch event {
            case let .content(chunk):
                isThinking = false
                outputBuffer.append(chunk)
            case let .thinking(chunk):
                isThinking = true
                thinkingBuffer.append(chunk)
            case .thinkingEnded:
                flushBufferedText(force: true)
                isThinking = false
            }
            flushBufferedText()
        }
        flushBufferedText(force: true)
        if shouldStopGeneration {
            shouldStopGeneration = false
            if outputText.isEmpty == false {
                phase = .ready
            }
            return
        }
        if outputText.isEmpty {
            throw NemrionError.malformedResponse
        }

        phase = .ready
    }
}
