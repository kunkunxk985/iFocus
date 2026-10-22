import SwiftUI
import AppKit

/// Uses the system Liquid Glass on macOS 26 and native vibrancy on older releases.
/// Keep this for navigation / window chrome surfaces rather than ordinary content cards.
struct AdaptiveGlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    let fallbackMaterial: NSVisualEffectView.Material

    @Environment(\.colorScheme) private var colorScheme

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(
                    VisualEffectBackground(
                        material: fallbackMaterial,
                        blendingMode: .withinWindow
                    )
                )
                .clipShape(shape)
                .overlay(
                    shape.strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.8)
                )
        }
    }
}

extension View {
    func adaptiveGlass(
        cornerRadius: CGFloat,
        fallbackMaterial: NSVisualEffectView.Material = .sidebar
    ) -> some View {
        modifier(
            AdaptiveGlassSurface(
                cornerRadius: cornerRadius,
                fallbackMaterial: fallbackMaterial
            )
        )
    }
}
