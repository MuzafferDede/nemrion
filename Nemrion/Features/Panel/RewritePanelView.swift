import SwiftUI

struct RewritePanelView: View {
    @ObservedObject var viewModel: RewritePanelViewModel
    @EnvironmentObject private var app: AppContainer

    var body: some View {
        ZStack {
            NemrionBackground()

            VStack(spacing: NemrionScale.space3) {
                topBar
                if let headerMessage {
                    headerMessageView(headerMessage)
                }
                bodyContainer
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(NemrionScale.space4)
        }
        .frame(minWidth: 680, idealWidth: 760, minHeight: 500)
    }

    private var bodyContainer: some View {
        VStack(spacing: NemrionScale.space3) {
            resultSurface
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            promptComposer
        }
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: NemrionScale.space3) {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("Polish")
                        .font(.system(size: NemrionScale.textLg, weight: .bold))
                } icon: {
                    NemrionMark(lineWidth: 0.11)
                        .frame(width: 18, height: 18)
                }
                .foregroundStyle(NemrionTheme.textPrimary)

                Text(statusLine)
                    .font(.system(size: NemrionScale.textSm, weight: .medium))
                    .foregroundStyle(NemrionTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            HStack(alignment: .top, spacing: NemrionScale.space2) {
                VStack(alignment: .trailing, spacing: 6) {
                    Text(resultTrailing)
                        .font(.system(size: NemrionScale.textXs, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(NemrionTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .nemrionSurface(.tileStrong)

                    Text(sourceLabel)
                        .font(.system(size: NemrionScale.textSm, weight: .medium))
                        .foregroundStyle(NemrionTheme.textTertiary)
                        .lineLimit(1)
                }

                Button {
                    app.dismissPanel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: NemrionScale.textXs, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(PanelButtonStyle(variant: .secondary, size: .compact))
                .help("Close")
            }
        }
        .padding(.horizontal, 2)
    }

    private var promptComposer: some View {
        HStack(alignment: .center, spacing: NemrionScale.space2) {
            HStack(spacing: NemrionScale.space2) {
                Image(systemName: "lightbulb")
                    .font(.system(size: NemrionScale.textSm, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textTertiary)

                TextField("Tell Nemrion how to refine this result…", text: $viewModel.instruction)
                    .textFieldStyle(.plain)
                    .font(.system(size: NemrionScale.textSm, weight: .medium))
                    .foregroundStyle(NemrionTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onSubmit {
                        Task { await viewModel.submitInstruction() }
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await viewModel.submitInstruction() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: NemrionScale.textSm, weight: .bold))
                    .foregroundStyle(NemrionTheme.inkOnAccent)
                    .frame(width: 36, height: 36)
                    .nemrionSurface(.interactive)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.sourceText.isEmpty || viewModel.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || app.dependencyStatus != .ready)
            .opacity(viewModel.sourceText.isEmpty || viewModel.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || app.dependencyStatus != .ready ? 0.5 : 1)
            .help("Send prompt")
        }
        .padding(NemrionScale.space2)
        .frame(minHeight: 52)
        .nemrionSurface(.tile)
    }

    private var resultSurface: some View {
        VStack(alignment: .leading, spacing: NemrionScale.space2) {
            resultHeader
            if viewModel.thinkingText.isEmpty == false {
                thinkingTranscript
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.outputText.isEmpty, viewModel.phase == .generating {
                        streamingPlaceholder
                    } else {
                        Text(outputBody)
                            .font(.system(size: NemrionScale.textMd, weight: .medium))
                            .lineSpacing(5)
                            .foregroundStyle(outputColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(NemrionScale.space3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.12))
            .overlay {
                RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                    .stroke(NemrionTheme.border.opacity(0.6), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))

            resultActions
                .padding(.top, NemrionScale.space1)
        }
        .padding(NemrionScale.space3)
        .nemrionSurface(.section)
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var resultHeader: some View {
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
                    Text(viewModel.isThinking ? "Thinking" : "Streaming")
                        .font(.system(size: NemrionScale.textSm, weight: .medium))
                        .foregroundStyle(NemrionTheme.textSecondary)
                    Button {
                        viewModel.stopGeneration()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(PanelButtonStyle(variant: .secondary, size: .compact))
                    .help("Stop generation")
                }
            }
        }
    }

    private var thinkingTranscript: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: NemrionScale.textXs, weight: .semibold))
                    .foregroundStyle(NemrionTheme.accent)

                Text(viewModel.isThinking ? "Thinking" : "Thoughts")
                    .font(.system(size: NemrionScale.textSm, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textPrimary)

                Spacer(minLength: 0)
            }

            ScrollView {
                Text(viewModel.thinkingText.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: NemrionScale.textXs, weight: .medium, design: .monospaced))
                    .lineSpacing(4)
                    .foregroundStyle(NemrionTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.bottom, 2)
            }
            .frame(maxHeight: 110)
        }
        .padding(NemrionScale.space2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.10))
        .overlay {
            RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                .stroke(NemrionTheme.border.opacity(0.5), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))
    }

