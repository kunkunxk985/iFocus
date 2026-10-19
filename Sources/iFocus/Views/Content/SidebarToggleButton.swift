import SwiftUI

/// Sleek, native macOS toolbar button for collapsing and expanding the sidebar.
///
/// The AppKit window owns the native traffic lights; each host applies a small
/// layout offset to align this control with the system titlebar baseline.
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
            glyph
        }
        .buttonStyle(SidebarToolbarButtonStyle())
        .onHover { isHovering = $0 }
        .help(sidebarCollapsed ? "展开侧栏 (⌃⌘S)" : "收起侧栏 (⌃⌘S)")
    }

    /// A circular plate, matching the shape system toolbar controls use on macOS 26.
    /// A bare glyph on the sidebar reads as an icon; the plate makes it a control.
    @ViewBuilder
    private var glyph: some View {
        let icon = Image(systemName: "sidebar.leading")
            .font(.system(size: 13.5, weight: .medium))
            .foregroundColor(
                isHovering
                ? AppTheme.primaryText(for: colorScheme)
                // Toolbar glyphs in system apps read near-white even at rest; a
                // secondary grey here made the button look disabled next to the
                // vivid window buttons.
                : AppTheme.primaryText(for: colorScheme).opacity(0.82)
            )
            .frame(width: 28, height: 28)

        if #available(macOS 26.0, *) {
            // The platform's own glass, rather than a hand-mixed translucent fill —
            // it picks up the backdrop and the hover/press response for free.
            icon
                .glassEffect(.regular.interactive(), in: Circle())
                .contentShape(Circle())
        } else {
            icon
                .background(Circle().fill(plateFill))
                .overlay(Circle().strokeBorder(plateEdge, lineWidth: 0.5))
                .contentShape(Circle())
        }
    }

    /// Fallback plate for macOS before 26, where `glassEffect` does not exist.
    /// Slightly stronger than a hairline tint so it reads as a control on the
    /// sidebar's dark material.
    private var plateFill: Color {
        if colorScheme == .light {
            return Color.black.opacity(isHovering ? 0.10 : 0.06)
        }
        return Color.white.opacity(isHovering ? 0.18 : 0.11)
    }

    private var plateEdge: Color {
        if colorScheme == .light {
            return Color.black.opacity(isHovering ? 0.12 : 0.07)
        }
        return Color.white.opacity(isHovering ? 0.20 : 0.13)
    }
}

struct SidebarToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
