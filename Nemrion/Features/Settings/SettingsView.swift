import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppContainer
    @State private var isModelPickerPresented = false

    var body: some View {
        ZStack {
            NemrionBackground()

            VStack(alignment: .leading, spacing: NemrionScale.space4) {
                header
                workspaceCard
                runtimeCard
            }
            .padding(NemrionScale.space4)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: NemrionScale.space3) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(NemrionTheme.textPrimary)

                Text("Keep runtime configuration small and get back to writing.")
                    .font(.system(size: NemrionScale.textSm, weight: .medium))
                    .foregroundStyle(NemrionTheme.textSecondary)
            }

            Spacer()

            Button {
                app.dismissSettingsWindow()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: NemrionScale.textXs, weight: .bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(PanelButtonStyle(variant: .secondary, size: .compact))
            .help("Close")
        }
    }

    private var workspaceCard: some View {
        settingsCard(
            title: "Workspace",
            subtitle: "Provider, model, and hotkey."
        ) {
            VStack(alignment: .leading, spacing: NemrionScale.space3) {
                VStack(spacing: NemrionScale.space2) {
                    ForEach(ProviderKind.allCases) { provider in
                        providerOption(provider)
                    }
                }

                modelSelector
                if selectedModelSupportsThinking {
                    thinkingToggle
                }

                HotkeyValueField(hotKey: app.settings.hotKeyDisplay)
            }
        }
    }

    private var runtimeCard: some View {
        settingsCard(
            title: "Runtime",
            subtitle: "Status and access."
        ) {
            VStack(alignment: .leading, spacing: NemrionScale.space3) {
                HStack(alignment: .top, spacing: NemrionScale.space3) {
                    Group {
                        if runtimeActionDisabled {
                            runtimeStatusRow
                        } else {
                            Button {
                                handleRuntimeAction()
                            } label: {
                                runtimeStatusRow
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    permissionStatus
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private var runtimeStatusRow: some View {
        statTile(
            eyebrow: "Runtime",
            title: "Ollama",
            value: app.dependencyStatus.title,
            icon: runtimeIcon,
            tint: runtimeColor,
            trailingSymbol: runtimeActionDisabled ? nil : "arrow.up.right"
        )
    }

    private var permissionStatus: some View {
        HStack(spacing: NemrionScale.space2) {
            statTile(
                eyebrow: "Access",
                title: "Accessibility",
                value: app.permissionMonitor.isTrusted ? "Granted" : "Waiting for access",
                icon: "nemrion.mark",
                tint: app.permissionMonitor.isTrusted ? NemrionTheme.success : NemrionTheme.warning,
                trailingSymbol: nil,
                iconSize: 36
            )

            if app.permissionMonitor.isTrusted == false {
                Button {
                    app.openAccessibilitySettings()
                } label: {
                    Text("Open Settings")
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(PanelButtonStyle(variant: .secondary))
                .frame(maxWidth: 148)
            }
        }
    }

    private func providerOption(_ provider: ProviderKind) -> some View {
        Button {
            app.settings.provider = provider
        } label: {
            settingsTile(
                eyebrow: "Provider",
                title: provider.displayName,
                detail: "Local-first runtime using shared Ollama models.",
                icon: "shippingbox.fill",
                tint: NemrionTheme.textSecondary,
                trailingSymbol: app.settings.provider == provider ? "checkmark.circle.fill" : nil
            )
        }
        .buttonStyle(.plain)
    }

    private var modelSelector: some View {
        Button {
            guard app.availableModels.isEmpty == false else { return }
            isModelPickerPresented.toggle()
        } label: {
            settingsTile(
                eyebrow: "Model",
                title: selectedModelTitle,
                detail: modelSelectorDetail,
                icon: "cpu.fill",
                tint: NemrionTheme.textSecondary,
                trailingSymbol: app.availableModels.isEmpty ? nil : (isModelPickerPresented ? "chevron.up" : "chevron.down"),
                trailingLabel: nil
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isModelPickerPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            modelPickerPopover
        }
    }

    private var thinkingToggle: some View {
        HStack(alignment: .top, spacing: NemrionScale.space2) {
            SurfaceIconBadge(
                symbol: "brain.head.profile",
                tint: app.settings.isThinkingEnabled ? NemrionTheme.accent : NemrionTheme.textSecondary
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("THINKING")
                    .font(.system(size: NemrionScale.textXs, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(NemrionTheme.textTertiary)

                Text("Reasoning")
                    .font(.system(size: NemrionScale.textMd, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textPrimary)

                Text(app.settings.isThinkingEnabled ? "Enabled for supported models" : "Disabled for faster rewrites")
                    .font(.system(size: NemrionScale.textSm, weight: .medium))
                    .foregroundStyle(NemrionTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: $app.settings.isThinkingEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .help(app.settings.isThinkingEnabled ? "Disable thinking" : "Enable thinking")
        }
        .padding(NemrionScale.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nemrionSurface(.tile)
    }

    private var modelPickerPopover: some View {
        VStack(spacing: 0) {
            ForEach(app.availableModels) { model in
                Button {
                    app.settings.modelName = model.id
                    if GenerationRequest.supportsThinking(model: model.id) == false {
                        app.settings.isThinkingEnabled = false
                    }
                    isModelPickerPresented = false
                    Task { await app.refreshProviderState(prewarm: true) }
                } label: {
                    HStack(spacing: NemrionScale.space2) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.title)
                                .font(.system(size: NemrionScale.textSm, weight: .semibold))
                                .foregroundStyle(model.id == app.settings.modelName ? NemrionTheme.inkOnAccent : NemrionTheme.textPrimary)

                            Text(modelPickerDetail(for: model))
                                .font(.system(size: NemrionScale.textXs, weight: .medium))
                                .foregroundStyle(model.id == app.settings.modelName ? NemrionTheme.textPrimary : NemrionTheme.textSecondary)
                        }

                        Spacer(minLength: 0)

                        if model.id == app.settings.modelName {
                            Image(systemName: "checkmark")
                                .font(.system(size: NemrionScale.textXs, weight: .bold))
                                .foregroundStyle(NemrionTheme.inkOnAccent)
                        }
                    }
                    .padding(.horizontal, NemrionScale.space3)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .background(model.id == app.settings.modelName ? NemrionTheme.surfaceInteractive : Color.clear)
                }
                .buttonStyle(.plain)

                if model.id != app.availableModels.last?.id {
                    Divider()
                        .overlay(NemrionTheme.border)
                }
            }
        }
        .frame(width: 320)
        .background(NemrionTheme.surfaceStrong)
        .nemrionSurface(.tileStrong)
        .padding(NemrionScale.space2)
    }

    private var selectedModelTitle: String {
        if let model = app.availableModels.first(where: { $0.id == app.settings.modelName }) {
            return model.title
        }
        if app.settings.modelName.isEmpty == false {
            return app.settings.modelName
        }
        return app.availableModels.first?.title ?? "No models found"
    }

    private var modelSelectorDetail: String {
        if app.availableModels.isEmpty {
            return app.settings.modelName.isEmpty
                ? "No local models available in Ollama yet"
                : "Selected model will refresh when Ollama is available"
        }
        return selectedModelSupportsThinking ? "Local model with thinking support" : "Local model"
    }

    private var selectedModelSupportsThinking: Bool {
        GenerationRequest.supportsThinking(model: app.settings.modelName)
    }

    private var runtimeActionDisabled: Bool {
        switch app.dependencyStatus {
        case .ready, .checking, .warmingModel:
            return true
        case .ollamaStopped:
            return false
        case .ollamaMissing, .unavailable:
            return true
        }
    }

    private func handleRuntimeAction() {
        guard app.dependencyStatus == .ollamaStopped else { return }
        app.startOllama()
    }

    private func settingsTile(
        eyebrow: String,
        title: String,
        detail: String,
        icon: String,
        tint: Color,
        iconBackground: Color? = nil,
        iconForeground: Color? = nil,
        trailingSymbol: String? = nil,
        trailingLabel: String? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: NemrionScale.space2) {
            SurfaceIconBadge(
                symbol: icon,
                tint: tint,
                backgroundColor: iconBackground,
                symbolColor: iconForeground
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased())
                    .font(.system(size: NemrionScale.textXs, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(NemrionTheme.textTertiary)

                Text(title)
                    .font(.system(size: NemrionScale.textMd, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textPrimary)

                Text(detail)
                    .font(.system(size: NemrionScale.textSm, weight: .medium))
                    .foregroundStyle(NemrionTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if trailingSymbol != nil || trailingLabel != nil {
                VStack(alignment: .trailing, spacing: 8) {
                    if let trailingSymbol {
                        Image(systemName: trailingSymbol)
                            .font(.system(size: NemrionScale.textXs, weight: .bold))
                            .foregroundStyle(NemrionTheme.textTertiary)
                    }

                    if let trailingLabel {
                        Text(trailingLabel)
                            .font(.system(size: NemrionScale.textXs, weight: .medium))
                            .foregroundStyle(NemrionTheme.textTertiary)
                    }
                }
            }
        }
        .padding(NemrionScale.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nemrionSurface(.tile)
    }

    private func statTile(
        eyebrow: String,
        title: String,
        value: String,
        icon: String,
        tint: Color,
        trailingSymbol: String?,
        iconSize: CGFloat = 32
    ) -> some View {
        HStack(alignment: .top, spacing: NemrionScale.space2) {
            SurfaceIconBadge(symbol: icon, tint: tint, size: iconSize)

            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased())
                    .font(.system(size: NemrionScale.textXs, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(NemrionTheme.textTertiary)

                Text(title)
                    .font(.system(size: NemrionScale.textSm, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textPrimary)

                Text(value)
                    .font(.system(size: NemrionScale.textSm, weight: .medium))
                    .foregroundStyle(tint)
            }

            Spacer(minLength: 0)

            if let trailingSymbol {
                Image(systemName: trailingSymbol)
                    .font(.system(size: NemrionScale.textXs, weight: .bold))
                    .foregroundStyle(NemrionTheme.textTertiary)
            }
        }
        .padding(NemrionScale.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nemrionSurface(.tileStrong)
    }

    private func settingsCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: NemrionScale.space3) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: NemrionScale.textSm, weight: .medium))
                    .foregroundStyle(NemrionTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
        }
        .padding(NemrionScale.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nemrionSurface(.section)
    }
    private var runtimeIcon: String {
        switch app.dependencyStatus {
        case .ready:
            return "checkmark.circle.fill"
        case .checking, .warmingModel:
            return "clock.fill"
        case .ollamaMissing, .ollamaStopped, .unavailable:
            return "bolt.slash.fill"
        }
    }

    private var runtimeColor: Color {
        app.dependencyStatus == .ready ? NemrionTheme.success : NemrionTheme.textSecondary
    }

    private func modelPickerDetail(for model: ProviderModel) -> String {
        if model.id == app.settings.modelName {
            return GenerationRequest.supportsThinking(model: model.id) ? "Selected, thinking supported" : "Selected model"
        }
        return GenerationRequest.supportsThinking(model: model.id) ? "Thinking supported" : "Available local model"
    }
}

private struct HotkeyValueField: View {
    let hotKey: String

    var body: some View {
        HStack(spacing: NemrionScale.space3) {
            VStack(alignment: .leading, spacing: 2) {
                Text("HOTKEY")
                    .tracking(1)
                    .font(.system(size: NemrionScale.textXs, weight: .bold))
                    .foregroundStyle(NemrionTheme.textTertiary)

                Text("Shortcut")
                    .font(.system(size: NemrionScale.textSm, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textPrimary)
            }

            Spacer(minLength: 0)

            ShortcutChips(shortcut: hotKey)
        }
        .padding(NemrionScale.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nemrionSurface(.tile)
    }
}
