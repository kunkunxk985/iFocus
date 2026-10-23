import SwiftUI
import iFocusCore

/// In-list refinement chips (orthogonal to sidebar smart lists).
private enum TaskListChip: Hashable, Identifiable {
    case all
    case highPriority
    case pinned
    case hasNotes
    case hasLink
    case category(TaskCategory)
    
    var id: String {
        switch self {
        case .all: return "all"
        case .highPriority: return "high"
        case .pinned: return "pinned"
        case .hasNotes: return "notes"
        case .hasLink: return "link"
        case .category(let c): return "cat-\(c.id)"
        }
    }
    
    var title: String {
        switch self {
        case .all: return "全部"
        case .highPriority: return "高优"
        case .pinned: return "置顶"
        case .hasNotes: return "有备注"
        case .hasLink: return "有链接"
        case .category(let c): return c.name
        }
    }
}

struct TaskListView: View {
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var viewState: ContentViewState
    @Environment(\.colorScheme) private var colorScheme
    /// One sheet per screen; edit sessions keep a stable snapshot identity.
    private enum TaskListSheet: Identifiable {
        case edit(EditTaskSession)
        case categories

        var id: String {
            switch self {
            case .edit(let session): return "edit-\(session.id)"
            case .categories: return "categories"
            }
        }
    }

