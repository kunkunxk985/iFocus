import SwiftUI

enum TimerLayoutMath {
    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * min(1, max(0, t))
    }

    static func ringSize(
        layout: WindowLayoutMetrics,
        stageWidth: CGFloat,
        stageHeight: CGFloat,
        immersive: Bool
    ) -> CGFloat {
        let preferred = layout.ringPreferred * (immersive ? 1.12 : 1)
        let reserved =
            layout.stageTopChrome
            + layout.sectionSpacing
            + (immersive ? 40 : lerp(88, 120, layout.eased))
            + (immersive ? 0 : layout.sectionSpacing)
            + (immersive ? 0 : lerp(56, 78, layout.eased))
            + layout.sectionSpacing * 0.7
            + (immersive ? 0 : lerp(48, 68, layout.eased))
            + layout.sectionSpacing * 0.7
            + layout.controlMainSize + (layout.showControlLabels ? 22 : 4)
            + (layout.showSessionHint && !immersive ? 28 : 12)
            + layout.sectionSpacing
        let budget = max(160, stageHeight - reserved)
        let widthCap = stageWidth * (immersive ? 0.55 : layout.ringMaxFractionOfWidth)
        return min(preferred, budget, widthCap)
    }
}
