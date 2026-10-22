import AppKit

/// Puts the sidebar toggle in the window's real toolbar and lets AppKit draw it.
///
/// The standard `.toggleSidebar` item is not usable here: AppKit only enables it
/// when the window has a split-view sidebar (`NSSplitViewController`), and this
/// app's sidebar is a SwiftUI column. A bordered item carrying the same system
/// glyph renders identically — same glass plate, hover, and press — and stays
/// enabled because its target is ours.
@MainActor
final class SidebarToolbar: NSObject, NSToolbarDelegate {
    static let shared = SidebarToolbar()

    private static let toolbarIdentifier = NSToolbar.Identifier("iFocusMainToolbar")
    private static let toggleIdentifier = NSToolbarItem.Identifier("iFocusSidebarToggle")

    /// Idempotent: repeated calls leave the installed toolbar alone.
    func install(on window: NSWindow) {
        guard window.toolbar?.identifier != Self.toolbarIdentifier else {
            // Fullscreen exit rebuilds the titlebar too; reassert even when the toolbar survives.
            WindowChrome.reassertTransparentTitlebar(in: window)
            return
        }
        let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        // Assigning the toolbar rebuilds the titlebar and can drop the transparent flag;
        // restore it now and once after the new titlebar settles, or first launch keeps an
        // opaque white band over the sidebar until the next key change.
        WindowChrome.reassertTransparentTitlebar(in: window)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.toggleIdentifier]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.toggleIdentifier, .flexibleSpace]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard itemIdentifier == Self.toggleIdentifier else {
            return NSToolbarItem(itemIdentifier: itemIdentifier)
        }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "侧栏"
        item.paletteLabel = "侧栏"
        item.toolTip = "切换侧栏 (⌃⌘S)"
        // The system toggle's glyph on this OS; older systems fall back to the
        // name the symbol shipped under before macOS 14.
        item.image = NSImage(systemSymbolName: "sidebar.leading", accessibilityDescription: "切换侧栏")
            ?? NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "切换侧栏")
        item.isBordered = true
        item.target = self
        item.action = #selector(toggleSidebar(_:))
        return item
    }

    @objc private func toggleSidebar(_ sender: Any?) {
        NotificationCenter.default.post(name: AppNavigation.toggleSidebar, object: nil)
    }
}
