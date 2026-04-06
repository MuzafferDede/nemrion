import SwiftUI

struct PermissionGuidanceView: View {
    let isTrusted: Bool
    let requestAccess: () -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NemrionScale.space2) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: NemrionScale.radius, style: .continuous)
                        .fill((isTrusted ? NemrionTheme.success : NemrionTheme.warning).opacity(0.14))

                    NemrionMark(lineWidth: 0.11)
                    .padding(6)
                }
                .frame(width: 28, height: 28)

                Text(isTrusted ? "Accessibility access granted" : "Accessibility access required")
                    .font(.system(size: NemrionScale.textSm, weight: .medium))
                    .foregroundStyle(isTrusted ? NemrionTheme.success : NemrionTheme.warning)
            }

            Text("Nemrion needs Accessibility access to read selected text, show the contextual bubble accurately, and replace the rewritten text back into the source app.")
                .font(.system(size: NemrionScale.textSm))
                .foregroundStyle(NemrionTheme.textSecondary)

            HStack(spacing: NemrionScale.space2) {
                Button {
                    requestAccess()
                } label: {
                    Label("Request Access", systemImage: "hand.raised")
                }
                .buttonStyle(PanelButtonStyle(variant: .primary))

                Button {
                    openSettings()
                } label: {
                    Label("Open System Settings", systemImage: "gearshape")
                }
                .buttonStyle(PanelButtonStyle(variant: .secondary))
            }
        }
    }
}
