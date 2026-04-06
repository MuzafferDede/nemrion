import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppContainer

    var body: some View {
        ZStack {
            settingsBackground

            ScrollView {
                VStack(alignment: .leading, spacing: NemrionScale.space4) {
                    header
                    workspaceCard
                    runtimeCard
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, NemrionScale.space4)
                .padding(.top, 30)
                .padding(.bottom, NemrionScale.space4)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(NemrionTheme.textPrimary)

            Text("Keep runtime configuration small and get back to writing.")
                .font(.system(size: NemrionScale.textSm, weight: .medium))
                .foregroundStyle(NemrionTheme.textSecondary)
        }
    }

    private var workspaceCard: some View {
        settingsCard(
            title: "Workspace",
            subtitle: "Provider, model, and hotkey."
        ) {
            VStack(alignment: .leading, spacing: NemrionScale.space3) {
                HStack(alignment: .top, spacing: NemrionScale.space3) {
                    fieldGroup(title: "Provider") {
                        VStack(spacing: NemrionScale.space2) {
                            ForEach(ProviderKind.allCases) { provider in
                                providerOption(provider)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    fieldGroup(title: "Model") {
                        modelSelector
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                fieldGroup(title: "Hotkey") {
                    HotkeyValueField(hotKey: app.settings.hotKeyDisplay)
                }
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
                    Button {
                        handleRuntimeAction()
                    } label: {
                        runtimeStatusRow
                    }
                    .buttonStyle(.plain)
                    .disabled(runtimeActionDisabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    permissionStatus
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private var runtimeStatusRow: some View {
        HStack(spacing: NemrionScale.space2) {
            ZStack {
                RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                    .fill(runtimeColor.opacity(0.14))

                Image(systemName: runtimeIcon)
                    .font(.system(size: NemrionScale.textSm, weight: .bold))
                    .foregroundStyle(runtimeColor)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("Ollama")
                    .font(.system(size: NemrionScale.textSm, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textPrimary)

                Text(app.dependencyStatus.title)
                    .font(.system(size: NemrionScale.textSm, weight: .medium))
                    .foregroundStyle(runtimeColor == NemrionTheme.warning ? NemrionTheme.warning : NemrionTheme.textSecondary)
            }

            Spacer()

            if runtimeActionDisabled == false {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: NemrionScale.textXs, weight: .bold))
                    .foregroundStyle(NemrionTheme.textTertiary)
            }
        }
        .padding(NemrionScale.space3)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(runtimeActionDisabled ? NemrionTheme.surfaceStrong : NemrionTheme.surfaceInteractive)
        .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                .stroke(runtimeActionDisabled ? NemrionTheme.border : NemrionTheme.borderStrong, lineWidth: 1)
        )
        .opacity(runtimeActionDisabled ? 1 : 0.98)
    }

    private var permissionStatus: some View {
        HStack(spacing: NemrionScale.space2) {
            ZStack {
                RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                    .fill((app.permissionMonitor.isTrusted ? NemrionTheme.success : NemrionTheme.warning).opacity(0.14))

                NemrionMark(
                    primary: app.permissionMonitor.isTrusted ? NemrionTheme.success : NemrionTheme.warning,
                    secondary: (app.permissionMonitor.isTrusted ? NemrionTheme.success : NemrionTheme.warning).opacity(0.66),
                    lineWidth: 0.11
                )
                .padding(6)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("Accessibility")
                    .font(.system(size: NemrionScale.textSm, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textPrimary)

                Text(app.permissionMonitor.isTrusted ? "Granted" : "Waiting for access")
                    .font(.system(size: NemrionScale.textSm, weight: .medium))
                    .foregroundStyle(app.permissionMonitor.isTrusted ? NemrionTheme.success : NemrionTheme.warning)
            }

            Spacer()

            if app.permissionMonitor.isTrusted == false {
                Button {
                    app.openAccessibilitySettings()
                } label: {
                    Text("Open Settings")
                }
                .buttonStyle(PanelButtonStyle(variant: .quiet))
            }
        }
        .padding(NemrionScale.space3)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(NemrionTheme.surfaceStrong)
        .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                .stroke(NemrionTheme.border, lineWidth: 1)
        )
    }

    private func providerOption(_ provider: ProviderKind) -> some View {
        Button {
            app.settings.provider = provider
        } label: {
            HStack(spacing: NemrionScale.space2) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(.system(size: NemrionScale.textMd, weight: .semibold))
                        .foregroundStyle(NemrionTheme.textPrimary)

                    Text("Local-first runtime using shared Ollama models.")
                        .font(.system(size: NemrionScale.textSm, weight: .medium))
                        .foregroundStyle(NemrionTheme.textSecondary)
                }

                Spacer()

                Image(systemName: app.settings.provider == provider ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: NemrionScale.textMd, weight: .semibold))
                    .foregroundStyle(app.settings.provider == provider ? NemrionTheme.accentBright : NemrionTheme.textTertiary)
            }
            .padding(NemrionScale.space3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(app.settings.provider == provider ? NemrionTheme.surfaceInteractive : NemrionTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                    .stroke(app.settings.provider == provider ? NemrionTheme.borderStrong : NemrionTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var modelSelector: some View {
        Menu {
            if app.availableModels.isEmpty {
                Text("No models found")
            } else {
                ForEach(app.availableModels) { model in
                    Button(model.title) {
                        app.settings.modelName = model.id
                    }
                }
            }
        } label: {
            HStack(spacing: NemrionScale.space2) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedModelTitle)
                        .font(.system(size: NemrionScale.textMd, weight: .semibold))
                        .foregroundStyle(NemrionTheme.textPrimary)

                    Text("Installed local model")
                        .font(.system(size: NemrionScale.textSm, weight: .medium))
                        .foregroundStyle(NemrionTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: NemrionScale.textXs, weight: .bold))
                    .foregroundStyle(NemrionTheme.textTertiary)
            }
            .padding(NemrionScale.space3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NemrionTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                    .stroke(NemrionTheme.border, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }

    private var selectedModelTitle: String {
        if let model = app.availableModels.first(where: { $0.id == app.settings.modelName }) {
            return model.title
        }
        return app.availableModels.first?.title ?? "No models found"
    }

    private func fieldGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: NemrionScale.textXs, weight: .bold))
                .tracking(1)
                .foregroundStyle(NemrionTheme.textTertiary)

            content()
        }
    }

    private var runtimeActionDisabled: Bool {
        switch app.dependencyStatus {
        case .ready, .checking:
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
        .background(Color(red: 0.13, green: 0.14, blue: 0.16).opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                .stroke(NemrionTheme.border, lineWidth: 1)
        )
    }

    private var settingsBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.07, blue: 0.08),
                Color(red: 0.10, green: 0.11, blue: 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var runtimeIcon: String {
        switch app.dependencyStatus {
        case .ready:
            return "checkmark.circle.fill"
        case .checking:
            return "clock.fill"
        case .ollamaMissing, .ollamaStopped, .unavailable:
            return "bolt.slash.fill"
        }
    }

    private var runtimeColor: Color {
        switch app.dependencyStatus {
        case .ready:
            return NemrionTheme.success
        case .checking:
            return NemrionTheme.warning
        case .ollamaMissing, .ollamaStopped, .unavailable:
            return NemrionTheme.warning
        }
    }
}

private struct SettingsValueField: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: NemrionScale.space2) {
            Image(systemName: icon)
                .font(.system(size: NemrionScale.textSm, weight: .semibold))
                .foregroundStyle(NemrionTheme.textSecondary)
                .frame(width: 28, height: 28)
                .background(NemrionTheme.surfaceStrong)
                .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: NemrionScale.textMd, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textPrimary)

                Text(detail)
                    .font(.system(size: NemrionScale.textSm, weight: .medium))
                    .foregroundStyle(NemrionTheme.textSecondary)
            }

            Spacer()
        }
        .padding(NemrionScale.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NemrionTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                .stroke(NemrionTheme.border, lineWidth: 1)
        )
    }
}

private struct HotkeyValueField: View {
    let hotKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: NemrionScale.space2) {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.system(size: NemrionScale.textSm, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(NemrionTheme.surfaceStrong)
                    .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Shortcut")
                        .font(.system(size: NemrionScale.textSm, weight: .semibold))
                        .foregroundStyle(NemrionTheme.textPrimary)

                    Text("Global trigger")
                        .font(.system(size: NemrionScale.textSm, weight: .medium))
                        .foregroundStyle(NemrionTheme.textSecondary)
                }
            }

            ShortcutChips(shortcut: hotKey)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NemrionTheme.surfaceStrong)
                .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                        .stroke(NemrionTheme.border, lineWidth: 1)
                )
        }
        .padding(NemrionScale.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NemrionTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                .stroke(NemrionTheme.border, lineWidth: 1)
        )
    }
}