    @ViewBuilder
    private func headerMessageView(_ message: String) -> some View {
        Text(message)
            .font(.system(size: NemrionScale.textSm, weight: .medium))
            .foregroundStyle(headerMessageColor(message))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
    }

    private func headerMessageColor(_ message: String) -> Color {
        if message == NemrionError.noSelection.localizedDescription {
            return NemrionTheme.brandMarkPrimary
        }
        return NemrionTheme.error
    }

    private var resultActions: some View {
        HStack(spacing: NemrionScale.space2) {
            if app.permissionMonitor.isTrusted == false {
                Button {
                    app.requestAccessibilityPrompt()
                } label: {
                    Label("Grant Access", systemImage: "hand.raised")
                }
                .buttonStyle(PanelButtonStyle(variant: .secondary))
            }

            Button {
                app.openSettingsWindow()
            } label: {
                Label("Open Settings", systemImage: "gearshape")
            }
            .buttonStyle(PanelButtonStyle(variant: .secondary))

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
                Label(viewModel.isApplying ? "Applying..." : "Apply", systemImage: "checkmark")
            }
            .buttonStyle(PanelButtonStyle(variant: .primary))
            .disabled(viewModel.outputText.isEmpty || viewModel.isApplying)
        }
    }

    private var statusLine: String {
        switch viewModel.phase {
        case .idle:
            return "Select text anywhere and run Nemrion."
        case .capturing:
            return "Capturing the active selection."
        case .generating:
            return viewModel.isThinking ? "Thinking before writing." : "Generating a rewritten version."
        case .ready:
            return "Adjust the prompt if needed, then apply the result."
        case .failure:
            return "Fix the issue below, then try again."
        }
    }

    private var headerMessage: String? {
        if case let .failure(message) = viewModel.phase {
            return message
        }
        return nil
    }

    private var sourceLabel: String {
        viewModel.sourceAppName == "Current App" ? "Awaiting source app" : viewModel.sourceAppName
    }

    private var resultTrailing: String {
        switch viewModel.phase {
        case .capturing:
            return "CAPTURING"
        case .generating:
            return viewModel.isThinking ? "THINKING" : "STREAMING"
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
        case .idle:
            return "The rewritten text will appear here."
        case .failure:
            return "The rewritten text will appear here."
        default:
            return viewModel.outputText
        }
    }

    private var outputColor: Color {
        return viewModel.outputText.isEmpty ? NemrionTheme.textSecondary : NemrionTheme.textPrimary
    }

    private var streamingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isThinking {
                Label("Thinking", systemImage: "brain.head.profile")
                    .font(.system(size: NemrionScale.textSm, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textSecondary)
                    .padding(.bottom, 2)
            }

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