    @State private var activeSheet: TaskListSheet? = nil
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var activeChip: TaskListChip = .all
    @FocusState private var isQuickAddFocused: Bool
    @FocusState private var isSearchFocused: Bool
    @State private var searchText = ""
    /// nil = follow current list defaults; else force today / tomorrow / inbox.
    @State private var dueOverride: TaskStore.DueOverride? = nil
    @State private var listViewportHeight: CGFloat = 640
    
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
        case .weekTask: return "稍后"
        case .plannedTask: return "已计划"
        case .completedTask: return "已完成"
        case .inboxTask: return "收集箱"
        default: return "待办任务"
        }
    }
    
    /// Count, plus a range note on 稍后 so the list is not mistaken for this calendar week.
    private var listSubtitle: String {
        if viewState.selectedScreen == .weekTask {
            let count = incompleteFiltered.count
            return count == 0 ? "后天到 7 天内" : "\(count) 待办 · 后天到 7 天内"
        }
        if baseTasks.isEmpty {
            return ""
        }
        // One quiet line — count only (no multi-metric stack under the title).
        if viewState.selectedScreen == .completedTask {
            return "\(completedFiltered.count) 项"
        }
        if viewState.selectedScreen == .todayTask, !overdueTasks.isEmpty {
            return "\(incompleteFiltered.count) 待办 · \(overdueTasks.count) 逾期"
        }
        return "\(incompleteFiltered.count) 待办"
    }
    
    private var listIcon: String {
        switch viewState.selectedScreen {
        case .todayTask: return "sun.max"
        case .tomorrowTask: return "sunrise"
        case .weekTask: return "clock"
        case .plannedTask: return "calendar.badge.clock"
        case .completedTask: return "checkmark.circle"
        case .inboxTask: return "tray"
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
        case .weekTask: return "添加稍后的任务，回车保存"
        case .plannedTask: return "添加计划任务，回车保存"
        case .inboxTask: return "先丢进收集箱…"
        default: return "添加任务，回车保存"
        }
    }
    
    private var baseTasks: [FocusTask] {
        taskStore.tasks(for: currentFilter)
    }
    
    private var currentTasks: [FocusTask] {
        baseTasks.filter { matchesChip($0) && matchesSearch($0) }
    }

    private func matchesSearch(_ task: FocusTask) -> Bool {
        TaskSearch.matches(
            searchText,
            in: [task.title, task.notes, task.category.name, task.linkURL, task.recurrence.rawValue]
                + task.checklist.flatMap { [$0.title, $0.note ?? ""] }
        )
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
    
    private var availableChips: [TaskListChip] {
        // Only chips that match something — hide empty filters (less chrome).
        var chips: [TaskListChip] = [.all]
        let candidates: [TaskListChip] = [.highPriority, .pinned, .hasNotes, .hasLink]
        for chip in candidates where chipCount(chip) > 0 {
            chips.append(chip)
        }
        // Categories appear only when the current list actually contains one.
        for cat in taskStore.allCategories where chipCount(.category(cat)) > 0 {
            chips.append(.category(cat))
        }
        return chips
    }
    
    private func matchesChip(_ task: FocusTask) -> Bool {
        switch activeChip {
        case .all:
            return true
        case .highPriority:
            // Higher number = higher urgency (matches sort + priorityColor).
            return task.priority >= 3
        case .pinned:
            return task.isPinned
        case .hasNotes:
            return !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .hasLink:
            return task.hasLink
        case .category(let cat):
            return task.category.id == cat.id
        }
    }
    
    private func chipCount(_ chip: TaskListChip) -> Int {
        baseTasks.filter { task in
            switch chip {
            case .all: return true
            case .highPriority: return task.priority >= 3
            case .pinned: return task.isPinned
            case .hasNotes: return !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .hasLink: return task.hasLink
            case .category(let cat): return task.category.id == cat.id
            }
        }.count
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
                        listTools
                    }

                    if !baseTasks.isEmpty || !searchText.isEmpty || isSearchFocused {
                        taskSearchField
                            .padding(.top, 12)
                    }

                    if isSelecting {
                        batchToolbar
                            .padding(.bottom, 12)
                    }

                    if viewState.selectedScreen != .completedTask, !isSelecting {
                        addTaskSection
                            .padding(.bottom, 16)
                    }

                    taskListSection
                        .padding(.bottom, timerStore.isSessionInProgress ? 96 : 32)
                }
            }
            .softScroll()
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { listViewportHeight = geo.size.height }
                        .onChange(of: geo.size.height) { listViewportHeight = $0 }
                }
            )
        }
        .overlay(alignment: .bottom) {
            if let banner = taskStore.undoDeletionBanner {
                UndoDeletionToast(
                    message: banner.message,
                    onUndo: { taskStore.undoLastDeletion() },
                    onDismiss: { taskStore.dismissUndoDeletionBanner() }
                )
                // Sit above the floating focus pill when a session is in progress off-timer.
                .padding(.bottom, timerStore.isSessionInProgress ? 88 : 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(40)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: taskStore.undoDeletionBanner?.token)
        .onChange(of: viewState.selectedScreen) { _ in
            isSelecting = false
            selectedIDs.removeAll()
            activeChip = .all
            dueOverride = nil
            searchText = ""
            isSearchFocused = false
        }
        .onChange(of: activeChip) { _ in
            // Avoid deleting off-screen tasks that were selected under another chip.
            selectedIDs = selectedIDs.intersection(Set(currentTasks.map(\.id)))
        }
        .onChange(of: baseTasks.map(\.id)) { _ in
            // Category chip may disappear when no tasks left in that category.
            if !availableChips.contains(where: { $0.id == activeChip.id }) {
                activeChip = .all
            }
        }
        .onChange(of: taskStore.allCategories) { _ in
            // A renamed category keeps working by id; a deleted one falls back to 全部.
            if !availableChips.contains(where: { $0.id == activeChip.id }) {
                activeChip = .all
            }
        }
        // Snapshot identity (`EditTaskSession`) — never `sheet(item:)` a live FocusTask
        // that mutates while the timer is running.
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .edit(let session):
                EditTaskView(session: session, categories: taskStore.allCategories) { title, category, priority, pomodoros, due, recurrence, notes, linkURL in
                    taskStore.updateTask(
                        id: session.id,
                        title: title,
                        category: category,
                        priority: priority,
                        estimatedPomodoros: pomodoros,
                        dueDate: due,
                        recurrence: recurrence,
                        notes: notes,
                        linkURL: linkURL
                    )
                }
                // Force full re-init of @State when reopening the same task after save.
                .id("\(session.id)-\(session.notes)-\(session.linkURL)-\(session.title)-\(session.priority)")
            case .categories:
                CategoryManagementView()
                    .environmentObject(taskStore)
            }
        }
        .onExitCommand {
            if isSelecting {
                withAnimation(AppTheme.springInteractive) {
                    isSelecting = false
                    selectedIDs.removeAll()
                }
            } else if isSearchFocused {
                isSearchFocused = false
            } else if isQuickAddFocused {
                isQuickAddFocused = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppNavigation.newTask)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                isQuickAddFocused = true
            }
        }
        .onAppear {
            if viewState.shouldFocusQuickAdd {
                viewState.shouldFocusQuickAdd = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isQuickAddFocused = true
                }
            }
        }
        .onChange(of: viewState.shouldFocusQuickAdd) { shouldFocus in
            if shouldFocus {
                viewState.shouldFocusQuickAdd = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isQuickAddFocused = true
                }
            }
        }
        .onAppear {
            if viewState.shouldFocusSearch {
                viewState.shouldFocusSearch = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            }
        }
        .onChange(of: viewState.shouldFocusSearch) { shouldFocus in
            if shouldFocus {
                viewState.shouldFocusSearch = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isSearchFocused = true
                }
            }
        }
    }

    private var taskSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.78))
            TextField("搜索标题、备注、分类或链接", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($isSearchFocused)
                .accessibilityLabel("搜索当前任务列表")
                .accessibilityHint("搜索任务标题、备注、分类、链接和重复周期")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.72))
                }
                .buttonStyle(.plain)
                .help("清除搜索")
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(
            Capsule().fill(AppTheme.cardBackground(for: colorScheme))
        )
        .overlay(
            Capsule().strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
        )
        .overlay(
            Capsule().strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 0.75)
        )
        .frame(maxWidth: 360, alignment: .leading)
        .help("搜索当前列表中的标题、备注、分类或链接（⌘F）")
    }
    
    /// Quiet actions beside the title. Filters live in one menu so they don't
    /// become a second row of navigation under the sidebar.
    private var listTools: some View {
        HStack(spacing: 14) {
            if availableChips.count > 1 {
                Menu {
                    ForEach(availableChips) { chip in
                        Button {
                            activeChip = chip
                        } label: {
                            if activeChip.id == chip.id {
                                Label("\(chip.title)  \(chipCount(chip))", systemImage: "checkmark")
                            } else {
                                Text("\(chip.title)  \(chipCount(chip))")
                            }
                        }
                    }
                    Divider()
                    Button("管理分类…") {
                        activeSheet = .categories
                    }
                } label: {
                    Text(activeChip.id == TaskListChip.all.id ? "筛选" : activeChip.title)
                        .font(.system(size: 12, weight: activeChip.id == TaskListChip.all.id ? .medium : .semibold))
                        .foregroundColor(
                            activeChip.id == TaskListChip.all.id
                            ? AppTheme.secondaryText(for: colorScheme)
                            : AppTheme.accent
                        )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("筛选当前列表")
            }

            if !currentTasks.isEmpty || isSelecting {
                Button(isSelecting ? "完成" : "批量") {
                    withAnimation(AppTheme.springInteractive) {
                        isSelecting.toggle()
                        if !isSelecting { selectedIDs.removeAll() }
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
        }
    }

    private var batchToolbar: some View {
        let isCompletedList = viewState.selectedScreen == .completedTask
        return VStack(alignment: .leading, spacing: 10) {
            Text(selectedIDs.isEmpty ? "点选任务进行批量操作" : "已选 \(selectedIDs.count) 项")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            
            HStack(spacing: 8) {
                batchButton("全选") {
                    selectedIDs = Set(currentTasks.map(\.id))
                }
                if isCompletedList {
                    batchButton("标为未完成") {
                        for id in selectedIDs {
                            if let t = taskStore.tasks.first(where: { $0.id == id }), t.isCompleted {
                                taskStore.toggleCompletion(for: t)
                            }
                        }
                        selectedIDs.removeAll()
                    }
                    .disabled(selectedIDs.isEmpty)
                } else {
                    batchButton("完成") {
                        AppHaptics.taskCompleted()
                        if settings.soundEnabled {
                            NSSound(named: "Pop")?.play()
                        }
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
                }
                batchButton("删除", destructive: true) {
                    taskStore.deleteTasks(ids: selectedIDs)
                    selectedIDs.removeAll()
                }
                .disabled(selectedIDs.isEmpty)
                Spacer()
            }

            // Hidden keyboard shortcut triggers for batch mode
            Group {
                Button("") {
                    selectedIDs = Set(currentTasks.map(\.id))
                }
                .keyboardShortcut("a", modifiers: .command)

                Button("") {
                    if !selectedIDs.isEmpty {
                        taskStore.deleteTasks(ids: selectedIDs)
                        selectedIDs.removeAll()
                    }
                }
                .keyboardShortcut(.delete, modifiers: [])

                Button("") {
                    if !selectedIDs.isEmpty {
                        taskStore.deleteTasks(ids: selectedIDs)
                        selectedIDs.removeAll()
                    }
                }
                .keyboardShortcut(.deleteForward, modifiers: [])

                Button("") {
                    withAnimation(AppTheme.springInteractive) {
                        isSelecting = false
                        selectedIDs.removeAll()
                    }
                }
                .keyboardShortcut(.cancelAction)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .fill(AppTheme.elevatedBackground(for: colorScheme).opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
        )
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
        .tint(destructive ? AppTheme.danger : AppTheme.accent)
    }
    
    private var addTaskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            taskStore.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? AppTheme.elevatedBackground(for: colorScheme)
                            : AppTheme.accent.opacity(colorScheme == .light ? 0.12 : 0.20)
                        )
                        .frame(width: 26, height: 26)
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(
                            taskStore.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? AppTheme.secondaryText(for: colorScheme).opacity(0.60)
                            : AppTheme.accent
                        )
                }
                .animation(AppTheme.springInteractive, value: taskStore.newTaskTitle.isEmpty)
                
                TextField(placeholderText, text: $taskStore.newTaskTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5, weight: .regular))
                    .focused($isQuickAddFocused)
                    .onExitCommand {
                        isQuickAddFocused = false
                    }
                    .onSubmit { addTask(openEditor: false) }
                
                HStack(spacing: 7) {
                    taskOptionsMenu
                    
                    Button(action: { addTask(openEditor: false) }) {
                        HStack(spacing: 3.5) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("添加")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5.5)
                        .background(
                            Capsule()
                                .fill(
                                    taskStore.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? AppTheme.accent.opacity(0.35)
                                    : AppTheme.accent
                                )
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(SpringScaleButtonStyle())
                    .disabled(taskStore.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("回车添加任务")
                    
                    Button(action: { addTask(openEditor: true) }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(
                                taskStore.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? AppTheme.secondaryText(for: colorScheme).opacity(0.35)
                                : AppTheme.accent
                            )
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(AppTheme.elevatedBackground(for: colorScheme).opacity(0.75))
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.75)
                            )
                    }
                    .buttonStyle(SpringScaleButtonStyle())
                    .disabled(taskStore.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("添加并打开详情编辑 (备注/链接)")
                }
            }
            
            // Due date shortcuts — integrated secondary shelf
            HStack(spacing: 6) {
                HStack(spacing: 3.5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9.5, weight: .medium))
                    Text("日期")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.70))
                .padding(.trailing, 2)

                dueChip(title: "跟随列表", override: nil)
                dueChip(title: "今天", override: .today)
                dueChip(title: "明天", override: .tomorrow)
                dueChip(title: "收集箱", override: .inbox)
                Spacer(minLength: 0)
            }
            .padding(.leading, 3)
            .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            AppTheme.squircle(radius: AppTheme.radiusCard)
                .fill(AppTheme.cardBackground(for: colorScheme))
        )
        .overlay(
            AppTheme.squircle(radius: AppTheme.radiusCard)
                .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
        )
        .overlay(
            AppTheme.squircle(radius: AppTheme.radiusCard)
                .strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 1)
        )
        .multiLayerShadow(elevation: .card, colorScheme: colorScheme)
    }

    private var taskOptionsMenu: some View {
        Menu {
            Section("任务属性") {
                newTaskCategoryButton(.study)
                Menu("更多分类") {
                    ForEach(taskStore.allCategories.filter { $0.id != TaskCategory.study.id }) { category in
                        newTaskCategoryButton(category)
                    }
                    Divider()
                    Button {
                        activeSheet = .categories
                    } label: {
                        Label("管理分类…", systemImage: "slider.horizontal.3")
                    }
                }
                Picker("优先级", selection: $taskStore.newTaskPriority) {
                    ForEach(1...4, id: \.self) { priority in
                        Text("\(priority) 级").tag(priority)
                    }
                }
            }
            Section("计划") {
                Picker("预估番茄", selection: $taskStore.newTaskPomodoros) {
                    ForEach(1...8, id: \.self) { count in
                        Text("\(count) 番茄").tag(count)
                    }
                }
                Picker("重复", selection: $taskStore.newTaskRecurrence) {
                    ForEach(TaskRecurrence.allCases) { recurrence in
                        Text(recurrence.rawValue).tag(recurrence)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                Image(systemName: taskStore.newTaskCategory.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(taskStore.newTaskCategory.color)
                Text(taskStore.newTaskCategory.name)
                    .lineLimit(1)
                Image(systemName: "timer")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                Text("\(taskStore.newTaskPomodoros)")
                    .monospacedDigit()
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(AppTheme.primaryText(for: colorScheme).opacity(0.86))
            .padding(.horizontal, 9)
            .padding(.vertical, 5.5)
            .background(
                Capsule().fill(AppTheme.elevatedBackground(for: colorScheme).opacity(0.78))
            )
            .overlay(
                Capsule().strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.75)
            )
            .overlay(
                Capsule().strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(SpringScaleButtonStyle(pressedScale: 0.96))
        .help("设置新任务的分类、优先级、预估番茄数和重复周期")
        .accessibilityLabel(
            "任务属性设置：\(taskStore.newTaskCategory.name)，\(taskStore.newTaskPriority) 级优先级，\(taskStore.newTaskPomodoros) 个番茄，\(taskStore.newTaskRecurrence.rawValue)"
        )
    }
    
    /// Menu row that picks the quick-add category (checkmark on the current one).
    private func newTaskCategoryButton(_ category: TaskCategory) -> some View {
        Button {
            taskStore.newTaskCategory = category
        } label: {
            if taskStore.newTaskCategory.id == category.id {
                Label(category.name, systemImage: "checkmark")
            } else {
                Label(category.name, systemImage: category.icon)
            }
        }
    }

    private func dueChip(title: String, override: TaskStore.DueOverride?) -> some View {
        let selected = dueOverride == override
        return Button {
            withAnimation(AppTheme.springInteractive) {
                dueOverride = override
            }
        } label: {
            HStack(spacing: 3) {
                if selected {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 4, height: 4)
                }
                Text(title)
                    .font(.system(size: 11, weight: selected ? .semibold : .medium))
                    .foregroundColor(
                        selected
                        ? AppTheme.accent
                        : AppTheme.secondaryText(for: colorScheme).opacity(0.85)
                    )
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 3.5)
            .background(
                Capsule()
                    .fill(
                        selected
                        ? AppTheme.accent.opacity(colorScheme == .light ? 0.12 : 0.20)
                        : AppTheme.elevatedBackground(for: colorScheme).opacity(0.6)
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        selected
                        ? AppTheme.accent.opacity(0.25)
                        : AppTheme.separatorLow(for: colorScheme),
                        lineWidth: 0.75
                    )
            )
        }
        .buttonStyle(SpringScaleButtonStyle(pressedScale: 0.96))
    }
    
    private func addTask(openEditor: Bool) {
        guard !taskStore.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let id = taskStore.addTask(for: currentFilter, dueOverride: dueOverride) else { return }
        if openEditor, let task = taskStore.tasks.first(where: { $0.id == id }) {
            activeSheet = .edit(EditTaskSession(task: task))
        }
    }
    
    /// Push an empty list into the middle of the page, under the title and composer.
    private var emptyStateMinHeight: CGFloat {
        let chrome: CGFloat = viewState.selectedScreen == .completedTask ? 140 : 280
        return max(240, listViewportHeight - chrome)
    }

    private var taskListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if currentTasks.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, minHeight: emptyStateMinHeight, alignment: .center)
            } else if viewState.selectedScreen == .todayTask {
                if !overdueTasks.isEmpty {
                    taskSection(title: "已逾期", tint: AppTheme.danger, tasks: overdueTasks)
                }
                if !dueTodayTasks.isEmpty {
                    taskSection(
                        title: overdueTasks.isEmpty ? "今日待办" : "今天",
                        tint: AppTheme.warning,
                        tasks: dueTodayTasks
                    )
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
                    .font(.system(size: 11.5, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.75))
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
                // Outer Page ScrollView owns scrolling — avoid nested scroll fight.
                .scrollDisabled(true)
                // Row budget ≈ content + vertical padding + card gap (tuned vs TaskRowView).
                .frame(minHeight: CGFloat(incomplete.count) * (settings.uiDensity == .compact ? 58 : 68))
                .environment(\.defaultMinListRowHeight, settings.uiDensity == .compact ? 48 : 56)
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
            onEdit: { activeSheet = .edit(EditTaskSession(task: task)) },
            onToggleTimer: { timerStore.toggle() },
            onStartFocus: {
                timerStore.startFocus(on: task.id)
            }
        )
    }
    
    private var emptyState: some View {
        let isCompletedList = viewState.selectedScreen == .completedTask
        let isToday = viewState.selectedScreen == .todayTask
        let isLater = viewState.selectedScreen == .weekTask
        let filteredEmpty = !baseTasks.isEmpty && currentTasks.isEmpty

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && currentTasks.isEmpty {
            return AnyView(
                AppEmptyState(
                    systemImage: "magnifyingglass",
                    title: "未找到相关任务",
                    actionTitle: "清除搜索",
                    action: { searchText = "" }
                )
                .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
            )
        }

        if filteredEmpty {
            return AnyView(
                AppEmptyState(
                    systemImage: "line.3.horizontal.decrease.circle",
                    title: "没有匹配的任务",
                    actionTitle: "显示全部",
                    action: { activeChip = .all }
                )
                .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
            )
        }

        if isCompletedList {
            return AnyView(
                AppEmptyState(
                    systemImage: "checkmark.circle",
                    title: "还没有完成记录",
                    actionTitle: "去今天",
                    action: { viewState.selectedScreen = .todayTask }
                )
                .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
            )
        }

        return AnyView(
            AppEmptyState(
                systemImage: isToday ? "sun.max" : (isLater ? "clock" : "tray"),
                title: isToday ? "今天还没有任务" : (isLater ? "稍后还没有任务" : "还没有任务"),
                actionTitle: "添加任务",
                action: { DispatchQueue.main.async { isQuickAddFocused = true } },
                secondaryActionTitle: "开始专注",
                secondaryAction: { viewState.selectedScreen = .timer }
            )
            .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
        )
    }
}


// MARK: - Undo toast

private struct UndoDeletionToast: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: String
    let onUndo: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "trash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
            Spacer(minLength: 8)
            Button("撤销", action: onUndo)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .controlSize(.small)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.cardBackground(for: colorScheme))
                .shadow(color: AppTheme.softShadow(for: colorScheme), radius: 18, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
        )
    }
}
