import SwiftUI

struct RewritePanelView: View {
    @ObservedObject var viewModel: RewritePanelViewModel
    @EnvironmentObject private var app: AppContainer

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                NemrionBackground()

                VStack(spacing: NemrionScale.space3) {
                    topBar
                    resultSurface
                        .frame(maxHeight: .infinity)
                    promptComposer
                    footer
                }
                .padding(NemrionScale.space4)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(minWidth: 680, idealWidth: 760, minHeight: 500, idealHeight: 560)
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: NemrionScale.space3) {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("Polish")
                        .font(.system(size: NemrionScale.textLg, weight: .bold))
                } icon: {
                    NemrionMark(primary: NemrionTheme.accentBright, secondary: NemrionTheme.textSecondary, lineWidth: 0.11)
                        .frame(width: 18, height: 18)
                }
                .foregroundStyle(NemrionTheme.textPrimary)

                Text(statusLine)
                    .font(.system(size: NemrionScale.textSm, weight: .medium))
                    .foregroundStyle(NemrionTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(resultTrailing)
                    .font(.system(size: NemrionScale.textXs, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(NemrionTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(NemrionTheme.surfaceStrong)
                    .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                            .stroke(NemrionTheme.border, lineWidth: 1)
                    )

                Text(sourceLabel)
                    .font(.system(size: NemrionScale.textSm, weight: .medium))
                    .foregroundStyle(NemrionTheme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 2)
    }

    private var promptComposer: some View {
        VStack(alignment: .leading, spacing: NemrionScale.space2) {
            HStack {
                Label("Additional prompt", systemImage: "slider.horizontal.3")
                    .font(.system(size: NemrionScale.textSm, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textPrimary)

                Spacer()

                Text("Optional")
                    .font(.system(size: NemrionScale.textXs, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textTertiary)
            }

            HStack(alignment: .bottom, spacing: NemrionScale.space2) {
                TextField("Make it friendlier, shorter, clearer, or more direct...", text: $viewModel.instruction)
                    .textFieldStyle(.plain)
                    .font(.system(size: NemrionScale.textSm, weight: .medium))
                    .foregroundStyle(NemrionTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .frame(height: 40)
                    .background(Color.black.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                            .stroke(NemrionTheme.border, lineWidth: 1)
                    )
                    .onSubmit {
                        Task { await viewModel.submitInstruction() }
                    }

                Button {
                    Task { await viewModel.submitInstruction() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: NemrionScale.textSm, weight: .bold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(PanelButtonStyle(variant: .secondary, size: .compact))
                .disabled(viewModel.sourceText.isEmpty || viewModel.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || app.dependencyStatus != .ready)
                .help("Submit additional prompt")
            }
        }
        .padding(NemrionScale.space3)
        .background(NemrionTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                .stroke(NemrionTheme.border, lineWidth: 1)
        )
    }

    private var resultSurface: some View {
        VStack(alignment: .leading, spacing: NemrionScale.space2) {
            HStack {
                Label("Result", systemImage: "text.quote")
                    .font(.system(size: NemrionScale.textMd, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textPrimary)

                Spacer()

                if viewModel.phase == .generating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(NemrionTheme.accent)
                        Text("Streaming")
                            .font(.system(size: NemrionScale.textSm, weight: .medium))
                            .foregroundStyle(NemrionTheme.textSecondary)
                    }
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.outputText.isEmpty, viewModel.phase == .generating {
                        streamingPlaceholder
                    } else {
                        Text(outputBody)
                            .font(.system(size: NemrionScale.textMd, weight: .medium))
                            .lineSpacing(4)
                            .foregroundStyle(outputColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(NemrionScale.space3)
        .background(NemrionTheme.backgroundRaised.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                .stroke(NemrionTheme.borderStrong, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var footer: some View {
        HStack(spacing: NemrionScale.space2) {
            if app.permissionMonitor.isTrusted == false {
                Button {
                    app.requestAccessibilityPrompt()
                } label: {
                    Label("Grant Access", systemImage: "hand.raised")
                }
                .buttonStyle(PanelButtonStyle(variant: .secondary))
            }

            if app.dependencyStatus != .ready {
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label("Open Settings", systemImage: "gearshape")
                }
                .buttonStyle(PanelButtonStyle(variant: .secondary))
            }

            Spacer()

            Button {
                Task {
                    await viewModel.applyOutput()
                    if case .failure = viewModel.phase {
                        return
                    }
                    app.dismissPanel()
                }
            } label: {
                Label(viewModel.isApplying ? "Applying..." : "Apply", systemImage: "arrow.down.left.and.arrow.up.right")
            }
            .buttonStyle(PanelButtonStyle(variant: .primary))
            .disabled(viewModel.outputText.isEmpty || viewModel.isApplying)
        }
        .padding(.top, 2)
    }

    private var statusLine: String {
        switch viewModel.phase {
        case .idle:
            return "Select text anywhere and run Nemrion."
        case .capturing:
            return "Capturing the active selection."
        case .generating:
            return "Generating a rewritten version."
        case .ready:
            return "Adjust the prompt if needed, then apply the result."
        case let .failure(message):
            return message
        }
    }

    private var sourceLabel: String {
        viewModel.sourceAppName == "Current App" ? "Awaiting source app" : viewModel.sourceAppName
    }

    private var resultTrailing: String {
        switch viewModel.phase {
        case .capturing:
            return "CAPTURING"
        case .generating:
            return "STREAMING"
        case .ready:
            return "READY"
        case .idle:
            return "WAITING"
        case .failure:
            return "ERROR"
        }
    }

    private var outputBody: String {
        switch viewModel.phase {
        case let .failure(message):
            return message
        case .idle:
            return "The rewritten text will appear here."
        default:
            return viewModel.outputText
        }
    }

    private var outputColor: Color {
        if case .failure = viewModel.phase {
            return NemrionTheme.error
        }
        return viewModel.outputText.isEmpty ? NemrionTheme.textSecondary : NemrionTheme.textPrimary
    }

    private var streamingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<7, id: \.self) { index in
                RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                    .fill(Color.white.opacity(0.10 - (Double(index) * 0.008)))
                    .frame(height: 16)
                    .frame(maxWidth: index.isMultiple(of: 2) ? .infinity : 500, alignment: .leading)
            }
        }
        .redacted(reason: .placeholder)
        .shimmering(active: true)
    }
}

private struct ShimmerModifier: ViewModifier {
    let active: Bool
    @State private var offset: CGFloat = -0.7

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.18), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .rotationEffect(.degrees(8))
                        .offset(x: proxy.size.width * offset)
                        .onAppear {
                            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                                offset = 1.08
                            }
                        }
                    }
                    .mask(content)
                }
            }
    }
}

private extension View {
    func shimmering(active: Bool) -> some View {
        modifier(ShimmerModifier(active: active))
    }
}
