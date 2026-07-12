import SwiftUI
import AppKit

struct TaskRowView: View {
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var viewState: ContentViewState
    @Environment(\.colorScheme) private var colorScheme
    
    var task: FocusTask
    let isActive: Bool
    /// Snapshot of running state — do NOT pass full TimerStore (avoids per-second re-renders).
    let isRunning: Bool
    var isSelecting: Bool = false
    var isSelected: Bool = false
    var onToggleSelect: (() -> Void)? = nil
    let onEdit: () -> Void
    let onToggleTimer: () -> Void
    let onStartFocus: () -> Void
    
    @EnvironmentObject private var settings: SettingsStore
    
    private var hasNotes: Bool {
        !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Quiet priority rail — higher number = more urgent (matches sort + color helpers).
    private var priorityRailColor: Color {
        switch task.priority {
        case 1: return AppTheme.separator(for: colorScheme)
        case 2: return Color(hex: "#F59E0B").opacity(0.55)
        case 3: return Color(hex: "#EF4444").opacity(0.75)
        default: return Color(hex: "#8B5CF6").opacity(0.85)
        }
    }
    
    var body: some View {
        let density = settings.uiDensity
        let completedFade = task.isCompleted
        
        HStack(alignment: .center, spacing: 0) {
            // Priority rail (quiet signal, no “3 级” chrome)
            if !completedFade && !isSelecting {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(priorityRailColor)
                    .frame(width: 3, height: density == .compact ? 28 : 34)
                    .padding(.trailing, 10)
                    .help("优先级 \(task.priority)")
            } else {
                Color.clear.frame(width: 3).padding(.trailing, 10)
            }
            
            HStack(alignment: .center, spacing: 10 * density.scale) {
                if isSelecting {
                    Button {
                        onToggleSelect?()
                    } label: {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText(for: colorScheme).opacity(0.5))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { taskStore.toggleCompletion(for: task) } label: {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(
                                task.isCompleted
                                ? Color(hex: "#10B981").opacity(0.9)
                                : AppTheme.secondaryText(for: colorScheme).opacity(0.4)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(task.isCompleted ? "标为未完成" : "标为完成")
                    
                    if !task.isCompleted {
                        Button(action: handleFocusButton) {
                            Image(systemName: focusButtonIcon)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(isActive ? .white : AppTheme.secondaryText(for: colorScheme))
                                .frame(width: 24 * density.scale, height: 24 * density.scale)
                                .background(
                                    Circle().fill(
                                        isActive
                                        ? AppTheme.accent
                                        : AppTheme.elevatedBackground(for: colorScheme)
                                    )
                                )
                                .overlay(
                                    Circle().stroke(
                                        isActive ? Color.clear : AppTheme.separatorLow(for: colorScheme),
                                        lineWidth: 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .help(focusButtonHelp)
                    }
                }
                
                VStack(alignment: .leading, spacing: density == .compact ? 2 : 4) {
                    // Primary: title + only critical flags
                    HStack(spacing: 6) {
                        if task.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.55))
                                .help("已置顶")
                        }
                        
                        Text(task.title)
                            .font(.system(size: density == .compact ? 13.5 : 14.5, weight: .medium))
                            .foregroundColor(completedFade
                                             ? AppTheme.secondaryText(for: colorScheme).opacity(0.7)
                                             : AppTheme.primaryText(for: colorScheme))
                            .strikethrough(task.isCompleted, color: AppTheme.secondaryText(for: colorScheme).opacity(0.45))
                            .lineLimit(2)
                        
                        if isActive && !completedFade {
                            Text(isRunning ? "专注中" : "当前")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppTheme.accent.opacity(0.10)))
                        }
                        
                        if task.isOverdue && !task.isCompleted {
                            Text("逾期")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color(hex: "#EF4444").opacity(0.95))
                        }
                        
                        Spacer(minLength: 0)
                    }
                    
                    // Secondary: mono meta, low contrast
                    HStack(spacing: 8) {
                        pomodoroProgress
                        
                        Text(task.category.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.72))
                        
                        if task.recurrence != .none {
                            Text(task.recurrence.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.55))
                        }
                        
                        if hasNotes {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.5))
                                .help(task.notes)
                        }
                        
                        if task.hasLink {
                            Button(action: openTaskLink) {
                                Image(systemName: "link")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.55))
                            }
                            .buttonStyle(.plain)
                            .help(task.linkURL)
                        }
                        
                        if let due = task.dueDate {
                            Text(dueLabel(for: due))
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundColor(
                                    task.isOverdue && !task.isCompleted
                                    ? Color(hex: "#EF4444").opacity(0.85)
                                    : AppTheme.secondaryText(for: colorScheme).opacity(0.6)
                                )
                        }
                        
                        Spacer(minLength: 0)
                        
                        if !task.isCompleted && !isSelecting {
                            Button {
                                taskStore.togglePin(for: task)
                            } label: {
                                Image(systemName: task.isPinned ? "pin.fill" : "pin")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(
                                        task.isPinned
                                        ? AppTheme.accent.opacity(0.85)
                                        : AppTheme.secondaryText(for: colorScheme).opacity(0.28)
                                    )
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.plain)
                            .help(task.isPinned ? "取消置顶" : "置顶")
                            
                            Button(action: onEdit) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.32))
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.plain)
                            .help("编辑（也可双击）")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(completedFade ? 0.75 : 1)
            }
        }
        .padding(.leading, density == .compact ? 10 : 12)
        .padding(.trailing, density == .compact ? 10 : 12)
        .padding(.vertical, density.rowVerticalPadding)
        .background(rowBackground)
        .softHoverLift(cornerRadius: AppTheme.cornerRadiusRow)
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusRow, style: .continuous))
        .onTapGesture(count: 2) {
            if !isSelecting { onEdit() }
        }
        .simultaneousGesture(TapGesture().onEnded {
            if isSelecting { onToggleSelect?() }
        })
        .contextMenu { if !isSelecting { contextMenuContent } }
        .opacity(isSelecting && !isSelected ? 0.88 : 1)
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
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.55))
            if task.completedPomodoros > task.estimatedPomodoros {
                Text("+\(task.completedPomodoros - task.estimatedPomodoros)")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.7))
            } else if task.estimatedPomodoros > 0 {
                Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.65))
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
                        ? AppTheme.accent.opacity(0.28)
                        : (task.isOverdue && !task.isCompleted
                           ? Color(hex: "#EF4444").opacity(0.18)
                           : AppTheme.separatorLow(for: colorScheme)),
                        lineWidth: isActive ? 1.2 : 1
                    )
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
        
        if task.hasLink {
            Button {
                openTaskLink()
            } label: {
                Label("打开链接", systemImage: "link")
            }
        }
        
        Divider()
        
        Button(role: .destructive) {
            taskStore.deleteTask(task)
        } label: {
            Label("删除任务", systemImage: "trash")
        }
    }
    
    private func openTaskLink() {
        let trimmed = task.linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return }
        NSWorkspace.shared.open(url)
    }
    
    private func handleFocusButton() {
        // Always work-intent via parent startFocus path.
        onStartFocus()
        viewState.selectedScreen = .timer
    }
}
