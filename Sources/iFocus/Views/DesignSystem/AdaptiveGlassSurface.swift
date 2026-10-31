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
        if cornerRadius == 0 {
            // Full-bleed sidebar: avoid 4-sided 3D glass bevels and thick borders;
            // use native sidebar vibrancy + a single razor-thin 0.5pt trailing hairline.
            content
                .background(
                    VisualEffectBackground(
                        material: fallbackMaterial,
                        blendingMode: .withinWindow
                    )
                )
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.primary.opacity(colorScheme == .light ? 0.07 : 0.11))
                        .frame(width: 0.5)
                }
        } else if #available(macOS 26.0, *) {
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
                    shape.strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.5)
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
