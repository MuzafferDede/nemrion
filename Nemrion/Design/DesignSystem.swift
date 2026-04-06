import SwiftUI

enum NemrionTheme {
    static let backgroundStart = Color(red: 0.043, green: 0.051, blue: 0.071)
    static let backgroundRaised = Color(red: 0.086, green: 0.102, blue: 0.133)
    static let surface = Color(red: 0.106, green: 0.122, blue: 0.157).opacity(0.92)
    static let surfaceStrong = Color(red: 0.145, green: 0.161, blue: 0.200).opacity(0.96)
    static let surfaceInteractive = Color(red: 0.153, green: 0.612, blue: 0.451).opacity(0.95)
    static let border = Color(red: 0.180, green: 0.208, blue: 0.255).opacity(0.96)
    static let borderStrong = Color(red: 0.231, green: 0.310, blue: 0.455).opacity(0.46)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.723, green: 0.777, blue: 0.862)
    static let textTertiary = Color(red: 0.560, green: 0.616, blue: 0.708)
    static let accent = Color(red: 0.153, green: 0.612, blue: 0.451)
    static let accentMuted = Color(red: 0.118, green: 0.494, blue: 0.361)
    static let brandMarkPrimary = Color(red: 0.898, green: 0.416, blue: 0.180)
    static let brandMarkSecondary = Color.white.opacity(0.74)
    static let blueStrong = Color(red: 0.231, green: 0.310, blue: 0.455)
    static let inkOnAccent = Color.black.opacity(0.84)
    static let success = accent
    static let warning = accent
    static let error = brandMarkPrimary
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
}

struct NemrionBackground: View {
    var body: some View {
        NemrionTheme.backgroundStart
        .ignoresSafeArea()
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
            NemrionTheme.backgroundRaised
        case .section:
            NemrionTheme.backgroundRaised.opacity(0.95)
        case .tile:
            NemrionTheme.surface
        case .tileStrong:
            NemrionTheme.surfaceStrong
        case .interactive:
            NemrionTheme.surfaceInteractive
        }
    }

    private var border: Color {
        switch kind {
        case .shell, .section, .tile, .tileStrong:
            return NemrionTheme.border
        case .interactive:
            return NemrionTheme.borderStrong
        }
    }
}

extension View {
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
                .fill(configuration.isPressed ? NemrionTheme.accentMuted : NemrionTheme.accent)
        case .secondary:
            RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                .fill(
                    configuration.isPressed
                    ? NemrionTheme.surfaceStrong.opacity(0.98)
                    : NemrionTheme.surface.opacity(0.98)
                )
        case .quiet:
            NemrionTheme.surface.opacity(configuration.isPressed ? 0.65 : 0.35)
        }
    }

    private func borderColor(configuration: Configuration) -> Color {
        switch variant {
        case .primary:
            return NemrionTheme.accentMuted.opacity(configuration.isPressed ? 0.42 : 0.68)
        case .secondary:
            return NemrionTheme.borderStrong.opacity(configuration.isPressed ? 0.38 : 0.56)
        case .quiet:
            return NemrionTheme.border.opacity(0.45)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return NemrionTheme.textPrimary
        case .secondary:
            return NemrionTheme.textPrimary
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
    var backgroundColor: Color? = nil
    var symbolColor: Color? = nil
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                .fill(backgroundColor ?? NemrionTheme.backgroundStart.opacity(0.92))

            if symbol == "nemrion.mark" {
                NemrionMark(
                    primary: symbolColor ?? NemrionTheme.brandMarkPrimary,
                    secondary: symbolColor ?? NemrionTheme.brandMarkSecondary,
                    lineWidth: 0.11
                )
                .padding(size * 0.19)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: NemrionScale.textSm, weight: .bold))
                    .foregroundStyle(symbolColor ?? tint)
            }
        }
        .frame(width: size, height: size)
        .aspectRatio(1, contentMode: .fit)
    }
}

struct NemrionMark: View {
    var primary: Color = NemrionTheme.brandMarkPrimary
    var secondary: Color = NemrionTheme.brandMarkSecondary
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
                    primary,
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
