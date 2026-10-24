import SwiftUI
import AppKit

/// Compact always-on-top companion for the focus timer. It only observes the
/// clock tick, so the mini window can update every second without re-rendering
/// the main window.
struct MiniTimerView: View {
    @ObservedObject var timerStore: TimerStore
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var settings: SettingsStore
    let onClose: () -> Void
    let onOpenMain: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var clockVersion: UInt = 0
    @State private var isHovering = false

    private var progress: Double {
        _ = clockVersion
        return timerStore.progress
    }

    private var time: String {
        _ = clockVersion
        return timerStore.timeString
    }

    private var stateLabel: String {
        if timerStore.isRunning { return "\(timerStore.mode.rawValue)中" }
        if timerStore.isSessionInProgress { return "已暂停" }
        return timerStore.mode.rawValue
    }

    private var taskTitle: String {
        if let title = taskStore.activeTask?.title, !title.isEmpty { return title }
        return timerStore.mode == .work ? "自由专注" : stateLabel
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
            Circle()
                .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(
                    timerStore.mode.accent,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 6) {
                Text(time)
                    .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if !isHovering {
                    Image(systemName: timerStore.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(timerStore.mode.accent)
                }
            }
            .padding(.horizontal, 16)
            .allowsHitTesting(false)
        }
        .frame(width: 148, height: 148)
        .overlay(MiniWindowDragArea().accessibilityHidden(true))
        .overlay(alignment: .topTrailing) {
            if isHovering {
                miniButton(systemName: "xmark", help: "隐藏迷你窗", action: onClose)
                    .offset(x: 2, y: -2)
            }
        }
        .overlay(alignment: .bottom) {
            if isHovering {
                HStack(spacing: 6) {
                    miniButton(
                        systemName: timerStore.isRunning ? "pause.fill" : "play.fill",
                        help: timerStore.isRunning ? "暂停" : (timerStore.isSessionInProgress ? "继续" : "开始"),
                        filled: true
                    ) {
                        timerStore.toggle()
                    }
                    miniButton(systemName: "forward.end.fill", help: "跳过此段") {
                        timerStore.skipToNext()
                    }
                    .disabled(!timerStore.canSkipSegment)
                    miniButton(systemName: "arrow.up.right.square", help: "打开专注钟") {
                        onOpenMain()
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .help(isHovering ? taskTitle : "拖动可移动，悬停后可暂停或跳过")
        .onHover { isHovering = $0 }
        .padding(8)
        .frame(width: 176, height: 176)
        .preferredColorScheme(settings.appearance.colorScheme)
        .onReceive(timerStore.clockTick) { _ in clockVersion &+= 1 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("迷你专注计时器，\(stateLabel)，\(time)，\(taskTitle)")
    }

    private func miniButton(
        systemName: String,
        help: String,
        filled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: filled ? 11 : 9.5, weight: .semibold))
                .foregroundColor(filled ? .white : AppTheme.secondaryText(for: colorScheme))
                .frame(width: filled ? 28 : 22, height: filled ? 28 : 22)
                .background(
                    Circle()
                        .fill(
                            filled
                            ? timerStore.mode.accent
                            : AppTheme.elevatedBackground(for: colorScheme).opacity(0.85)
                        )
                        .overlay(
                            Circle().strokeBorder(
                                filled ? Color.clear : AppTheme.separatorLow(for: colorScheme),
                                lineWidth: 0.75
                            )
                        )
                )
        }
        .buttonStyle(SoftScaleButtonStyle())
        .help(help)
        .accessibilityLabel(help)
    }
}


/// A transparent drag handle: the material card otherwise has no titlebar.
private struct MiniWindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
