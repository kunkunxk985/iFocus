import AppKit
import Foundation

/// Persist main-window frame and sidebar collapsed state (local only).
enum WindowLayoutStore {
    private static let frameKey = "mainWindowFrame"
    private static let sidebarCollapsedKey = "sidebarCollapsed"
    
    static var isSidebarCollapsed: Bool {
        get { UserDefaults.standard.bool(forKey: sidebarCollapsedKey) }
        set { UserDefaults.standard.set(newValue, forKey: sidebarCollapsedKey) }
    }
    
    static func saveMainWindowFrame(_ frame: NSRect) {
        guard frame.width >= 800, frame.height >= 560 else { return }
        let dict: [String: Double] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "w": frame.size.width,
            "h": frame.size.height
        ]
        UserDefaults.standard.set(dict, forKey: frameKey)
    }
    
    static func savedMainWindowFrame() -> NSRect? {
        guard let dict = UserDefaults.standard.dictionary(forKey: frameKey) as? [String: Double],
              let w = dict["w"], let h = dict["h"],
              let x = dict["x"], let y = dict["y"],
              w >= 800, h >= 560 else { return nil }
        return NSRect(x: x, y: y, width: w, height: h)
    }
    
    /// Apply saved frame to the primary app window if present.
    static func restoreMainWindowIfPossible() {
        guard let frame = savedMainWindowFrame() else { return }
        DispatchQueue.main.async {
            let windows = NSApplication.shared.windows.filter {
                $0.title == "iFocus" || $0.canBecomeKey
            }
            guard let window = windows.first(where: { $0.title != "设置" }) ?? windows.first else { return }
            // Constrain to visible screen if possible.
            if let screen = window.screen ?? NSScreen.main {
                let visible = screen.visibleFrame
                var f = frame
                if f.maxX < visible.minX + 40 { f.origin.x = visible.minX + 40 }
                if f.maxY < visible.minY + 40 { f.origin.y = visible.minY + 40 }
                if f.minX > visible.maxX - 40 { f.origin.x = visible.maxX - f.width - 40 }
                if f.minY > visible.maxY - 40 { f.origin.y = visible.maxY - f.height - 40 }
                window.setFrame(f, display: true)
            } else {
                window.setFrame(frame, display: true)
            }
        }
    }
}
