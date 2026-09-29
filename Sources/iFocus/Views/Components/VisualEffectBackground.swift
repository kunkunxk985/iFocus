import SwiftUI
import AppKit

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active
    var isEmphasized: Bool = false

    init(
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active,
        isEmphasized: Bool = false
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
        self.isEmphasized = isEmphasized
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = isEmphasized
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = isEmphasized
    }
}

extension VisualEffectBackground {
    static var sidebar: VisualEffectBackground {
        VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
    }

    static var hudWindow: VisualEffectBackground {
        VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
    }

    static var popover: VisualEffectBackground {
        VisualEffectBackground(material: .popover, blendingMode: .withinWindow)
    }

    static var underWindowBackground: VisualEffectBackground {
        VisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow)
    }

    static var titlebar: VisualEffectBackground {
        VisualEffectBackground(material: .titlebar, blendingMode: .withinWindow)
    }

    static var selection: VisualEffectBackground {
        VisualEffectBackground(material: .selection, blendingMode: .withinWindow)
    }

    static var headerView: VisualEffectBackground {
        VisualEffectBackground(material: .headerView, blendingMode: .withinWindow)
    }

    static var sheet: VisualEffectBackground {
        VisualEffectBackground(material: .sheet, blendingMode: .withinWindow)
    }

    static var menu: VisualEffectBackground {
        VisualEffectBackground(material: .menu, blendingMode: .withinWindow)
    }
}

extension View {
    /// Apply an authentic macOS NSVisualEffectView blur behind the view.
    func visualEffect(
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active,
        isEmphasized: Bool = false
    ) -> some View {
        background(
            VisualEffectBackground(
                material: material,
                blendingMode: blendingMode,
                state: state,
                isEmphasized: isEmphasized
            )
        )
    }
}


struct CircularVisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active
    /// Emphasized material reads as solid. The sidebar toggle stays glassy.
    var emphasized: Bool = false

    func makeNSView(context: Context) -> CircularEffectView {
        let view = CircularEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = emphasized
        return view
    }

    func updateNSView(_ view: CircularEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = emphasized
    }
}

/// Sidebar-toggle glass. Corner radius is applied in `layout` so the first
/// frame is already a circle, not a square that clips later.
final class CircularEffectView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = min(bounds.width, bounds.height) / 2
    }
}

// MARK: - Soft / hidden scrollbars

/// Hides the chunky macOS legacy scroller track. Scrolling still works with
/// trackpad / mouse wheel; no permanent gutter.
struct SoftScrollChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollIndicators(.hidden)
            .background(ScrollChromeHider())
    }
}

extension View {
    /// Prefer invisible scroll chrome (no permanent scrollbar gutter).
    func softScroll() -> some View {
        modifier(SoftScrollChrome())
    }
}

/// Walks up to the enclosing `NSScrollView` and disables permanent scrollers.
private struct ScrollChromeHider: NSViewRepresentable {
    func makeNSView(context: Context) -> ScrollChromeProbeView {
        ScrollChromeProbeView()
    }
    
    func updateNSView(_ nsView: ScrollChromeProbeView, context: Context) {
        nsView.apply()
    }
}

private final class ScrollChromeProbeView: NSView {
    override var isHidden: Bool {
        get { super.isHidden }
        set { super.isHidden = false } // stay in hierarchy for probing
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        apply()
        DispatchQueue.main.async { [weak self] in self?.apply() }
    }
    
    override func layout() {
        super.layout()
        apply()
    }
    
    func apply() {
        var node: NSView? = self
        while let current = node {
            if let scroll = current as? NSScrollView {
                scroll.scrollerStyle = .overlay
                scroll.autohidesScrollers = true
                scroll.hasVerticalScroller = false
                scroll.hasHorizontalScroller = false
                break
            }
            node = current.superview
        }
    }
    
    override var intrinsicContentSize: NSSize { .zero }
}
