import AppKit
import Combine

/// Query shared by the toolbar's native search field and the SwiftUI sidebar.
@MainActor
final class SettingsSearchModel: ObservableObject {
    static let shared = SettingsSearchModel()

    @Published var query = ""

    func matchesRow(title: String, subtitle: String? = nil, keywords: String = "") -> Bool {
        let tokens = query.split(whereSeparator: \.isWhitespace)
        guard !tokens.isEmpty else { return false }
        let haystack = "\(title) \(subtitle ?? "") \(keywords)"
        return tokens.allSatisfy { haystack.localizedCaseInsensitiveContains(String($0)) }
    }
}

/// Gives the Settings window the same native 52pt titlebar band as the main window,
/// with the settings search field at its trailing edge.
@MainActor
final class SettingsWindowToolbar: NSObject, NSToolbarDelegate {
    static let shared = SettingsWindowToolbar()

    private static let toolbarIdentifier = NSToolbar.Identifier("iFocusSettingsToolbar")
    private static let searchIdentifier = NSToolbarItem.Identifier("iFocusSettingsSearch")

    private weak var searchField: NSSearchField?

    func install(on window: NSWindow) {
        guard window.toolbar?.identifier != Self.toolbarIdentifier else { return }
        SettingsSearchModel.shared.query = ""
        let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.searchIdentifier]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.searchIdentifier]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard itemIdentifier == Self.searchIdentifier else {
            return NSToolbarItem(itemIdentifier: itemIdentifier)
        }
        let item = NSSearchToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "搜索设置"
        item.preferredWidthForSearchField = 200
        let field = item.searchField
        field.placeholderString = "搜索设置"
        field.sendsSearchStringImmediately = true
        field.target = self
        field.action = #selector(searchTextChanged(_:))
        field.setAccessibilityLabel("搜索设置")
        searchField = field
        return item
    }

    /// Clears both the native field and the SwiftUI filter (used by the empty state).
    func clearSearchField() {
        searchField?.stringValue = ""
        SettingsSearchModel.shared.query = ""
    }

    /// Expands and focuses the search field; used by the app's Find command while
    /// the Settings window is key.
    func focusSearchField() {
        guard let searchField, let window = searchField.window else { return }
        window.makeFirstResponder(searchField)
    }

    @objc private func searchTextChanged(_ sender: NSSearchField) {
        SettingsSearchModel.shared.query = sender.stringValue
    }
}
