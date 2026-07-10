import SwiftUI

struct TaskRowView: View {
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var viewState: ContentViewState
    @Environment(\.colorScheme) private var colorScheme
    
    var task: FocusTask
    let isActive: Bool
    /// Snapshot of running state — do NOT pass full TimerStore (avoids per-second re-renders).
    let isRunning: Bool
    let onEdit: () -> Void
    let onToggleTimer: () -> Void
    let onStartFocus: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { taskStore.toggleCompletion(for: task) } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(task.isCompleted ? Color(hex: "#10B981") : AppTheme.secondaryText(for: colorScheme).opacity(0.55))
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? "标为未完成" : "标为完成")
            
            if !task.isCompleted {
                Button(action: handleFocusButton) {
                    Image(systemName: focusButtonIcon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isActive ? .white : AppTheme.primaryText(for: colorScheme))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(
                                isActive
                                ? AppTheme.accent
                                : AppTheme.elevatedBackground(for: colorScheme)
                            )
                        )
                        .overlay(
                            Circle().stroke(
                                isActive ? Color.clear : AppTheme.separator(for: colorScheme),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
                .help(focusButtonHelp)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if task.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                            .help("已置顶")
                    }
                    
                    Text(task.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(task.isCompleted
                                         ? AppTheme.secondaryText(for: colorScheme)
                                         : AppTheme.primaryText(for: colorScheme))
                        .strikethrough(task.isCompleted, color: AppTheme.secondaryText(for: colorScheme))
                        .lineLimit(2)
                    
                    if isActive {
                        Text(isRunning ? "专注中" : "当前")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppTheme.accent.opacity(0.12)))
                    }
                    
                    if task.isOverdue && !task.isCompleted {
                        Text("逾期")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "#EF4444"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(hex: "#EF4444").opacity(0.12)))
                    }
                }
                
                HStack(spacing: 8) {
                    pomodoroProgress
                    
                    metaChip(task.category.rawValue, color: task.category.color)
                    
                    if let due = task.dueDate {
                        Text(dueLabel(for: due))
                            .font(.caption2.weight(.medium))
                            .foregroundColor(
                                task.isOverdue && !task.isCompleted
                                ? Color(hex: "#EF4444")
                                : AppTheme.secondaryText(for: colorScheme)
                            )
                    }
                    
                    Spacer(minLength: 0)
                    
                    if !task.isCompleted {
                        Button {
                            taskStore.togglePin(for: task)
                        } label: {
                            Image(systemName: task.isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(task.isPinned ? AppTheme.accent : AppTheme.secondaryText(for: colorScheme).opacity(0.45))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help(task.isPinned ? "取消置顶" : "置顶")
                    }
                    
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.55))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("编辑（也可双击）")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(rowBackground)
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusRow, style: .continuous))
        .onTapGesture(count: 2, perform: onEdit)
        .contextMenu { contextMenuContent }
    }
    
    private func metaChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }
    
    private var focusButtonIcon: String {
        if isActive && isRunning { return "pause.fill" }
        return "play.fill"
    }
    
    private var focusButtonHelp: String {
        if isActive && isRunning { return "暂停专注" }
        if isActive { return "继续专注" }
        if isRunning { return "切换到此任务并重新计时" }
        return "专注此任务"
    }
    
    private func dueLabel(for due: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(due) { return "今天" }
        if calendar.isDateInTomorrow(due) { return "明天" }
        if calendar.isDateInYesterday(due) { return "昨天" }
        return dueFormatter.string(from: due)
    }
    
    private var pomodoroProgress: some View {
        HStack(spacing: 3) {
            Image(systemName: "timer")
                .font(.caption2.bold())
                .foregroundColor(AppTheme.accent.opacity(0.9))
            if task.completedPomodoros > task.estimatedPomodoros {
                Text("+\(task.completedPomodoros - task.estimatedPomodoros)")
                    .font(.caption2.bold())
                    .foregroundColor(AppTheme.accent)
            } else if task.estimatedPomodoros > 0 {
                Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
        }
    }
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusRow, style: .continuous)
            .fill(AppTheme.cardBackground(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusRow, style: .continuous)
                    .stroke(
                        isActive
                        ? AppTheme.accent.opacity(0.4)
                        : (task.isOverdue && !task.isCompleted
                           ? Color(hex: "#EF4444").opacity(0.25)
                           : AppTheme.separatorLow(for: colorScheme)),
                        lineWidth: isActive ? 1.4 : 1
                    )
            )
            .shadow(
                color: isActive ? AppTheme.accent.opacity(0.14) : .clear,
                radius: isActive ? 10 : 0,
                y: isActive ? 3 : 0
            )
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button(action: handleFocusButton) {
            Label(focusButtonHelp, systemImage: focusButtonIcon)
        }
        
        Button {
            taskStore.toggleCompletion(for: task)
        } label: {
            Label(task.isCompleted ? "标记为未完成" : "标记为已完成",
                  systemImage: task.isCompleted ? "circle" : "checkmark.circle.fill")
        }
        
        if !task.isCompleted {
            Button {
                taskStore.togglePin(for: task)
            } label: {
                Label(task.isPinned ? "取消置顶" : "置顶", systemImage: task.isPinned ? "pin.slash" : "pin")
            }
        }
        
        Menu("修改优先级") {
            ForEach(1...4, id: \.self) { priority in
                Button {
                    taskStore.updatePriority(for: task, to: priority)
                } label: {
                    HStack {
                        Text("\(priority) 级")
                        if task.priority == priority { Image(systemName: "checkmark") }
                    }
                }
            }
        }
        
        Menu("修改分类") {
            ForEach(TaskCategory.allCases) { category in
                Button {
                    taskStore.updateCategory(for: task, to: category)
                } label: {
                    HStack {
                        Text(category.rawValue)
                        if task.category == category { Image(systemName: "checkmark") }
                    }
                }
            }
        }
        
        Menu("移动到日期") {
            Button("今天") {
                taskStore.updateDueDate(for: task, to: Calendar.current.startOfDay(for: Date()))
            }
            Button("明天") {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
                taskStore.updateDueDate(for: task, to: tomorrow)
            }
            Button("清除日期") {
                taskStore.updateDueDate(for: task, to: nil)
            }
        }
        
        Button(action: onEdit) {
            Label("编辑任务", systemImage: "pencil")
        }
        
        Divider()
        
        Button(role: .destructive) {
            taskStore.deleteTask(task)
        } label: {
            Label("删除任务", systemImage: "trash")
        }
    }
    
    private func handleFocusButton() {
        if isActive {
            let wasRunning = isRunning
            onToggleTimer()
            if !wasRunning {
                viewState.selectedScreen = .timer
            }
            return
        }
        onStartFocus()
        viewState.selectedScreen = .timer
    }
}
