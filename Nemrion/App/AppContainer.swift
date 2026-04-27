import AppKit
import Combine
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    static let shared = AppContainer()

    @Published var settings = AppSettings()
    @Published var dependencyStatus: DependencyStatus = .checking
    @Published var availableModels: [ProviderModel] = []

    let permissionMonitor = PermissionMonitor()
    let selectionService = SelectionService()

    private let provider = OllamaProvider()
    private let hotKeyManager = HotKeyManager()
    private let panelViewModel: RewritePanelViewModel
    private let panelCoordinator: RewritePanelCoordinator
    private let settingsCoordinator: SettingsWindowCoordinator
    private let bubbleController: SelectionBubbleController
    private var cancellables: Set<AnyCancellable> = []
    private var didRequestAccessibilityOnLaunch = false
    private var didAttemptOllamaStartOnLaunch = false

    private init() {
        panelViewModel = RewritePanelViewModel()
        panelCoordinator = RewritePanelCoordinator(viewModel: panelViewModel)
        settingsCoordinator = SettingsWindowCoordinator()
        bubbleController = SelectionBubbleController()

        panelViewModel.configure(
            selectionService: selectionService,
            permissionMonitor: permissionMonitor,
            provider: provider,
            settingsSource: { [weak self] in self?.settings ?? AppSettings() },
            dependencySource: { [weak self] in self?.dependencyStatus ?? .checking }
        )

        bubbleController.onActivate = { [weak self] in
            Task { await self?.triggerPolishFlow() }
        }
    }

    func start() {
        permissionMonitor.start()
        hotKeyManager.start {
            Task { @MainActor [weak self] in
                await self?.triggerPolishFlow()
            }
        }

        permissionMonitor.$isTrusted
            .receive(on: RunLoop.main)
            .sink { [weak self] trusted in
                guard let self else { return }
                if trusted {
                    self.bubbleController.start(selectionService: self.selectionService)
                } else {
                    self.bubbleController.stop()
                }
            }
            .store(in: &cancellables)

        if permissionMonitor.isTrusted == false, didRequestAccessibilityOnLaunch == false {
            didRequestAccessibilityOnLaunch = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.permissionMonitor.requestAccessPrompt()
            }
        }

        Task {
            await refreshProviderState()
            startOllamaOnLaunchIfNeeded()
        }
    }

    func triggerPolishFlow() async {
        await refreshProviderState()
        await panelViewModel.runPolishFlow { [weak self] in
            self?.panelCoordinator.show()
        }
    }

    func dismissPanel() {
        panelCoordinator.hide()
        panelViewModel.clearSession()
    }

    func openSettingsWindow() {
        Task { await refreshProviderState() }
        settingsCoordinator.show()
    }

    func dismissSettingsWindow() {
        settingsCoordinator.hide()
    }

    func refreshProviderState() async {
        dependencyStatus = await provider.healthCheck()
        guard case .ready = dependencyStatus else {
            availableModels = []
            if case .ready = panelViewModel.phase {
                panelViewModel.phase = .idle
            }
            return
        }

        do {
            let models = try await provider.availableModels().sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            availableModels = models
            if settings.modelName.isEmpty || models.contains(where: { $0.id == settings.modelName }) == false {
                settings.modelName = models.first?.id ?? "llama3.1"
            }
        } catch {
            dependencyStatus = .unavailable(error.localizedDescription)
        }
    }

    func openAccessibilitySettings() {
        PermissionMonitor.openAccessibilitySettings()
    }

    func startOllama() {
        let workspace = NSWorkspace.shared
        let fileManager = FileManager.default
        let installPaths = [
            "/Applications/Ollama.app",
            "\(NSHomeDirectory())/Applications/Ollama.app"
        ]

        guard let appPath = installPaths.first(where: { fileManager.fileExists(atPath: $0) }) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false

        workspace.openApplication(
            at: URL(fileURLWithPath: appPath),
            configuration: configuration
        ) { [weak self] _, _ in
            guard let self else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                await self.refreshProviderState()
            }
        }
    }

    private func startOllamaOnLaunchIfNeeded() {
        guard didAttemptOllamaStartOnLaunch == false else { return }
        didAttemptOllamaStartOnLaunch = true

        guard dependencyStatus == .ollamaStopped else { return }
        startOllama()
    }

    func requestAccessibilityPrompt() {
        permissionMonitor.requestAccessPrompt()
    }
}
