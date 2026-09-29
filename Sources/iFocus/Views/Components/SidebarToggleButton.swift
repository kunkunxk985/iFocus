import SwiftUI

/// Sleek macOS toolbar button paired with the custom glass traffic-light cluster.
struct SidebarToggleButton: View {
    @Binding var sidebarCollapsed: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button {
            withAnimation(AppTheme.springGentle) {
                sidebarCollapsed.toggle()
                WindowLayoutStore.isSidebarCollapsed = sidebarCollapsed
                WindowStateModel.shared.isSidebarCollapsed = sidebarCollapsed
            }
        } label: {
            Image(systemName: "sidebar.leading")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundColor(
                    isHovering
                    ? AppTheme.primaryText(for: colorScheme)
                    : AppTheme.secondaryText(for: colorScheme).opacity(0.85)
                )
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            isHovering
                            ? (colorScheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.09))
                            : Color.clear
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            isHovering
                            ? (colorScheme == .light ? Color.black.opacity(0.05) : Color.white.opacity(0.08))
                            : Color.clear,
                            lineWidth: 0.5
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(SidebarToolbarButtonStyle())
        .onHover { isHovering = $0 }
        .help(sidebarCollapsed ? "展开侧栏 (⌃⌘S)" : "收起侧栏 (⌃⌘S)")
    }
}

struct SidebarToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
