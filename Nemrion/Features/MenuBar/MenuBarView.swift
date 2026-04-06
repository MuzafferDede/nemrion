import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var app: AppContainer

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
            VStack(alignment: .leading, spacing: 4) {
                EyebrowLabel(text: "Menu Bar")

                Text("Nemrion")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(NemrionTheme.textPrimary)

                Text("Polish selected text anywhere on macOS")
                    .font(.system(size: NemrionScale.textXs, weight: .medium))
                    .foregroundStyle(NemrionTheme.textSecondary)
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
        Button {
            handleRuntimeAction()
        } label: {
            runtimeRow
        }
        .buttonStyle(.plain)
        .disabled(runtimeActionDisabled)
    }

    private var runtimeRow: some View {
        compactActionTile(
            symbol: runtimeSymbol,
            title: "Runtime",
            subtitle: statusText,
            isPrimary: false,
            tint: runtimeColor,
            emphasized: runtimeActionDisabled == false,
            showsArrow: runtimeActionDisabled == false
        )
        .opacity(runtimeActionDisabled ? 0.92 : 1)
    }

    private var actionsRow: some View {
        Button {
            Task { await app.triggerPolishFlow(source: .menuBar) }
        } label: {
            compactActionTile(
                symbol: "nemrion.mark",
                title: "Polish",
                subtitle: "Rewrite",
                isPrimary: true,
                showsArrow: true
            )
        }
        .buttonStyle(.plain)
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

    private var runtimeBackground: Color {
        runtimeActionDisabled ? Color.white.opacity(0.06) : NemrionTheme.surfaceInteractive
    }

    private var runtimeBorder: Color {
        runtimeActionDisabled ? NemrionTheme.border : NemrionTheme.borderStrong
    }

    private func handleRuntimeAction() {
        guard app.dependencyStatus == .ollamaStopped else { return }
        app.startOllama()
    }

    private var runtimeSymbol: String {
        switch app.dependencyStatus {
        case .ready:
            return "checkmark.circle.fill"
        case .checking:
            return "clock.fill"
        case .ollamaMissing, .ollamaStopped, .unavailable:
            return "bolt.fill"
        }
    }

    private func compactActionTile(
        symbol: String,
        title: String,
        subtitle: String,
        isPrimary: Bool,
        tint: Color? = nil,
        emphasized: Bool = false,
        showsArrow: Bool = false
    ) -> some View {
        return HStack(spacing: NemrionScale.space2) {
            actionIcon(symbol: symbol, strong: isPrimary, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: NemrionScale.textSm, weight: .semibold))
                    .foregroundStyle(isPrimary ? Color.white : NemrionTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: NemrionScale.textXs, weight: .medium))
                    .foregroundStyle(isPrimary ? Color.white.opacity(0.72) : NemrionTheme.textSecondary)
            }

            Spacer()

            if showsArrow {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: NemrionScale.textXs, weight: .bold))
                    .foregroundStyle(isPrimary ? Color.white.opacity(0.72) : NemrionTheme.textTertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .nemrionSurface(tileKind(isPrimary: isPrimary, emphasized: emphasized))
    }

    private func actionIcon(symbol: String, strong: Bool, tint: Color? = nil) -> some View {
        SurfaceIconBadge(
            symbol: symbol,
            tint: strong ? Color.white : (tint ?? NemrionTheme.textPrimary)
        )
        .frame(width: 28, height: 28)
    }

    private func tileKind(isPrimary: Bool, emphasized: Bool) -> NemrionSurfaceKind {
        if isPrimary || emphasized {
            return .interactive
        }
        return .tile
    }

    private func toolbarIcon(symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: NemrionScale.textSm, weight: .bold))
            .foregroundStyle(NemrionTheme.textPrimary)
            .frame(width: 30, height: 30)
            .nemrionSurface(.tile)
    }
}
