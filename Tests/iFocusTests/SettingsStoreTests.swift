import XCTest
import AppKit
@testable import iFocus

final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var avatarDirectory: URL!
    
    override func setUpWithError() throws {
        suiteName = "iFocus.SettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        avatarDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-AvatarTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: avatarDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try? FileManager.default.removeItem(at: avatarDirectory)
        avatarDirectory = nil
    }
    
    func testLoadsDefaultsWhenKeysAreMissing() {
        let store = SettingsStore(defaults: defaults, applyAppearance: false)
        
        XCTAssertEqual(store.workMinutes, 25)
        XCTAssertEqual(store.shortBreakMinutes, 5)
        XCTAssertEqual(store.longBreakMinutes, 15)
        XCTAssertEqual(store.dailyGoal, 8)
        XCTAssertTrue(store.soundEnabled)
        XCTAssertEqual(store.username, "小番茄")
        XCTAssertEqual(store.appearance, .system)
    }
    
    func testClampsPersistedTimerSettings() {
        defaults.set(0, forKey: "workMinutes")
        defaults.set(-5, forKey: "shortBreakMinutes")
        defaults.set(1, forKey: "longBreakMinutes")
        defaults.set(99, forKey: "dailyGoal")
        
        let store = SettingsStore(defaults: defaults, applyAppearance: false)
        
        XCTAssertEqual(store.workMinutes, 1)
        XCTAssertEqual(store.shortBreakMinutes, 1)
        XCTAssertEqual(store.longBreakMinutes, 5)
        XCTAssertEqual(store.dailyGoal, 20)
    }
    
    func testClampsValuesSetAtRuntimeAndPersistsClampedValue() {
        let store = SettingsStore(defaults: defaults, applyAppearance: false)
        
        store.workMinutes = 200
        store.shortBreakMinutes = -1
        store.longBreakMinutes = 2
        store.dailyGoal = 0
        
        XCTAssertEqual(store.workMinutes, 90)
        XCTAssertEqual(defaults.integer(forKey: "workMinutes"), 90)
        XCTAssertEqual(store.shortBreakMinutes, 1)
        XCTAssertEqual(defaults.integer(forKey: "shortBreakMinutes"), 1)
        XCTAssertEqual(store.longBreakMinutes, 5)
        XCTAssertEqual(defaults.integer(forKey: "longBreakMinutes"), 5)
        XCTAssertEqual(store.dailyGoal, 1)
        XCTAssertEqual(defaults.integer(forKey: "dailyGoal"), 1)
    }
    
    func testSanitizeUsernameUsesDefaultForBlankName() {
        let store = SettingsStore(defaults: defaults, applyAppearance: false)
        
        store.username = "   "
        store.sanitizeUsername()
        
        XCTAssertEqual(store.username, "小番茄")
        XCTAssertEqual(defaults.string(forKey: "username"), "小番茄")
    }

    func testImportSettingsJSONBridgesNSNumberFromJSONSerialization() throws {
        let store = SettingsStore(defaults: defaults, applyAppearance: false)
        store.workMinutes = 25
        store.dailyGoal = 8
        store.decorativeMotionEnabled = false
        store.analyticsShowRecent = false

        // Mimic real export → re-import through JSONSerialization (NSNumber boxing).
        let raw: [String: Any] = [
            "workMinutes": 40,
            "dailyGoal": 12,
            "decorativeMotionEnabled": true,
            "analyticsShowRecentCards": true,
            "username": "测试用户"
        ]
        let data = try JSONSerialization.data(withJSONObject: raw, options: [])
        try store.importSettingsJSON(data)

        XCTAssertEqual(store.workMinutes, 40)
        XCTAssertEqual(store.dailyGoal, 12)
        XCTAssertTrue(store.decorativeMotionEnabled)
        XCTAssertTrue(store.analyticsShowRecent)
        XCTAssertEqual(store.username, "测试用户")
    }

    func testExportImportSettingsRoundTrip() throws {
        let store = SettingsStore(defaults: defaults, applyAppearance: false)
        store.workMinutes = 33
        store.shortBreakMinutes = 7
        store.dailyGoal = 10
        store.smartLaunchLanding = false
        store.analyticsShowTimeline = true

        let data = try store.exportSettingsJSON()
        store.workMinutes = 25
        store.shortBreakMinutes = 5
        store.dailyGoal = 8
        store.smartLaunchLanding = true
        store.analyticsShowTimeline = false

        try store.importSettingsJSON(data)
        XCTAssertEqual(store.workMinutes, 33)
        XCTAssertEqual(store.shortBreakMinutes, 7)
        XCTAssertEqual(store.dailyGoal, 10)
        XCTAssertFalse(store.smartLaunchLanding)
        XCTAssertTrue(store.analyticsShowTimeline)
    }

    func testAnalyticsCardVisibilityQuietDefaultsAndFullPreset() {
        let store = SettingsStore(defaults: defaults, applyAppearance: false)

        // Quiet-tool defaults when keys missing
        XCTAssertTrue(store.isAnalyticsQuietDefault)
        XCTAssertTrue(store.anyAnalyticsCardEnabled)
        XCTAssertFalse(store.isAnalyticsFullLayout)

        store.enableAllAnalyticsCards()
        XCTAssertTrue(store.isAnalyticsFullLayout)
        XCTAssertTrue(store.analyticsShowRecent)
        XCTAssertTrue(store.analyticsShowTimeline)

        store.analyticsShowInsight = false
        XCTAssertFalse(store.isAnalyticsFullLayout)
        XCTAssertTrue(store.anyAnalyticsCardEnabled)

        store.resetAnalyticsCardVisibilityToQuietDefaults()
        XCTAssertTrue(store.isAnalyticsQuietDefault)
        XCTAssertFalse(store.analyticsShowRecent)
        XCTAssertEqual(defaults.bool(forKey: "analyticsShowRecentCards"), false)
    }

    func testUploadAvatarConvertsAndReloadsImage() throws {
        let sourceURL = avatarDirectory.appendingPathComponent("source.png")
        let image = NSImage(size: NSSize(width: 24, height: 24))
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSRect(x: 0, y: 0, width: 24, height: 24).fill()
        image.unlockFocus()

        let sourceBitmap = try XCTUnwrap(
            NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation))
        )
        let sourceData = try XCTUnwrap(sourceBitmap.representation(using: .png, properties: [:]))
        try sourceData.write(to: sourceURL)

        let store = SettingsStore(
            defaults: defaults,
            applyAppearance: false,
            avatarStorageDirectory: avatarDirectory
        )

        XCTAssertTrue(store.uploadAvatar(from: sourceURL))
        let savedPath = try XCTUnwrap(store.avatarPath)
        XCTAssertNotEqual(savedPath, sourceURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedPath))
        XCTAssertNotNil(NSImage(contentsOfFile: savedPath))

        store.removeAvatar()
        XCTAssertNil(store.avatarPath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: savedPath))
    }
}
