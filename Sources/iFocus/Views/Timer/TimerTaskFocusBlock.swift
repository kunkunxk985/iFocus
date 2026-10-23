import SwiftUI

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
            pickerLine(title: task.title, detail: task.category.name)
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
        .disabled(timerStore.isRunning)
        .opacity(timerStore.isRunning ? 0.85 : 1)
    }

    private var emptyPicker: some View {
        let items = taskStore.incompleteTasks
        return Menu {
            menuContent
        } label: {
            pickerLine(
                title: items.isEmpty ? "自由专注" : "选择任务",
                detail: items.isEmpty ? "空格开始" : "\(items.count) 个未完成"
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func pickerLine(title: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
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

}
