import SwiftUI

/// Task picker strip above the focus ring.
struct TimerTaskFocusBlock: View {
    let layout: WindowLayoutMetrics
    let modeColor: Color
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var viewState: ContentViewState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // No section title — the row itself is enough (quieter chrome).
        Group {
            if let task = taskStore.activeTask {
                selectedRow(task)
            } else {
                emptyPicker
            }
        }
    }

    private func selectedRow(_ task: FocusTask) -> some View {
        let glyph = TimerLayoutMath.lerp(34, 42, layout.eased)
        let titleSize = TimerLayoutMath.lerp(13.5, 15.5, layout.eased)
        let pad = TimerLayoutMath.lerp(9, 13, layout.eased)
        return Menu {
            menuContent
        } label: {
            HStack(spacing: 12) {
                glyphView(task.category.icon, color: task.category.color, size: glyph)
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: titleSize, weight: .semibold))
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                        .lineLimit(1)
                    Text("\(task.category.rawValue) · \(task.completedPomodoros)/\(task.estimatedPomodoros) 番茄")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
            .padding(pad)
            .background(blockBackground(emphasized: true))
        }
        .menuStyle(.borderlessButton)
        .disabled(timerStore.isRunning)
        .opacity(timerStore.isRunning ? 0.85 : 1)
    }

    private var emptyPicker: some View {
        let items = taskStore.incompleteTasks
        let glyph = TimerLayoutMath.lerp(34, 42, layout.eased)
        let titleSize = TimerLayoutMath.lerp(13.5, 15.5, layout.eased)
        let pad = TimerLayoutMath.lerp(9, 13, layout.eased)
        return Menu {
            menuContent
        } label: {
            HStack(spacing: 12) {
                glyphView("list.bullet", color: modeColor, size: glyph)
                VStack(alignment: .leading, spacing: 3) {
                    Text(items.isEmpty ? "自由专注" : "选择任务")
                        .font(.system(size: titleSize, weight: .semibold))
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    Text(items.isEmpty
                         ? "空格开始，或先去清单添加"
                         : "\(items.count) 个未完成")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
            .padding(pad)
            .background(blockBackground(emphasized: false))
        }
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private var menuContent: some View {
        let items = taskStore.incompleteTasks
        Button {
            timerStore.requestStartWorkFocus(taskId: nil)
        } label: {
            Label("自由专注（不关联任务）", systemImage: "sparkles")
        }
        if !items.isEmpty {
            Divider()
            ForEach(items) { task in
                Button {
                    timerStore.requestStartWorkFocus(taskId: task.id)
                } label: {
                    Label {
                        Text("\(task.title)  ·  \(task.completedPomodoros)/\(task.estimatedPomodoros)")
                    } icon: {
                        Image(systemName: task.category.icon)
                    }
                }
            }
        }
        Divider()
        Button {
            viewState.selectedScreen = .todayTask
        } label: {
            Label("去「今天」添加任务…", systemImage: "plus.circle")
        }
    }

    private func glyphView(_ systemName: String, color: Color, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.14))
                .frame(width: size, height: size)
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundColor(color)
        }
    }

    private func blockBackground(emphasized: Bool) -> some View {
        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous)
            .fill(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.9 : 0.7))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous)
                    .stroke(
                        emphasized ? modeColor.opacity(0.18) : AppTheme.separatorLow(for: colorScheme),
                        lineWidth: 1
                    )
            )
    }
}
