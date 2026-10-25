import SwiftUI
import iFocusCore

/// Task picker strip above the focus ring.
struct TimerTaskFocusBlock: View {
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
        Menu {
            menuContent
        } label: {
            pickerLine(title: task.title, detail: timerTaskDetail(for: task), isTaskSelected: true)
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
        .disabled(timerStore.isRunning)
        .opacity(timerStore.isRunning ? 0.90 : 1)
    }

    private var emptyPicker: some View {
        let items = taskStore.incompleteTasks
        return Menu {
            menuContent
        } label: {
            pickerLine(
                title: items.isEmpty ? "自由专注" : "选择任务",
                detail: items.isEmpty ? "空格开始" : "\(items.count) 个待办",
                isTaskSelected: false
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func timerTaskDetail(for task: FocusTask) -> String {
        if task.timeSpentMinutes > 0 {
            return FocusStats.formatTotalMinutes(task.timeSpentMinutes)
        }
        if let due = task.dueDate {
            let calendar = Calendar.current
            if calendar.isDateInToday(due) { return "今天" }
            if calendar.isDateInTomorrow(due) { return "明天" }
        }
        return ""
    }

    private func pickerLine(title: String, detail: String, isTaskSelected: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: isTaskSelected ? "target" : "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isTaskSelected ? AppTheme.accent : AppTheme.secondaryText(for: colorScheme).opacity(0.8))

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .lineLimit(1)

            if !detail.isEmpty {
                Text("·")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.35))

                Text(detail)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.80))
                    .lineLimit(1)
            }

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.55))
                .padding(.leading, 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.95 : 0.85))
        )
        .overlay(
            Capsule()
                .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.75)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .light ? 0.03 : 0.12),
            radius: 8,
            x: 0,
            y: 2
        )
        .contentShape(Capsule())
    }

    @ViewBuilder
    private var menuContent: some View {
        let items = taskStore.incompleteTasks
        Button {
            timerStore.selectTask(nil)
        } label: {
            HStack {
                Label("自由专注（不关联任务）", systemImage: "sparkles")
                if taskStore.activeTaskId == nil {
                    Image(systemName: "checkmark")
                }
            }
        }
        if !items.isEmpty {
            Divider()
            ForEach(items) { task in
                Button {
                    timerStore.selectTask(task.id)
                } label: {
                    HStack {
                        Text(task.title)
                        if taskStore.activeTaskId == task.id {
                            Image(systemName: "checkmark")
                        }
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

}
