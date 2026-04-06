import AppKit
import Combine
import Foundation

@MainActor
final class RewritePanelViewModel: ObservableObject {
    @Published var phase: RewritePhase = .idle
    @Published var sourceText = ""
    @Published var outputText = ""
    @Published var instruction = ""
    @Published var lastError = ""
    @Published var sourceAppName = "Current App"
    @Published var isApplying = false

    private var capturedSelection: CapturedSelection?
    private let pasteboard = NSPasteboard.general

    private var selectionService: SelectionService?
    private var permissionMonitor: PermissionMonitor?
    private var provider: AIProvider?
    private var settingsSource: (() -> AppSettings)?
    private var dependencySource: (() -> DependencyStatus)?

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

    func runPolishFlow(trigger: TriggerSource, revealPanel: @escaping @MainActor () -> Void) async {
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
        lastError = ""

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
        lastError = ""
        sourceAppName = "Current App"
        isApplying = false
        capturedSelection = nil
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

        let request = GenerationRequest(
            sourceText: sourceText,
            instruction: instructionOverride ?? instruction,
            action: .polish,
            model: settings.modelName
        )

        for try await chunk in provider.streamRewrite(request: request) {
            outputText.append(chunk)
        }

        if outputText.isEmpty {
            throw NemrionError.malformedResponse
        }

        phase = .ready
    }
}
