import SwiftUI
import AppKit

/// Glass-finished macOS window controls (Hide, Minimize, Fullscreen / Zoom).
/// The window actions remain native while SwiftUI renders the Liquid Glass-style lens.
struct TrafficLightsView: View {
    var windowTitle: String? = nil
    var showsBackdrop: Bool = true
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHoveringCluster = false
    @State private var isWindowKey = true
    @State private var isWindowFullScreen = false
    @State private var isOptionPressed = false
    @State private var flagsMonitor: Any? = nil

    var body: some View {
        HStack(spacing: 4) {
            trafficLightButton(
                color: Color(hex: "#FF5F56"),
                borderColor: Color(hex: "#E0443E"),
                glyphName: "xmark",
                glyphColor: Color(hex: "#4C0002"),
                glyphSize: 6.5,
                glyphWeight: .bold,
                tooltip: "隐藏窗口 (⌘W)",
                accessibilityLabel: "隐藏窗口",
                accessibilityHint: "将 iFocus 窗口隐藏到菜单栏；之后仍可从菜单栏重新打开。",
                isEnabled: true
            ) {
                guard let window = getTargetWindow() else { return }
                WindowChromeController.closeOrHide(window: window)
            }

            trafficLightButton(
                color: Color(hex: "#FFBD2E"),
                borderColor: Color(hex: "#DEA123"),
                glyphName: "minus",
                glyphColor: Color(hex: "#5B3C00"),
                glyphSize: 7,
                glyphWeight: .black,
                tooltip: isWindowFullScreen ? "全屏模式下无法最小化" : "最小化窗口 (⌘M)",
                accessibilityLabel: "最小化窗口",
                accessibilityHint: "将窗口收至程序坞。",
                isEnabled: !isWindowFullScreen
            ) {
                guard !isWindowFullScreen, let window = getTargetWindow() else { return }
                window.miniaturize(nil)
            }

            trafficLightButton(
                color: Color(hex: "#27C93F"),
                borderColor: Color(hex: "#1AAB29"),
                glyphName: greenGlyphName,
                glyphColor: Color(hex: "#003800"),
                glyphSize: greenGlyphSize,
                glyphWeight: .bold,
                tooltip: greenTooltip,
                accessibilityLabel: greenTooltip,
                accessibilityHint: "按住 Option 键可缩放窗口；可用 Control-Command-F 切换全屏。",
                isEnabled: !isGreenDisabled
            ) {
                guard let window = getTargetWindow() else { return }
                if isWindowFullScreen {
                    window.toggleFullScreen(nil)
                } else if NSEvent.modifierFlags.contains(.option) {
                    window.zoom(nil)
                } else {
                    window.toggleFullScreen(nil)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background {
            if showsBackdrop {
                Capsule()
                    .adaptiveGlass(cornerRadius: 16, fallbackMaterial: .titlebar)
                    .overlay {
                        Capsule().strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isWindowKey ? 0.82 : 0.48),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                    }
                    .shadow(color: .black.opacity(isWindowKey ? 0.12 : 0.06), radius: 7, y: 2)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.14)) {
                isHoveringCluster = hovering
            }
            if hovering {
                isOptionPressed = NSEvent.modifierFlags.contains(.option)
                if flagsMonitor == nil {
                    flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                        let option = event.modifierFlags.contains(.option)
                        DispatchQueue.main.async {
                            if self.isHoveringCluster && self.isOptionPressed != option {
                                self.isOptionPressed = option
                            }
                        }
                        return event
                    }
                }
            } else {
                isOptionPressed = false
                if let monitor = flagsMonitor {
                    NSEvent.removeMonitor(monitor)
                    flagsMonitor = nil
                }
            }
        }
        .onAppear {
            syncWindowStates()
            DispatchQueue.main.async {
                syncWindowStates()
            }
        }
        .onDisappear {
            if let monitor = flagsMonitor {
                NSEvent.removeMonitor(monitor)
                flagsMonitor = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            if isTargetWindow(note.object as? NSWindow) {
                isWindowKey = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            if isTargetWindow(note.object as? NSWindow) {
                isWindowKey = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { note in
            if isTargetWindow(note.object as? NSWindow) {
                isWindowFullScreen = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { note in
            if isTargetWindow(note.object as? NSWindow) {
                isWindowFullScreen = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { note in
            if isTargetWindow(note.object as? NSWindow) {
                isWindowFullScreen = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { note in
            if isTargetWindow(note.object as? NSWindow) {
                isWindowFullScreen = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            syncWindowStates()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            isWindowKey = false
        }
    }

    private var isGreenDisabled: Bool {
        if windowTitle == "设置" { return true }
        guard let window = getTargetWindow() else { return false }
        if window.title == "设置" { return true }
        return !window.styleMask.contains(.resizable)
    }

    private var greenGlyphName: String {
        if isWindowFullScreen {
            return "arrow.down.right.and.arrow.up.left"
        }
        return isOptionPressed ? "plus" : "arrow.up.left.and.arrow.down.right"
    }

    private var greenGlyphSize: CGFloat {
        if isWindowFullScreen {
            return 6.0
        }
        return isOptionPressed ? 6.5 : 6.0
    }

    private var greenTooltip: String {
        if isGreenDisabled {
            return "设置窗口不支持全屏"
        }
        if isWindowFullScreen {
            return "退出全屏 (⌃⌘F)"
        }
        return isOptionPressed ? "缩放 (⌥)" : "全屏 (⌃⌘F) / 缩放 (⌥)"
    }

    private func syncWindowStates() {
        if let window = getTargetWindow() {
            isWindowKey = window.isKeyWindow
            isWindowFullScreen = window.styleMask.contains(.fullScreen)
        }
    }

    private func isTargetWindow(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        if let windowTitle {
            return window.title == windowTitle
        }
        return window.title == "iFocus" || window.title == "设置"
    }

    private func getTargetWindow() -> NSWindow? {
        if let windowTitle {
            if let key = NSApp.keyWindow, key.title == windowTitle {
                return key
            }
            if let found = NSApplication.shared.windows.first(where: { $0.title == windowTitle }) {
                return found
            }
        } else if let key = NSApp.keyWindow, (key.title == "iFocus" || key.title == "设置") {
            return key
        }
        return NSApplication.shared.windows.first(where: { ($0.title == "iFocus" || $0.title == "设置") && $0.canBecomeKey })
    }

    private func trafficLightButton(
        color: Color,
        borderColor: Color,
        glyphName: String,
        glyphColor: Color,
        glyphSize: CGFloat,
        glyphWeight: Font.Weight,
        tooltip: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            if isEnabled {
                action()
            }
        }) {
            let isActiveOrHovered = isWindowKey || isHoveringCluster
            TrafficLightCircleBody(
                color: isEnabled && isActiveOrHovered ? color : inactiveColor,
                borderColor: isEnabled && isActiveOrHovered ? borderColor : inactiveBorderColor,
                glyphName: glyphName,
                glyphColor: glyphColor,
                glyphSize: glyphSize,
                glyphWeight: glyphWeight,
                showGlyph: isEnabled && isHoveringCluster && !glyphName.isEmpty
            )
            .frame(width: 20, height: 20)
            .contentShape(Circle())
        }
        .buttonStyle(TrafficLightButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .help(tooltip)
    }

    private var inactiveColor: Color {
        colorScheme == .light
            ? Color(hex: "#D8D8DC")
            : Color(hex: "#38383C")
    }

    private var inactiveBorderColor: Color {
        colorScheme == .light
            ? Color(hex: "#C6C6CC")
            : Color(hex: "#444448")
    }
}

private struct TrafficLightCircleBody: View {
    let color: Color
    let borderColor: Color
    let glyphName: String
    let glyphColor: Color
    let glyphSize: CGFloat
    let glyphWeight: Font.Weight
    let showGlyph: Bool

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.78), color, borderColor.opacity(0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Circle().fill(
                    RadialGradient(
                        colors: [.white.opacity(0.72), .white.opacity(0.16), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 14
                    )
                )
            }
            .overlay(alignment: .topLeading) {
                Ellipse()
                    .fill(Color.white.opacity(0.76))
                    .frame(width: 5.5, height: 2.2)
                    .blur(radius: 0.45)
                    .offset(x: 3, y: 2)
            }
            .overlay {
                Circle().strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.92), .white.opacity(0.20), borderColor.opacity(0.86)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
            }
            .overlay {
                if showGlyph && !glyphName.isEmpty {
                    Image(systemName: glyphName)
                        .font(.system(size: glyphSize, weight: glyphWeight))
                        .foregroundColor(glyphColor.opacity(0.9))
                        .transition(.opacity)
                }
            }
            .shadow(color: borderColor.opacity(0.34), radius: 2, y: 1)
            .clipShape(Circle())
            .frame(width: 13, height: 13)
    }
}

private struct TrafficLightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
