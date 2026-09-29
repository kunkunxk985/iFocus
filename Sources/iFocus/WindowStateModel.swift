import AppKit
import Foundation
import SwiftUI

/// Observable state for macOS window chrome, fullscreen status, and sidebar layout.
final class WindowStateModel: ObservableObject {
    static let shared = WindowStateModel()

    @Published var isFullScreen: Bool = false
    @Published var isTransitioningFullScreen: Bool = false
    @Published var isSidebarCollapsed: Bool = WindowLayoutStore.isSidebarCollapsed

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.willEnterFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let window = note.object as? NSWindow, window.title != "设置" {
                self?.isFullScreen = true
                self?.isTransitioningFullScreen = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didEnterFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let window = note.object as? NSWindow, window.title != "设置" {
                self?.isFullScreen = true
                self?.isTransitioningFullScreen = false
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.willExitFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let window = note.object as? NSWindow, window.title != "设置" {
                self?.isFullScreen = false
                self?.isTransitioningFullScreen = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didExitFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let window = note.object as? NSWindow, window.title != "设置" {
                self?.isFullScreen = false
                self?.isTransitioningFullScreen = false
            }
        }
    }

    func sync() {
        if let window = NSApplication.shared.windows.first(where: { $0.title == "iFocus" }) {
            isFullScreen = window.styleMask.contains(.fullScreen)
        }
        isSidebarCollapsed = WindowLayoutStore.isSidebarCollapsed
    }
}
