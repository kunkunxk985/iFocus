import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var viewState: ContentViewState
    @Environment(\.colorScheme) private var colorScheme
    /// Stable sheet identity — never bind sheet(item:) to a live mutating task value.
    @State private var editSession: EditTaskSession? = nil
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    
    private func filter(for screen: AppScreen) -> TaskStore.TaskFilter {
        switch screen {
        case .todayTask: return .todayTask
        case .tomorrowTask: return .tomorrowTask
        case .weekTask: return .weekTask
        case .plannedTask: return .plannedTask
        case .completedTask: return .completedTask
        case .inboxTask: return .inboxTask
        default: return .todayTask
        }
    }
    
    private var listTitle: String {
        switch viewState.selectedScreen {
        case .todayTask: return "今天"
        case .tomorrowTask: return "明天"
        case .weekTask: return "本周"
        case .plannedTask: return "已计划"
        case .completedTask: return "已完成"
        case .inboxTask: return "收集箱"
        default: return "待办任务"
        }
    }
    
    private var listSubtitle: String {
        switch viewState.selectedScreen {
        case .todayTask: return "今天到期与逾期 · 优先处理红色项"
        case .tomorrowTask: return "提前安排明天要做的事"
        case .weekTask: return "本周计划（不含今天、明天）"
        case .plannedTask: return "所有带截止日期的未完成任务"
        case .completedTask: return "已完成任务的回顾"
        case .inboxTask: return "随手记下，稍后再安排日期"
        default: return ""
        }
    }
    
    private var listIcon: String {
        switch viewState.selectedScreen {
        case .todayTask: return "sun.max.fill"
        case .tomorrowTask: return "sunrise.fill"
        case .weekTask: return "calendar"
        case .plannedTask: return "calendar.badge.clock"
        case .completedTask: return "checkmark.circle.fill"
        case .inboxTask: return "tray.fill"
        default: return "list.bullet"
        }
    }
    
    private var currentFilter: TaskStore.TaskFilter {
        filter(for: viewState.selectedScreen ?? .todayTask)
    }
    
    private var placeholderText: String {
        switch viewState.selectedScreen {
        case .todayTask: return "添加今天的任务，回车保存"
        case .tomorrowTask: return "添加明天的任务，回车保存"
        case .weekTask: return "添加本周任务，回车保存"
        case .plannedTask: return "添加计划任务，回车保存"
        case .inboxTask: return "先丢进收集箱…"
        default: return "添加任务，回车保存"
        }
    }
    
    private var currentTasks: [FocusTask] {
        taskStore.tasks(for: currentFilter)
    }
    private var incompleteFiltered: [FocusTask] {
        currentTasks.filter { !$0.isCompleted }
    }
    private var completedFiltered: [FocusTask] {
        currentTasks.filter { $0.isCompleted }
    }
    
    private var overdueTasks: [FocusTask] {
        guard viewState.selectedScreen == .todayTask else { return [] }
        return incompleteFiltered.filter(\.isOverdue)
    }
    
    private var dueTodayTasks: [FocusTask] {
        guard viewState.selectedScreen == .todayTask else { return incompleteFiltered }
        return incompleteFiltered.filter { !$0.isOverdue }
    }
    
    private var estimatedMinutes: Int {
        incompleteFiltered.reduce(0) { $0 + $1.estimatedPomodoros * settings.workMinutes }
    }
    private var totalFocusMinutes: Int {
        currentTasks.reduce(0) { $0 + $1.timeSpentMinutes }
    }
    
    var body: some View {
        PageContainer(maxWidth: 900, horizontalPadding: 40) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PageTitle(
                        title: listTitle,
                        subtitle: listSubtitle,
                        systemImage: listIcon,
                        tint: AppTheme.accent
                    )
                    .overlay(alignment: .trailing) {
                        HStack(spacing: 8) {
                            if !incompleteFiltered.isEmpty {
                                Text("\(incompleteFiltered.count) 项")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(AppTheme.cardBackground(for: colorScheme)))
                                    .overlay(Capsule().stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1))
                            }
                            if !currentTasks.isEmpty {
                                Button(isSelecting ? "完成选择" : "批量") {
                                    withAnimation {
                                        isSelecting.toggle()
                                        if !isSelecting { selectedIDs.removeAll() }
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }

                    statsBar
                        .padding(.top, 18)
                        .padding(.bottom, 20)
                    
                    if isSelecting {
                        batchToolbar
                            .padding(.bottom, 16)
                    }

                    if viewState.selectedScreen != .completedTask, !isSelecting {
                        addTaskSection
                            .padding(.bottom, 20)
                    }

                    taskListSection
                        .padding(.bottom, 48)
                }
            }
            .softScroll()
        }
        .onChange(of: viewState.selectedScreen) { _ in
            isSelecting = false
            selectedIDs.removeAll()
        }
        // Snapshot identity (`EditTaskSession`) — never `sheet(item:)` a live FocusTask
        // that mutates while the timer is running.
        .sheet(item: $editSession) { session in
            EditTaskView(session: session) { title, category, priority, pomodoros, due, recurrence in
                taskStore.updateTask(
                    id: session.id,
                    title: title,
                    category: category,
                    priority: priority,
                    estimatedPomodoros: pomodoros,
                    dueDate: due,
                    recurrence: recurrence
                )
            }
            .id(session.id)
        }
    }
    
    private var batchToolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedIDs.isEmpty ? "点选任务进行批量操作" : "已选 \(selectedIDs.count) 项")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            
            HStack(spacing: 8) {
                batchButton("全选") {
                    selectedIDs = Set(currentTasks.map(\.id))
                }
                batchButton("完成") {
                    taskStore.completeTasks(ids: selectedIDs)
                    selectedIDs.removeAll()
                }
                .disabled(selectedIDs.isEmpty)
                batchButton("今天") {
                    taskStore.setDueDate(ids: selectedIDs, to: Calendar.current.startOfDay(for: Date()))
                    selectedIDs.removeAll()
                }
                .disabled(selectedIDs.isEmpty)
                batchButton("明天") {
                    let t = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
                    taskStore.setDueDate(ids: selectedIDs, to: t)
                    selectedIDs.removeAll()
                }
                .disabled(selectedIDs.isEmpty)
                batchButton("收集箱") {
                    taskStore.moveToInbox(ids: selectedIDs)
                    selectedIDs.removeAll()
                }
                .disabled(selectedIDs.isEmpty)
                batchButton("删除", destructive: true) {
                    taskStore.deleteTasks(ids: selectedIDs)
                    selectedIDs.removeAll()
                }
                .disabled(selectedIDs.isEmpty)
                Spacer()
            }
        }
        .padding(14)
        .background(SoftCardBackground(cornerRadius: 14))
    }
    
    private func batchButton(
        _ title: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(destructive ? .red : AppTheme.accent)
    }
    
    private var statsBar: some View {
        HStack(spacing: 10) {
            miniStat(value: formattedEstimated, label: "预计", color: AppTheme.accent)
            miniStat(value: "\(incompleteFiltered.count)", label: "待办", color: Color(hex: "#F59E0B"))
            miniStat(value: formattedFocusTime, label: "已专注", color: Color(hex: "#3B82F6"))
            if viewState.selectedScreen == .todayTask && !overdueTasks.isEmpty {
                miniStat(value: "\(overdueTasks.count)", label: "逾期", color: Color(hex: "#EF4444"))
            } else {
                miniStat(value: "\(completedFiltered.count)", label: "完成", color: Color(hex: "#10B981"))
            }
        }
    }
    
    private func miniStat(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(SoftCardBackground(cornerRadius: 14))
    }
    
    private var formattedEstimated: String {
        let mins = estimatedMinutes
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)h\(m)m" : "\(h)h"
        }
        return "\(mins)分"
    }
    
    private var formattedFocusTime: String {
        let mins = totalFocusMinutes
        let h = mins / 60
        let m = mins % 60
        if mins == 0 { return "0" }
        if h > 0 && m > 0 { return "\(h)h\(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
    
    private var addTaskSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .padding(.leading, 4)
            
            TextField(placeholderText, text: $taskStore.newTaskTitle)
                .textFieldStyle(.plain)
                .font(.body)
                .onSubmit { addTask() }
            
            HStack(spacing: 6) {
                compactMenu(help: "番茄") {
                    Picker("预估番茄", selection: $taskStore.newTaskPomodoros) {
                        ForEach(1...8, id: \.self) { n in
                            Text("\(n) 番茄").tag(n)
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                        Text("\(taskStore.newTaskPomodoros)")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(AppTheme.accent)
                }
                
                compactMenu(help: "优先级") {
                    Picker("优先级", selection: $taskStore.newTaskPriority) {
                        ForEach(1...4, id: \.self) { n in
                            Text("\(n) 级").tag(n)
                        }
                    }
                } label: {
                    Image(systemName: priorityIcon(taskStore.newTaskPriority))
                        .foregroundColor(priorityColor(taskStore.newTaskPriority))
                }
                
                compactMenu(help: "分类") {
                    Picker("分类", selection: $taskStore.newTaskCategory) {
                        ForEach(TaskCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                } label: {
                    Image(systemName: taskStore.newTaskCategory.icon)
                        .foregroundColor(taskStore.newTaskCategory.color)
                }
                
                Button(action: addTask) {
                    Text("添加")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(
                                taskStore.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? AppTheme.accent.opacity(0.35)
                                : AppTheme.accent
                            )
                        )
                }
                .buttonStyle(.plain)
                .disabled(taskStore.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(SoftCardBackground(cornerRadius: 14, elevated: true))
    }
    
    private func compactMenu<Label: View, Content: View>(
        help: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Menu { content() } label: {
            label()
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 28, minHeight: 28)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.elevatedBackground(for: colorScheme))
                )
        }
        .menuStyle(.borderlessButton)
        .help(help)
    }
    
    private func addTask() {
        guard !taskStore.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        taskStore.addTask(for: currentFilter)
    }
    
    private var taskListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if currentTasks.isEmpty {
                emptyState
            } else if viewState.selectedScreen == .todayTask {
                if !overdueTasks.isEmpty {
                    taskSection(title: "已逾期", tint: Color(hex: "#EF4444"), tasks: overdueTasks)
                }
                if !dueTodayTasks.isEmpty {
                    taskSection(
                        title: overdueTasks.isEmpty ? "今日待办" : "今天",
                        tint: Color(hex: "#F59E0B"),
                        tasks: dueTodayTasks
                    )
                }
                if !currentTasks.isEmpty {
                    Text("拖拽左侧把手可排序 · 图钉可置顶")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.85))
                        .padding(.top, 4)
                }
            } else if viewState.selectedScreen == .completedTask {
                ForEach(currentTasks) { task in
                    taskRow(task)
                }
            } else {
                reorderableTaskStack(tasks: incompleteFiltered + completedFiltered)
            }
        }
    }
    
    private func taskSection(title: String, tint: Color, tasks: [FocusTask]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                Text("\(tasks.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(tint.opacity(0.12)))
                Spacer()
            }
            .padding(.horizontal, 2)
            
            reorderableTaskStack(tasks: tasks)
        }
    }
    
    /// List + onMove so macOS users can drag-reorder without Edit mode chrome.
    private func reorderableTaskStack(tasks: [FocusTask]) -> some View {
        let incomplete = tasks.filter { !$0.isCompleted }
        let completed = tasks.filter(\.isCompleted)
        return VStack(spacing: 8) {
            if !incomplete.isEmpty {
                List {
                    ForEach(incomplete) { task in
                        taskRow(task)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .onMove { source, dest in
                        taskStore.reorderVisible(
                            incomplete,
                            from: source,
                            to: dest,
                            filter: currentFilter
                        )
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: CGFloat(incomplete.count) * 78)
                .environment(\.defaultMinListRowHeight, 64)
            }
            ForEach(completed) { task in
                taskRow(task)
            }
        }
    }
    
    private func taskRow(_ task: FocusTask) -> some View {
        TaskRowView(
            task: task,
            isActive: taskStore.activeTaskId == task.id,
            isRunning: timerStore.isRunning,
            isSelecting: isSelecting,
            isSelected: selectedIDs.contains(task.id),
            onToggleSelect: {
                if selectedIDs.contains(task.id) {
                    selectedIDs.remove(task.id)
                } else {
                    selectedIDs.insert(task.id)
                }
            },
            onEdit: { editSession = EditTaskSession(task: task) },
            onToggleTimer: { timerStore.toggle() },
            onStartFocus: {
                timerStore.startFocus(on: task.id)
            }
        )
    }
    
    private var emptyState: some View {
        let isCompletedList = viewState.selectedScreen == .completedTask
        return VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.10))
                    .frame(width: 72, height: 72)
                Image(systemName: isCompletedList ? "archivebox" : "tray")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(AppTheme.accent)
            }
            VStack(spacing: 6) {
                Text(isCompletedList ? "暂无已完成任务" : "这里还是空的")
                    .font(.headline)
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                Text(isCompletedList ? "完成任务后会出现在这里" : "在上方添加一条，或去专注钟自由开始")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
            
            if !isCompletedList {
                HStack(spacing: 10) {
                    Button {
                        viewState.selectedScreen = .timer
                    } label: {
                        Label("去专注钟", systemImage: "timer")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    
                    if viewState.selectedScreen != .inboxTask {
                        Button {
                            viewState.selectedScreen = .inboxTask
                        } label: {
                            Label("去收集箱", systemImage: "tray")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .background(SoftCardBackground(cornerRadius: 18))
    }
}
