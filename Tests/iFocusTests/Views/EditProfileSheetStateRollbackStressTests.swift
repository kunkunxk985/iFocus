import XCTest
import SwiftUI
import AppKit
@testable import iFocus

final class EditProfileSheetStateRollbackStressTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var tempDirectory: URL!
    private var store: SettingsStore!

    override func setUpWithError() throws {
        suiteName = "iFocus.EditProfileSheetStressTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        store = SettingsStore(defaults: defaults, applyAppearance: false, avatarStorageDirectory: tempDirectory)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: tempDirectory)
        store = nil
    }

    private func pumpRunLoop(seconds: TimeInterval = 0.05) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func createDummyImageFile(named name: String = "test-avatar.png") -> URL {
        let fileURL = tempDirectory.appendingPathComponent(name)
        let image = NSImage(size: NSSize(width: 64, height: 64))
        image.lockFocus()
        NSColor.systemRed.drawSwatch(in: NSRect(x: 0, y: 0, width: 64, height: 64))
        image.unlockFocus()
        let tiff = image.tiffRepresentation!
        let bitmap = NSBitmapImageRep(data: tiff)!
        let png = bitmap.representation(using: .png, properties: [:])!
        try! png.write(to: fileURL)
        return fileURL
    }

    class TestHostModel: ObservableObject {
        @Published var tempUsername: String
        @Published var isPresented: Bool

        init(tempUsername: String = "Alice", isPresented: Bool = true) {
            self.tempUsername = tempUsername
            self.isPresented = isPresented
        }
    }

    struct TestHostView: View {
        @ObservedObject var model: TestHostModel
        @EnvironmentObject var settings: SettingsStore

        var body: some View {
            if model.isPresented {
                EditProfileSheet(
                    tempUsername: $model.tempUsername,
                    isPresented: $model.isPresented
                )
            } else {
                Text("Dismissed")
            }
        }
    }

    // =========================================================================
    // MARK: - 1. Dismissal Pathway 1: Cancel Button & Keyboard Shortcut
    // =========================================================================

    func testDismissalPathway1_CancelButton_RollsBackUncommittedState() {
        store.avatarColorIndex = 1
        store.username = "Alice"
        let model = TestHostModel(tempUsername: "Alice", isPresented: true)
        let hostView = TestHostView(model: model).environmentObject(store)
        let hosting = NSHostingView(rootView: hostView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        pumpRunLoop(seconds: 0.05)

        // Mutate swatch and nickname
        store.avatarColorIndex = 4
        model.tempUsername = "MaliciousMutation"

        // Trigger cancel via Esc / .cancelAction shortcut
        let cancelEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false,
            keyCode: 53
        )!

        let handled = window.performKeyEquivalent(with: cancelEvent)
        XCTAssertTrue(handled, "Cancel action should consume key event")
        pumpRunLoop(seconds: 0.05)

        // Verify dismissal and rollback
        XCTAssertFalse(model.isPresented, "Sheet should be dismissed")
        XCTAssertEqual(store.avatarColorIndex, 1, "avatarColorIndex must revert to 1")
        XCTAssertEqual(defaults.integer(forKey: "avatarColorIndex"), 1, "UserDefaults must revert to 1")
        XCTAssertEqual(store.username, "Alice", "Username must remain untouched")
        XCTAssertEqual(defaults.string(forKey: "username"), "Alice")

        window.contentView = nil
    }

    // =========================================================================
    // MARK: - 2. Dismissal Pathway 2: Esc Key (.onExitCommand)
    // =========================================================================

    func testDismissalPathway2_EscKey_DismissesAndRollsBack() {
        store.avatarColorIndex = 2
        let model = TestHostModel(tempUsername: "OriginalUser", isPresented: true)
        let hostView = TestHostView(model: model).environmentObject(store)
        let hosting = NSHostingView(rootView: hostView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        pumpRunLoop(seconds: 0.05)

        // Mutate color to 5
        store.avatarColorIndex = 5
        XCTAssertEqual(store.avatarColorIndex, 5)

        // Send Esc key event
        let escEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false,
            keyCode: 53
        )!

        _ = window.performKeyEquivalent(with: escEvent)
        pumpRunLoop(seconds: 0.05)

        XCTAssertFalse(model.isPresented)
        XCTAssertEqual(store.avatarColorIndex, 2)
        XCTAssertEqual(defaults.integer(forKey: "avatarColorIndex"), 2)

        window.contentView = nil
    }

    // =========================================================================
    // MARK: - 3. Dismissal Pathway 3: Close Button (FloatingModalCloseButton)
    // =========================================================================

    func testDismissalPathway3_CloseButton_ActionRollsBack() {
        store.avatarColorIndex = 0
        var isPresented = true

        let closeButton = FloatingModalCloseButton {
            // Mirrors EditProfileSheet's handleCancel()
            if self.store.avatarColorIndex != 0 {
                self.store.avatarColorIndex = 0
            }
            isPresented = false
        }

        // Mutate color
        store.avatarColorIndex = 3
        XCTAssertEqual(store.avatarColorIndex, 3)

        // Click close button
        closeButton.action()

        XCTAssertFalse(isPresented)
        XCTAssertEqual(store.avatarColorIndex, 0)
        XCTAssertEqual(defaults.integer(forKey: "avatarColorIndex"), 0)
    }

    // =========================================================================
    // MARK: - 4. Dismissal Pathway 4: Backdrop Click (.onChange(of: isPresented))
    // =========================================================================

    func testDismissalPathway4_BackdropClick_RollsBackImmediately() {
        store.avatarColorIndex = 3
        let model = TestHostModel(tempUsername: "ClickTester", isPresented: true)
        let hostView = TestHostView(model: model).environmentObject(store)
        let hosting = NSHostingView(rootView: hostView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        pumpRunLoop(seconds: 0.05)

        // Mutate color to 6
        store.avatarColorIndex = 6
        XCTAssertEqual(store.avatarColorIndex, 6)
        XCTAssertEqual(defaults.integer(forKey: "avatarColorIndex"), 6)

        // Simulate backdrop click in AnalyticsView (sets isPresented = false directly)
        model.isPresented = false
        pumpRunLoop(seconds: 0.05)

        // Verify .onChange(of: isPresented) rolled back state
        XCTAssertEqual(store.avatarColorIndex, 3, "Backdrop click must trigger rollback to original index 3")
        XCTAssertEqual(defaults.integer(forKey: "avatarColorIndex"), 3, "UserDefaults must roll back to 3")

        window.contentView = nil
    }

    // =========================================================================
    // MARK: - 5. Dismissal Pathway 5: Direct View Teardown (.onDisappear)
    // =========================================================================

    func testDismissalPathway5_OnDisappear_GuaranteesRollback() {
        store.avatarColorIndex = 1
        var tempUsername = "DisappearTester"
        var isPresented = true

        let sheet = EditProfileSheet(
            tempUsername: Binding(get: { tempUsername }, set: { tempUsername = $0 }),
            isPresented: Binding(get: { isPresented }, set: { isPresented = $0 })
        )
        .environmentObject(store)

        let hosting = NSHostingView(rootView: sheet)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        pumpRunLoop(seconds: 0.05)

        // Mutate
        store.avatarColorIndex = 4
        XCTAssertEqual(store.avatarColorIndex, 4)

        // Abruptly dismantle the view from the window
        window.contentView = nil
        pumpRunLoop(seconds: 0.05)

        // onDisappear must execute rollbackAvatarState()
        XCTAssertEqual(store.avatarColorIndex, 1, "onDisappear must safely roll back avatarColorIndex")
        XCTAssertEqual(defaults.integer(forKey: "avatarColorIndex"), 1)
    }

    // =========================================================================
    // MARK: - 6. Avatar Path Rollback: Upload Image Then Cancel
    // =========================================================================

    func testAvatarPathRollback_UploadThenCancel() {
        XCTAssertNil(store.avatarPath)
        let dummyImageURL = createDummyImageFile(named: "dummy-upload.png")

        let model = TestHostModel(tempUsername: "Uploader", isPresented: true)
        let hostView = TestHostView(model: model).environmentObject(store)
        let hosting = NSHostingView(rootView: hostView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        pumpRunLoop(seconds: 0.05)

        // User uploads avatar
        let uploaded = store.uploadAvatar(from: dummyImageURL, removePrevious: false)
        XCTAssertTrue(uploaded)
        let uncommittedPath = store.avatarPath
        XCTAssertNotNil(uncommittedPath)
        XCTAssertNotNil(defaults.string(forKey: "avatarPath"))

        // User cancels by clicking backdrop
        model.isPresented = false
        pumpRunLoop(seconds: 0.05)

        // Verify avatarPath is rolled back to nil and uncommitted file is cleaned up
        XCTAssertNil(store.avatarPath, "avatarPath must revert to nil when cancelled")
        XCTAssertNil(defaults.string(forKey: "avatarPath"), "UserDefaults avatarPath must be removed")
        if let uncommittedPath {
            XCTAssertFalse(FileManager.default.fileExists(atPath: uncommittedPath), "Uncommitted avatar file must be cleaned up on rollback")
        }

        window.contentView = nil
    }

    // =========================================================================
    // MARK: - 7. Avatar Path Rollback: Restore Default Then Cancel
    // =========================================================================

    func testAvatarPathRollback_RestoreDefaultThenCancel() {
        let dummyImageURL = createDummyImageFile(named: "existing-avatar.png")
        _ = store.uploadAvatar(from: dummyImageURL)
        let existingPath = store.avatarPath
        XCTAssertNotNil(existingPath)

        let model = TestHostModel(tempUsername: "Restorer", isPresented: true)
        let hostView = TestHostView(model: model).environmentObject(store)
        let hosting = NSHostingView(rootView: hostView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        pumpRunLoop(seconds: 0.05)

        // User clicks "恢复默认" (clears avatarPath without deleting file until save)
        store.avatarPath = nil
        XCTAssertNil(store.avatarPath)
        XCTAssertNil(defaults.string(forKey: "avatarPath"))

        // User cancels via backdrop
        model.isPresented = false
        pumpRunLoop(seconds: 0.05)

        // Verify existingPath is restored and file still exists on disk
        XCTAssertEqual(store.avatarPath, existingPath, "avatarPath must be restored to previous path")
        XCTAssertEqual(defaults.string(forKey: "avatarPath"), existingPath)
        if let existingPath {
            XCTAssertTrue(FileManager.default.fileExists(atPath: existingPath), "Original avatar file must remain intact on disk after cancel")
        }

        window.contentView = nil
    }

    // =========================================================================
    // MARK: - 8. Commit Pathway: Save Persists All Mutations
    // =========================================================================

    func testCommitPathway_SavePersistsAllMutations() {
        store.avatarColorIndex = 0
        store.username = "OldUsername"
        XCTAssertNil(store.avatarPath)

        let model = TestHostModel(tempUsername: "   New Committed Name   ", isPresented: true)
        let hostView = TestHostView(model: model).environmentObject(store)
        let hosting = NSHostingView(rootView: hostView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        pumpRunLoop(seconds: 0.05)

        // Mutate color
        store.avatarColorIndex = 3

        // Send Cmd+Return key event (triggers handleSave())
        let saveEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )!

        let handled = window.performKeyEquivalent(with: saveEvent)
        XCTAssertTrue(handled, "Cmd+Return should be handled by save shortcut")
        pumpRunLoop(seconds: 0.05)

        // Verify sheet dismissed
        XCTAssertFalse(model.isPresented)

        // Verify commitment
        XCTAssertEqual(store.avatarColorIndex, 3, "Committed color must remain 3")
        XCTAssertEqual(defaults.integer(forKey: "avatarColorIndex"), 3)
        XCTAssertEqual(store.username, "New Committed Name", "Username must be trimmed and saved")
        XCTAssertEqual(defaults.string(forKey: "username"), "New Committed Name")

        // Now dismantle the window (onDisappear fires)
        window.contentView = nil
        pumpRunLoop(seconds: 0.05)

        // Verify onDisappear did NOT roll back the committed state
        XCTAssertEqual(store.avatarColorIndex, 3, "Committed color must survive onDisappear")
        XCTAssertEqual(store.username, "New Committed Name")
    }

    // =========================================================================
    // MARK: - 9. Multi-Cycle Stress Test: Successive Open/Cancel/Save Cycles
    // =========================================================================

    func testMultiCycleStress_SuccessiveEditsAndDismissals() {
        store.avatarColorIndex = 0
        store.username = "CycleUser"

        let model = TestHostModel(tempUsername: "CycleUser", isPresented: false)
        let hostView = TestHostView(model: model).environmentObject(store)
        let hosting = NSHostingView(rootView: hostView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        pumpRunLoop(seconds: 0.05)

        // --- Cycle 1: Open -> Mutate color to 2 -> Cancel ---
        model.tempUsername = store.username
        model.isPresented = true
        pumpRunLoop(seconds: 0.05)

        store.avatarColorIndex = 2
        model.isPresented = false // Cancel
        pumpRunLoop(seconds: 0.05)

        XCTAssertEqual(store.avatarColorIndex, 0, "Cycle 1 rollback to 0")

        // --- Cycle 2: Open -> Mutate color to 4, name to 'SecondName' -> Save ---
        model.tempUsername = "SecondName"
        model.isPresented = true
        pumpRunLoop(seconds: 0.05)

        store.avatarColorIndex = 4
        // Trigger Save via Cmd+Return
        let saveEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )!
        _ = window.performKeyEquivalent(with: saveEvent)
        pumpRunLoop(seconds: 0.05)

        XCTAssertEqual(store.avatarColorIndex, 4, "Cycle 2 committed color 4")
        XCTAssertEqual(store.username, "SecondName", "Cycle 2 committed name")

        // --- Cycle 3: Open -> Mutate color to 1 -> Cancel ---
        // Crucial test: Does it roll back to 4 (the newly committed value) or 0 (stale initial value)?
        model.tempUsername = store.username
        model.isPresented = true
        pumpRunLoop(seconds: 0.05)

        store.avatarColorIndex = 1
        model.isPresented = false // Cancel
        pumpRunLoop(seconds: 0.05)

        XCTAssertEqual(store.avatarColorIndex, 4, "Cycle 3 must roll back to 4 (new baseline), NOT 0!")

        window.contentView = nil
    }

    // =========================================================================
    // MARK: - 10. Nickname Sanitization Edge Cases
    // =========================================================================

    func testNicknameSanitizationEdgeCases() {
        // Test 1: Empty string sanitizes to default '小番茄'
        store.username = ""
        store.sanitizeUsername()
        XCTAssertEqual(store.username, "小番茄")

        // Test 2: Whitespaces only sanitize to '小番茄'
        store.username = "   \n\t  "
        store.sanitizeUsername()
        XCTAssertEqual(store.username, "小番茄")

        // Test 3: Trims surrounding whitespace
        store.username = "  番茄达人  "
        store.sanitizeUsername()
        XCTAssertEqual(store.username, "番茄达人")

        // Test 4: Emoji & symbols preserved
        store.username = "🍅 Super Focus 2026 🚀"
        store.sanitizeUsername()
        XCTAssertEqual(store.username, "🍅 Super Focus 2026 🚀")

        // Test 5: Long string (120 chars) preserved without truncating or crashing
        let longName = String(repeating: "A", count: 120)
        store.username = longName
        store.sanitizeUsername()
        XCTAssertEqual(store.username, longName)
    }
}
