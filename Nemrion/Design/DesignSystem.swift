import SwiftUI

enum NemrionTheme {
    static let backgroundStart = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let backgroundEnd = Color(red: 0.08, green: 0.09, blue: 0.10)
    static let backgroundRaised = Color(red: 0.11, green: 0.12, blue: 0.14)
    static let panelShell = Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.86)
    static let surface = Color.white.opacity(0.055)
    static let surfaceStrong = Color.white.opacity(0.085)
    static let surfaceInteractive = Color(red: 0.16, green: 0.17, blue: 0.19).opacity(0.95)
    static let border = Color.white.opacity(0.10)
    static let borderStrong = Color.white.opacity(0.16)
    static let textPrimary = Color.white.opacity(0.97)
    static let textSecondary = Color.white.opacity(0.70)
    static let textTertiary = Color.white.opacity(0.48)
    static let accent = Color(red: 0.11, green: 0.18, blue: 0.30)
    static let accentBright = Color(red: 0.17, green: 0.27, blue: 0.43)
    static let accentMuted = Color(red: 0.10, green: 0.14, blue: 0.22)
    static let blueStrong = Color(red: 0.20, green: 0.21, blue: 0.24)
    static let blueBright = Color(red: 0.27, green: 0.28, blue: 0.32)
    static let success = Color(red: 0.36, green: 0.86, blue: 0.68)
    static let warning = Color(red: 0.96, green: 0.74, blue: 0.36)
    static let error = Color(red: 0.98, green: 0.46, blue: 0.51)
}

enum NemrionScale {
    private static let ratio: CGFloat = 1.25

    static let space1: CGFloat = 8
    static let space2: CGFloat = space1 * ratio
    static let space3: CGFloat = space2 * ratio
    static let space4: CGFloat = space3 * ratio

    static let radius: CGFloat = 4

    static let textXs: CGFloat = 11
    static let textSm: CGFloat = textXs * ratio
    static let textMd: CGFloat = textSm * ratio
    static let textLg: CGFloat = textMd * ratio
}

enum NemrionSurfaceKind {
    case shell
    case section
    case tile
    case tileStrong
    case interactive
    case inset
}

struct NemrionBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [NemrionTheme.backgroundStart, NemrionTheme.backgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [NemrionTheme.accent.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 520
            )
            .offset(x: 120, y: -80)

            RadialGradient(
                colors: [Color.white.opacity(0.08), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 420
            )
            .offset(x: -120, y: -120)

            MeshBackdrop()
                .blendMode(.plusLighter)
                .opacity(0.22)
        }
        .ignoresSafeArea()
    }
}

struct MeshBackdrop: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [NemrionTheme.accent.opacity(0.28), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 80)
                .frame(width: 320, height: 320)
                .offset(x: 180, y: -100)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 90)
                .frame(width: 260, height: 260)
                .offset(x: -170, y: 140)
        }
    }
}

struct GlassCardModifier: ViewModifier {
    var radius: CGFloat = NemrionScale.radius

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial.opacity(0.72))
            .background(NemrionTheme.panelShell)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.white.opacity(0.14), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(NemrionTheme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.44), radius: 34, y: 18)
    }
}

struct SectionCardModifier: ViewModifier {
    var radius: CGFloat = NemrionScale.radius
    var strong: Bool = false

