import XCTest
import AppKit
import SwiftUI
@testable import iFocus

/// The settings window is non-opaque with a clear background, so any pixel the view leaves
/// transparent shows the desktop. The margin around the glass sidebar card and the gap before
/// the content pane must be painted like the main window's canvas.
final class SettingsWindowChromeTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var tempDir: URL!

    override func setUpWithError() throws {
        suiteName = "iFocus.SettingsWindowChromeTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-SettingsChrome-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSettingsRimAroundSidebarCardIsOpaque() throws {
        let settings = SettingsStore(defaults: defaults, applyAppearance: false)
        let tasks = TaskStore(storageDirectory: tempDir)
        let timer = TimerStore(settings: settings, taskStore: tasks, sessionStorageDirectory: tempDir)
        let size = NSSize(width: 900, height: 628)
        let host = NSHostingView(
            rootView: SettingsWindowView()
                .environmentObject(settings)
                .environmentObject(timer)
                .environmentObject(tasks)
                .environment(\.colorScheme, .dark)
                .frame(width: size.width, height: size.height)
        )
        host.appearance = NSAppearance(named: .darkAqua)
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)

        // Points in view coordinates (top-left origin): left/top/bottom margin of the card,
        // and the gap between the card (ends at x≈196) and the content pane (starts at x=200).
        let scale = CGFloat(rep.pixelsWide) / size.width
        let rim: [(String, CGFloat, CGFloat)] = [
            ("left margin", 3, 300),
            ("top margin", 100, 3),
            ("bottom margin", 100, size.height - 3),
            ("card/content gap", 198, 300),
        ]
        for (label, x, y) in rim {
            let color = try XCTUnwrap(rep.colorAt(x: Int(x * scale), y: Int(y * scale)))
            XCTAssertEqual(color.alphaComponent, 1, accuracy: 0.01, "\(label) is see-through")
        }
    }

    /// SwiftUI has left the bottom of the main window's sidebar column unpainted (4–32pt) in the
    /// running app. Whatever a view misses must look like the canvas, never show the desktop
    /// through a clear window: the left 252pt paint nothing, the rest paints the canvas.
    func testManagedWindowsShowCanvasWhereContentLeavesAGap() throws {
        for title in ["iFocus", "设置"] {
            for (appearanceName, scheme) in [(NSAppearance.Name.darkAqua, ColorScheme.dark), (.aqua, .light)] {
                let size = NSSize(width: 900, height: 628)
                let window = NSWindow(
                    contentRect: NSRect(origin: .zero, size: size),
                    styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                    backing: .buffered,
                    defer: false
                )
                window.isReleasedWhenClosed = false
                window.title = title
                window.appearance = NSAppearance(named: appearanceName)
                window.contentView = NSHostingView(
                    rootView: HStack(spacing: 0) {
                        Color.clear.frame(width: 252)
                        AppTheme.contentBackground(for: scheme)
                    }
                    .frame(width: size.width, height: size.height)
                    .ignoresSafeArea()
                )
                WindowChrome.apply(to: window)
                let frameView = try XCTUnwrap(window.contentView?.superview)
                frameView.layoutSubtreeIfNeeded()
                let rep = try XCTUnwrap(frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds))
                frameView.cacheDisplay(in: frameView.bounds, to: rep)

                let scale = CGFloat(rep.pixelsWide) / frameView.bounds.width
                let bottomRow = rep.pixelsHigh - Int(3 * scale)
                let gap = try XCTUnwrap(rep.colorAt(x: Int(60 * scale), y: bottomRow))
                let canvas = try XCTUnwrap(rep.colorAt(x: Int(600 * scale), y: bottomRow))
                let label = "\(title) \(appearanceName.rawValue)"
                XCTAssertEqual(gap.alphaComponent, 1, accuracy: 0.01, "\(label): gap is see-through")
                XCTAssertEqual(gap.redComponent, canvas.redComponent, accuracy: 0.01, "\(label): gap differs from canvas")
                XCTAssertEqual(gap.greenComponent, canvas.greenComponent, accuracy: 0.01, "\(label): gap differs from canvas")
                XCTAssertEqual(gap.blueComponent, canvas.blueComponent, accuracy: 0.01, "\(label): gap differs from canvas")
                window.close()
            }
        }
    }
}
