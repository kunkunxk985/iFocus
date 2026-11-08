import XCTest
import SwiftUI
@testable import iFocus

final class FloatingCardSurfaceTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "iFocus.FloatingCardSurfaceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testFloatingCardSurfaceModifierDefaults() {
        let modifier = FloatingCardSurfaceModifier()
        XCTAssertEqual(modifier.cornerRadius, 18)
    }

    func testFloatingCardSurfaceModifierCustomRadius() {
        let modifier = FloatingCardSurfaceModifier(cornerRadius: 24)
        XCTAssertEqual(modifier.cornerRadius, 24)
    }

    func testFloatingModalShortcutHintDefaults() {
        let hint = FloatingModalShortcutHint()
        XCTAssertEqual(hint.hint, "⌘↵ 保存 · Esc 取消")
    }

    func testFloatingModalShortcutHintCustomText() {
        let hint = FloatingModalShortcutHint(hint: "Custom Hint")
        XCTAssertEqual(hint.hint, "Custom Hint")
    }

    func testFloatingModalCloseButtonInitializesWithAction() {
        var clicked = false
        let button = FloatingModalCloseButton {
            clicked = true
        }
        button.action()
        XCTAssertTrue(clicked)
    }

    func testViewExtensionFloatingCardSurface() {
        let view = Text("Hello").floatingCardSurface(cornerRadius: 18)
        XCTAssertNotNil(view)
    }

    func testUncommittedAvatarChangesRollbackOnCancel() {
        let store = SettingsStore(defaults: defaults, applyAppearance: false)
        store.avatarColorIndex = 1
        let originalColor = store.avatarColorIndex
        let originalPath = store.avatarPath

        // User interacts with swatches
        store.avatarColorIndex = 4
        XCTAssertEqual(store.avatarColorIndex, 4)

        // Simulate cancel / backdrop rollback
        store.avatarColorIndex = originalColor
        store.avatarPath = originalPath
        XCTAssertEqual(store.avatarColorIndex, 1)
        XCTAssertEqual(store.avatarPath, nil)
    }

    func testEditProfileSheetStructureCompilesAndInstantiates() {
        let store = SettingsStore(defaults: defaults, applyAppearance: false)
        var tempUsername = "Tester"
        var isPresented = true

        let bindingUsername = Binding(get: { tempUsername }, set: { tempUsername = $0 })
        let bindingPresented = Binding(get: { isPresented }, set: { isPresented = $0 })

        let sheet = EditProfileSheet(
            tempUsername: bindingUsername,
            isPresented: bindingPresented
        )
        .environmentObject(store)

        XCTAssertNotNil(sheet)
    }
}
