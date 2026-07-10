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
    
    var body: some View {
        let density = settings.uiDensity
        let completedFade = task.isCompleted
        HStack(alignment: .center, spacing: 10 * density.scale) {
            if isSelecting {
                Button {
                    onToggleSelect?()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText(for: colorScheme).opacity(0.55))
                }
                .buttonStyle(.plain)
            } else {
                Button { taskStore.toggleCompletion(for: task) } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(task.isCompleted ? Color(hex: "#10B981") : AppTheme.secondaryText(for: colorScheme).opacity(0.45))
                }
                .buttonStyle(.plain)
                .help(task.isCompleted ? "标为未完成" : "标为完成")
                
                if !task.isCompleted {
                    Button(action: handleFocusButton) {
                        Image(systemName: focusButtonIcon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isActive ? .white : AppTheme.primaryText(for: colorScheme))
                            .frame(width: 26 * density.scale, height: 26 * density.scale)
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
            }
            
            VStack(alignment: .leading, spacing: density == .compact ? 3 : 5) {
                // Primary line: title + only critical badges
                HStack(spacing: 6) {
                    if task.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppTheme.accent.opacity(0.9))
                            .help("已置顶")
                    }
                    
                    Text(task.title)
                        .font(.system(size: density == .compact ? 14 : 15.5, weight: .semibold))
                        .foregroundColor(completedFade
                                         ? AppTheme.secondaryText(for: colorScheme).opacity(0.72)
                                         : AppTheme.primaryText(for: colorScheme))
                        .strikethrough(task.isCompleted, color: AppTheme.secondaryText(for: colorScheme).opacity(0.5))
                        .lineLimit(2)
                    
                    if isActive && !completedFade {
                        statusPill(isRunning ? "专注中" : "当前", color: AppTheme.accent)
                    }
                    
                    if task.isOverdue && !task.isCompleted {
                        statusPill("逾期", color: Color(hex: "#EF4444"))
                    }
                    
                    Spacer(minLength: 0)
                }
                
                // Secondary line: quieter meta
                HStack(spacing: 6) {
                    pomodoroProgress
                    
                    metaChip(task.category.rawValue, color: task.category.color.opacity(completedFade ? 0.55 : 0.85))
                    
                    if task.recurrence != .none {
                        metaChip(task.recurrence.rawValue, color: Color(hex: "#8B5CF6").opacity(0.75))
                    }
                    
                    if hasNotes {
                        Image(systemName: "note.text")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.7))
                            .help(task.notes)
                    }
                    
                    if task.hasLink {
                        Button {
                            openTaskLink()
                        } label: {
                            Image(systemName: "link")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppTheme.accent.opacity(0.9))
                        }
                        .buttonStyle(.plain)
                        .help(task.linkURL)
                    }
                    
                    if let due = task.dueDate {
                        Text(dueLabel(for: due))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(
                                task.isOverdue && !task.isCompleted
                                ? Color(hex: "#EF4444").opacity(0.9)
                                : AppTheme.secondaryText(for: colorScheme).opacity(0.75)
                            )
                    }
                    
                    Spacer(minLength: 0)
                    
                    if !task.isCompleted && !isSelecting {
                        Button {
                            taskStore.togglePin(for: task)
                        } label: {
                            Image(systemName: task.isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(task.isPinned ? AppTheme.accent : AppTheme.secondaryText(for: colorScheme).opacity(0.35))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .help(task.isPinned ? "取消置顶" : "置顶")
                        
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.4))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .help("编辑（也可双击）")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(completedFade ? 0.78 : 1)
        }
        .padding(.horizontal, density == .compact ? 12 : 14)
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
        .opacity(isSelecting && !isSelected ? 0.85 : 1)
    }
    
    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }
    
    private func metaChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color.opacity(0.9))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.08)))
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
