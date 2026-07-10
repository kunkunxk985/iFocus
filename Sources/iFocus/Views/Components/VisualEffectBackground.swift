import SwiftUI
import AppKit

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
    }
}

struct CircularVisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = true
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.layer?.cornerRadius = min(view.bounds.width, view.bounds.height) / 2
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