    func body(content: Content) -> some View {
        content
            .background(strong ? NemrionTheme.surfaceStrong : NemrionTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(strong ? NemrionTheme.borderStrong : NemrionTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct NemrionSurfaceModifier: ViewModifier {
    let kind: NemrionSurfaceKind
    var radius: CGFloat = NemrionScale.radius

    func body(content: Content) -> some View {
        content
            .background(background)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    @ViewBuilder
    private var background: some View {
        switch kind {
        case .shell:
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.10, blue: 0.11),
                    Color(red: 0.12, green: 0.13, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .section:
            Color(red: 0.13, green: 0.14, blue: 0.16).opacity(0.94)
        case .tile:
            NemrionTheme.surface
        case .tileStrong:
            NemrionTheme.surfaceStrong
        case .interactive:
            NemrionTheme.surfaceInteractive
        case .inset:
            Color.black.opacity(0.12)
        }
    }

    private var border: Color {
        switch kind {
        case .shell, .section, .tile, .tileStrong, .inset:
            return NemrionTheme.border
        case .interactive:
            return NemrionTheme.borderStrong
        }
    }
}

extension View {
    func glassCard(radius: CGFloat = NemrionScale.radius) -> some View {
        modifier(GlassCardModifier(radius: radius))
    }

    func sectionCard(radius: CGFloat = NemrionScale.radius, strong: Bool = false) -> some View {
        modifier(SectionCardModifier(radius: radius, strong: strong))
    }

    func nemrionSurface(_ kind: NemrionSurfaceKind, radius: CGFloat = NemrionScale.radius) -> some View {
        modifier(NemrionSurfaceModifier(kind: kind, radius: radius))
    }
}

enum PanelButtonVariant {
    case primary
    case secondary
    case quiet
}

enum PanelButtonSize {
    case regular
    case compact
}

struct PanelButtonStyle: ButtonStyle {
    var variant: PanelButtonVariant = .secondary
    var size: PanelButtonSize = .regular

    init(variant: PanelButtonVariant = .secondary, size: PanelButtonSize = .regular) {
        self.variant = variant
        self.size = size
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: NemrionScale.textSm, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(buttonBackground(configuration: configuration))
            .overlay(
                RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                    .stroke(borderColor(configuration: configuration), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.986 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }

    @ViewBuilder
    private func buttonBackground(configuration: Configuration) -> some View {
        switch variant {
        case .primary:
            RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: configuration.isPressed
                        ? [NemrionTheme.accent.opacity(0.92), NemrionTheme.accent.opacity(0.80)]
                        : [NemrionTheme.accentBright, NemrionTheme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case .secondary:
            RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                .fill(
                    configuration.isPressed
                    ? NemrionTheme.blueStrong.opacity(0.96)
                    : NemrionTheme.blueBright.opacity(0.98)
                )
        case .quiet:
            NemrionTheme.surface.opacity(configuration.isPressed ? 0.65 : 0.35)
        }
    }

    private func borderColor(configuration: Configuration) -> Color {
        switch variant {
        case .primary:
            return Color.white.opacity(configuration.isPressed ? 0.14 : 0.24)
        case .secondary:
            return Color.white.opacity(configuration.isPressed ? 0.10 : 0.18)
        case .quiet:
            return NemrionTheme.border.opacity(0.45)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .secondary:
            return .white
        case .quiet:
            return NemrionTheme.textPrimary
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular:
            return NemrionScale.space3
        case .compact:
            return 0
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular:
            return NemrionScale.space2
        case .compact:
            return 0
        }
    }
}

struct EyebrowLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: NemrionScale.textXs, weight: .bold, design: .rounded))
            .tracking(1.3)
            .foregroundStyle(NemrionTheme.textTertiary)
    }
}

struct SurfaceIconBadge: View {
    let symbol: String
    var tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                .fill(tint.opacity(0.14))

            if symbol == "nemrion.mark" {
                NemrionMark(
                    primary: tint,
                    secondary: tint.opacity(0.66),
                    lineWidth: 0.11
                )
                .padding(6)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: NemrionScale.textSm, weight: .bold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 32, height: 32)
    }
}

struct MetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(NemrionTheme.textTertiary)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NemrionTheme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sectionCard(radius: NemrionScale.radius, strong: true)
    }
}

struct GradientStroke: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 999, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.32), Color.white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

struct NemrionMark: View {
    var primary: Color = .white
    var secondary: Color = Color.white.opacity(0.58)
    var lineWidth: CGFloat = 0.095

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let stroke = max(1.6, size * lineWidth)

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: size * 0.08, y: size * 0.34))
                    path.addLine(to: CGPoint(x: size * 0.34, y: size * 0.34))
                    path.move(to: CGPoint(x: size * 0.08, y: size * 0.50))
                    path.addLine(to: CGPoint(x: size * 0.28, y: size * 0.50))
                    path.move(to: CGPoint(x: size * 0.08, y: size * 0.66))
                    path.addLine(to: CGPoint(x: size * 0.40, y: size * 0.66))
                }
                .stroke(secondary, style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round))

                Path { path in
                    path.move(to: CGPoint(x: size * 0.38, y: size * 0.66))
                    path.addCurve(
                        to: CGPoint(x: size * 0.56, y: size * 0.34),
                        control1: CGPoint(x: size * 0.46, y: size * 0.64),
                        control2: CGPoint(x: size * 0.50, y: size * 0.38)
                    )
                    path.addCurve(
                        to: CGPoint(x: size * 0.73, y: size * 0.45),
                        control1: CGPoint(x: size * 0.61, y: size * 0.26),
                        control2: CGPoint(x: size * 0.67, y: size * 0.25)
                    )
                    path.addCurve(
                        to: CGPoint(x: size * 0.90, y: size * 0.34),
                        control1: CGPoint(x: size * 0.79, y: size * 0.61),
                        control2: CGPoint(x: size * 0.83, y: size * 0.26)
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: [secondary, primary],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: stroke * 1.06, lineCap: .round, lineJoin: .round)
                )

                SparkShape()
                    .fill(primary)
                    .frame(width: size * 0.20, height: size * 0.20)
                    .offset(x: size * 0.31, y: -size * 0.28)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct SparkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let points = [
            CGPoint(x: w * 0.50, y: 0),
            CGPoint(x: w * 0.65, y: h * 0.35),
            CGPoint(x: w, y: h * 0.50),
            CGPoint(x: w * 0.65, y: h * 0.65),
            CGPoint(x: w * 0.50, y: h),
            CGPoint(x: w * 0.35, y: h * 0.65),
            CGPoint(x: 0, y: h * 0.50),
            CGPoint(x: w * 0.35, y: h * 0.35)
        ]

        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

struct ShortcutChips: View {
    let shortcut: String

    private var tokens: [String] {
        shortcut.split(separator: "-").map { token in
            switch token.lowercased() {
            case "command":
                return "⌘"
            case "shift":
                return "⇧"
            case "option":
                return "⌥"
            case "control":
                return "⌃"
            default:
                return String(token)
            }
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tokens, id: \.self) { token in
                Text(token)
                    .font(.system(size: NemrionScale.textSm, weight: .semibold))
                    .foregroundStyle(NemrionTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(NemrionTheme.surfaceStrong)
                    .clipShape(RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                            .stroke(NemrionTheme.border, lineWidth: 1)
                    )
            }
        }
    }
}
