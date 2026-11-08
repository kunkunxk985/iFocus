import SwiftUI
import AppKit

// MARK: - Floating Card Surface Modifier

/// Shared visual surface modifier for Things 3 style floating modal sheets and cards.
///
/// Features:
/// 1. Base material: `.ultraThinMaterial` continuous squircle for native desktop translucency.
/// 2. Adaptive tint: `AppTheme.cardBackground` (light: 0.90, dark: 0.70) for depth and calm contrast.
/// 3. Double-stroke borders:
///    - Outer boundary hairline: `AppTheme.separatorLow` (0.5pt stroke border).
///    - Inner specular highlight: `AppTheme.cardInnerHighlight` (0.75pt stroke border).
/// 4. Popover elevation shadow: `.multiLayerShadow(elevation: .popover, colorScheme: colorScheme)`.
struct FloatingCardSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 18) {
        self.cornerRadius = cornerRadius
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var tintOpacity: Double {
        colorScheme == .light ? 0.90 : 0.70
    }

    func body(content: Content) -> some View {
        content
            .background(
                shape
                    .fill(AppTheme.cardBackground(for: colorScheme).opacity(tintOpacity))
            )
            .background(
                .ultraThinMaterial,
                in: shape
            )
            .overlay(
                shape
                    .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.5)
            )
            .overlay(
                shape
                    .strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 0.75)
            )
            .clipShape(shape)
            .multiLayerShadow(elevation: .popover, colorScheme: colorScheme)
    }
}

extension View {
    /// Applies the shared Things 3 style floating modal card surface.
    ///
    /// - Parameter cornerRadius: Continuous squircle corner radius (default: 18).
    /// - Returns: View styled with ultra-thin material, adaptive tint, inner specular highlight,
    ///   outer hairline separator, and popover elevation shadow.
    func floatingCardSurface(cornerRadius: CGFloat = 18) -> some View {
        modifier(FloatingCardSurfaceModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Reusable Floating Modal Components

/// Top-right circular close button for floating modal cards.
///
/// Features a subtle circular hover background, 10pt bold `xmark` symbol,
/// tactile feedback on press, and accessible labeling.
struct FloatingModalCloseButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    var action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button {
            AppHaptics.buttonClick()
            action()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(
                            isHovering
                            ? Color.primary.opacity(colorScheme == .light ? 0.08 : 0.15)
                            : Color.clear
                        )
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AppTheme.springInteractive) {
                isHovering = hovering
            }
        }
        .help("关闭 (Esc)")
        .accessibilityLabel("关闭")
    }
}

/// Bottom subtle keyboard shortcut hints for floating modal cards (e.g. `⌘↵ 保存 · Esc 取消`).
struct FloatingModalShortcutHint: View {
    @Environment(\.colorScheme) private var colorScheme
    var hint: String

    init(hint: String = "⌘↵ 保存 · Esc 取消") {
        self.hint = hint
    }

    var body: some View {
        Text(hint)
            .font(.system(size: 11, weight: .regular, design: .rounded))
            .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.65))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel("快捷键提示：\(hint)")
    }
}
