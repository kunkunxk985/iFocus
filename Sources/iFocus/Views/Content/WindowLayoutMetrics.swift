import SwiftUI

/// Continuous window-aware layout — not a binary compact/comfort switch.
/// Resize the window and spacing, type, ring, and chrome fluidly reflow.
struct WindowLayoutMetrics: Equatable {
    let width: CGFloat
    let height: CGFloat
    /// Multiplies paddings that already honor user density preference.
    let densityScale: CGFloat

    /// Design reference (comfortable open size).
    static let reference = CGSize(width: 1280, height: 860)
    /// Smallest supported main window.
    static let minimum = CGSize(width: 1024, height: 700)
    /// Default open size — slightly taller so timer chrome never clips.
    static let defaultSize = CGSize(width: 1280, height: 860)

    init(width: CGFloat, height: CGFloat, densityScale: CGFloat = 1) {
        self.width = max(1, width)
        self.height = max(1, height)
        self.densityScale = densityScale
    }

    // MARK: - Fluid 0…1+ (0 ≈ min window, 1 ≈ reference, >1 roomy)

    /// Height progress from min → reference (clamped 0…1.35).
    var heightFluid: CGFloat {
        let minH = Self.minimum.height
        let refH = Self.reference.height
        guard refH > minH else { return 1 }
        return max(0, min(1.35, (height - minH) / (refH - minH)))
    }

    /// Width progress from min → reference.
    var widthFluid: CGFloat {
        let minW = Self.minimum.width
        let refW = Self.reference.width
        guard refW > minW else { return 1 }
        return max(0, min(1.35, (width - minW) / (refW - minW)))
    }

    /// Combined stage fluid (height weighted — vertical stack is the bottleneck).
    var fluid: CGFloat {
        heightFluid * 0.65 + widthFluid * 0.35
    }

    /// Smoothstep for nicer resize feel (avoids linear jumps near min).
    var eased: CGFloat {
        let t = min(1, max(0, fluid))
        return t * t * (3 - 2 * t)
    }

    // MARK: - Continuous tokens

    /// 0.88 at min → 1.0 at ref → ~1.12 when large.
    var scale: CGFloat {
        let base = 0.88 + eased * 0.12
        let roomy = max(0, fluid - 1) * 0.12
        return (base + roomy) * densityScale
    }

    /// Section vertical spacing (status ↔ ring ↔ controls).
    var sectionSpacing: CGFloat {
        lerp(10, 18, eased) * densityScale
    }

    var horizontalPadding: CGFloat {
        lerp(16, 32, eased) * densityScale
    }

    /// Space under traffic lights for timer stage top.
    var stageTopChrome: CGFloat {
        lerp(44, 56, eased)
    }

    // MARK: - Timer stage

    /// Target ring diameter before clamping to leftover budget.
    var ringPreferred: CGFloat {
        let base = lerp(188, 300, eased)
        let roomy = max(0, fluid - 1) * 40
        let immersiveBoost: CGFloat = 1 // caller multiplies if needed
        return (base + roomy) * immersiveBoost * densityScale
    }

    var ringMaxFractionOfWidth: CGFloat {
        lerp(0.42, 0.50, eased)
    }

    var controlMainSize: CGFloat {
        lerp(56, 76, eased) * densityScale
    }

    var controlSideSize: CGFloat {
        lerp(40, 52, eased) * densityScale
    }

    var controlSpacing: CGFloat {
        lerp(18, 32, eased) * densityScale
    }

    var modeChipVerticalPadding: CGFloat {
        lerp(7, 11, eased)
    }

    var modeChipFont: CGFloat {
        lerp(11.5, 13.5, eased)
    }

    var goalCardMaxWidth: CGFloat {
        lerp(320, 440, eased)
    }

    var taskBlockMaxWidth: CGFloat {
        lerp(360, 500, eased)
    }

    var modeSwitcherMaxWidth: CGFloat {
        lerp(320, 420, eased)
    }

    /// Labels under skip/reset — prefer icon-only for a quieter stage.
    var showControlLabels: Bool {
        height >= 820
    }

    /// Keyboard hint row under controls — only on tall stages.
    var showSessionHint: Bool {
        height >= 860
    }

    /// Reserved for legacy callers; long-break context is folded into the goal line.
    var showLongBreakRow: Bool {
        false
    }

    /// Slightly tighter goal padding at small heights.
    var goalCardPaddingV: CGFloat {
        lerp(8, 12, eased)
    }

    // MARK: - Shared pages (lists / analytics)

    var pageHorizontalPadding: CGFloat {
        lerp(24, 44, eased) * densityScale
    }

    var pageContentMaxWidth: CGFloat {
        lerp(720, 1100, eased)
    }

    var pageTitleSize: CGFloat {
        lerp(22, 28, eased) * densityScale
    }

    // MARK: - Helpers

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * min(1, max(0, t))
    }
}

// MARK: - Window geometry mirrors

/// Window geometry mirrors used by the app entry and Settings copy.
enum AppWindowMetrics {
    static let minimum = WindowLayoutMetrics.minimum
    static let defaultSize = WindowLayoutMetrics.defaultSize
}

// MARK: - Sidebar chrome

/// Sidebar width formula used by the content layout.
enum SidebarChrome {
    /// Expanded sidebar width for a given window width. Fluid: 208 → 252pt.
    static func expandedWidth(for windowWidth: CGFloat) -> CGFloat {
        let fluid = min(1, max(0, (windowWidth - WindowLayoutMetrics.minimum.width)
                               / max(1, WindowLayoutMetrics.reference.width - WindowLayoutMetrics.minimum.width)))
        return 208 + fluid * 44
    }
}

// MARK: - Environment

private struct WindowLayoutKey: EnvironmentKey {
    static let defaultValue = WindowLayoutMetrics(
        width: WindowLayoutMetrics.reference.width,
        height: WindowLayoutMetrics.reference.height
    )
}

extension EnvironmentValues {
    var windowLayout: WindowLayoutMetrics {
        get { self[WindowLayoutKey.self] }
        set { self[WindowLayoutKey.self] = newValue }
    }
}
