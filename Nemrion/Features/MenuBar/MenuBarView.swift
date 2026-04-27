import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var app: AppContainer
    @Environment(\.dismiss) private var dismiss

    private var statusText: String {
        app.dependencyStatus.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NemrionScale.space3) {
            topBar
            summary
            actionsRow
        }
        .padding(NemrionScale.space3)
        .nemrionSurface(.shell)
        .frame(width: 320)
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: NemrionScale.space2) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Nemrion")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(NemrionTheme.textPrimary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    app.openSettingsWindow()
                } label: {
                    toolbarIcon(symbol: "gearshape")
                }
                .buttonStyle(.plain)

                Button {
                    NSApp.terminate(nil)
                } label: {
                    toolbarIcon(symbol: "power")
                }
                .buttonStyle(.plain)
                .help("Quit Nemrion")
            }
        }
    }

    private var summary: some View {
        Group {
            if runtimeActionDisabled {
                runtimeRow
            } else {
                Button {
                    handleRuntimeAction()
                } label: {
                    runtimeRow
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var runtimeRow: some View {
        compactActionTile(
            symbol: runtimeSymbol,
            title: "Runtime",
            subtitle: statusText,
            tint: runtimeColor,
            showsArrow: runtimeActionDisabled == false
        )
    }

    private var actionsRow: some View {
        Button {
            dismiss()
            Task { await app.triggerPolishFlow() }
        } label: {
            compactActionTile(
                symbol: "nemrion.mark",
                title: "Polish",
                subtitle: "Rewrite",
                tint: NemrionTheme.textSecondary,
                showsArrow: true
            )
        }
        .buttonStyle(.plain)
    }

    private var runtimeColor: Color {
        app.dependencyStatus == .ready ? NemrionTheme.success : NemrionTheme.textSecondary
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

    private var runtimeSymbol: String {
        switch app.dependencyStatus {
        case .ready:
            return "checkmark.circle.fill"
        case .checking, .warmingModel:
            return "clock.fill"
        case .ollamaMissing, .ollamaStopped, .unavailable:
            return "bolt.fill"
        }
    }

    private func compactActionTile(
        symbol: String,
        title: String,
        subtitle: String,
        tint: Color? = nil,
        showsArrow: Bool = false
    ) -> some View {
        return HStack(spacing: NemrionScale.space2) {
            actionIcon(symbol: symbol, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: NemrionScale.textSm, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: NemrionScale.textXs, weight: .medium))
                    .foregroundStyle(tint ?? NemrionTheme.textSecondary)
            }

            Spacer()

            if showsArrow {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: NemrionScale.textXs, weight: .bold))
                    .foregroundStyle(NemrionTheme.textTertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .nemrionSurface(.tile)
    }

    private func actionIcon(symbol: String, tint: Color? = nil) -> some View {
        SurfaceIconBadge(
            symbol: symbol,
            tint: tint ?? NemrionTheme.textSecondary
        )
        .frame(width: 28, height: 28)
    }

    private func toolbarIcon(symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: NemrionScale.textSm, weight: .bold))
            .foregroundStyle(NemrionTheme.textPrimary)
            .frame(width: 30, height: 30)
            .nemrionSurface(.tile)
    }
}
