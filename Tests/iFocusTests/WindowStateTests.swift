import XCTest
import AppKit
@testable import iFocus

final class WindowStateTests: XCTestCase {
    func testWindowStateModelTracksFullscreenNotifications() {
        let model = WindowStateModel.shared

        let dummyMainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        dummyMainWindow.title = "iFocus"

        NotificationCenter.default.post(
            name: NSWindow.didEnterFullScreenNotification,
            object: dummyMainWindow
        )
        XCTAssertTrue(model.isFullScreen)
        XCTAssertFalse(model.isTransitioningFullScreen)

        NotificationCenter.default.post(
            name: NSWindow.didExitFullScreenNotification,
            object: dummyMainWindow
        )
        XCTAssertFalse(model.isFullScreen)
        XCTAssertFalse(model.isTransitioningFullScreen)
    }

    func testWindowStateModelTracksTransitionNotifications() {
        let model = WindowStateModel.shared
        let dummyMainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        dummyMainWindow.title = "iFocus"

        NotificationCenter.default.post(
            name: NSWindow.willEnterFullScreenNotification,
            object: dummyMainWindow
        )
        XCTAssertTrue(model.isFullScreen)
        XCTAssertTrue(model.isTransitioningFullScreen)

        NotificationCenter.default.post(
            name: NSWindow.didEnterFullScreenNotification,
            object: dummyMainWindow
        )
        XCTAssertTrue(model.isFullScreen)
        XCTAssertFalse(model.isTransitioningFullScreen)

        NotificationCenter.default.post(
            name: NSWindow.willExitFullScreenNotification,
            object: dummyMainWindow
        )
        XCTAssertFalse(model.isFullScreen)
        XCTAssertTrue(model.isTransitioningFullScreen)

        NotificationCenter.default.post(
            name: NSWindow.didExitFullScreenNotification,
            object: dummyMainWindow
        )
        XCTAssertFalse(model.isFullScreen)
        XCTAssertFalse(model.isTransitioningFullScreen)
    }

    func testWindowStateModelIgnoresSettingsWindowFullscreen() {
        let model = WindowStateModel.shared
        model.isFullScreen = false

        let dummySettingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        dummySettingsWindow.title = "设置"

        NotificationCenter.default.post(
            name: NSWindow.didEnterFullScreenNotification,
            object: dummySettingsWindow
        )
        XCTAssertFalse(model.isFullScreen)
    }

    func testSidebarCollapsedStateSync() {
        let model = WindowStateModel.shared
        let initial = model.isSidebarCollapsed

        WindowLayoutStore.isSidebarCollapsed = !initial
        model.isSidebarCollapsed = !initial
        XCTAssertEqual(model.isSidebarCollapsed, !initial)
        XCTAssertEqual(WindowLayoutStore.isSidebarCollapsed, !initial)

        // Restore
        WindowLayoutStore.isSidebarCollapsed = initial
        model.isSidebarCollapsed = initial
    }

    func testAppNavigationToggleSidebarNotification() {
        let exp = expectation(description: "Toggle sidebar notification received")
        let sub = NotificationCenter.default.addObserver(
            forName: AppNavigation.toggleSidebar,
            object: nil,
            queue: .main
        ) { _ in
            exp.fulfill()
        }

        NotificationCenter.default.post(name: AppNavigation.toggleSidebar, object: nil)
        wait(for: [exp], timeout: 1.0)
        NotificationCenter.default.removeObserver(sub)
    }

    func testAppThemeTrafficLightLeadingConstant() {
        XCTAssertEqual(AppTheme.trafficLightLeading, 18)
        XCTAssertEqual(AppTheme.topHeaderHeight, 48)
        XCTAssertEqual(AppTheme.titlebarControlOffset, 4)
    }

    func testViewMenuSanitizerRemovesDuplicateItems() {
        let menu = NSMenu(title: "显示")
        let keepItem1 = NSMenuItem(title: "展开侧栏", action: nil, keyEquivalent: "s")
        let keepItem2 = NSMenuItem(title: "进入全屏", action: nil, keyEquivalent: "f")
        let duplicate1 = NSMenuItem(title: "进入全屏幕", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        let duplicate2 = NSMenuItem(title: "退出全屏幕", action: nil, keyEquivalent: "f")
        let duplicate3 = NSMenuItem(title: "Enter Full Screen", action: nil, keyEquivalent: "f")

        menu.addItem(keepItem1)
        menu.addItem(keepItem2)
        menu.addItem(duplicate1)
        menu.addItem(duplicate2)
        menu.addItem(duplicate3)

        XCTAssertEqual(menu.items.count, 5)
        ViewMenuSanitizer.shared.sanitize(menu)

        XCTAssertEqual(menu.items.count, 2)
        XCTAssertEqual(menu.items[0].title, "展开侧栏")
        XCTAssertEqual(menu.items[1].title, "进入全屏")
    }
}
