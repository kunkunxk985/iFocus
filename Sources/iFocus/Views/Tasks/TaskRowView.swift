import SwiftUI
import AppKit
import iFocusCore

// MARK: - Row formatting

private let dueFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "M月d日"
    f.locale = Locale(identifier: "zh_CN")
    return f
}()

private let dueFormatterWithYear: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy年M月d日"
    f.locale = Locale(identifier: "zh_CN")
    return f
}()

/// Crisp Apple-style checkmark path for animated completion drawing
private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX + rect.width * 0.20, y: rect.minY + rect.height * 0.52)
        let vertex = CGPoint(x: rect.minX + rect.width * 0.44, y: rect.minY + rect.height * 0.78)
        let end = CGPoint(x: rect.minX + rect.width * 0.82, y: rect.minY + rect.height * 0.22)
        path.move(to: start)
        path.addLine(to: vertex)
        path.addLine(to: end)
        return path
    }
}

/// Circular checkbox with smooth spring bounce and animated stroke draw
private struct AnimatedTaskCheckbox: View {
    let isCompleted: Bool
    let action: () -> Void

    @State private var bounceScale: CGFloat = 1.0
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            withAnimation(AppTheme.springInteractive) {
                bounceScale = 1.22
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(AppTheme.springInteractive) {
                    bounceScale = 1.0
                }
            }
        }) {
            ZStack {
                Circle()
                    .strokeBorder(
                        isCompleted
                        ? AppTheme.success
                        : AppTheme.secondaryText(for: colorScheme).opacity(0.40),
                        lineWidth: isCompleted ? 1.5 : 1.25
                    )
                    .background(
                        Circle()
                            .fill(
                                isCompleted
                                ? AppTheme.success
                                : (isPressed ? AppTheme.accent.opacity(0.08) : Color.clear)
                            )
                    )
                    .frame(width: 18, height: 18)

                CheckmarkShape()
                    .trim(from: 0, to: isCompleted ? 1.0 : 0.0)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 10, height: 8)
                    .animation(AppTheme.springInteractive, value: isCompleted)
            }
            .frame(width: 24, height: 24)
            .contentShape(Circle())
            .scaleEffect(bounceScale * (isPressed ? 0.92 : 1.0))
            .animation(AppTheme.springInteractive, value: isPressed)
        }
        .buttonStyle(CheckmarkPressButtonStyle(isPressed: $isPressed))
    }
}

private struct CheckmarkPressButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { pressed in
                isPressed = pressed
            }
    }
}

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
    @State private var isHovering = false
    @State private var isGraceCompleted = false
    @State private var isPendingGraceCommit = false
    @State private var graceTimerItem: DispatchWorkItem? = nil

    private func handleCheckboxTap() {
        if task.isCompleted {
            AppHaptics.buttonClick()
            taskStore.toggleCompletion(for: task)
        } else if isGraceCompleted {
            isPendingGraceCommit = false
            graceTimerItem?.cancel()
            graceTimerItem = nil
            withAnimation(AppTheme.springInteractive) {
                isGraceCompleted = false
            }
            AppHaptics.buttonClick()
        } else {
            AppHaptics.taskCompleted()
            if settings.soundEnabled {
                NSSound(named: "Pop")?.play()
            }
            withAnimation(AppTheme.springInteractive) {
                isGraceCompleted = true
            }
            isPendingGraceCommit = true
            let item = DispatchWorkItem { [weak taskStore] in
                guard let taskStore = taskStore else { return }
                guard self.isPendingGraceCommit else { return }
                self.isPendingGraceCommit = false
                self.graceTimerItem = nil
                withAnimation(AppTheme.springInteractive) {
                    taskStore.toggleCompletion(for: task)
                }
                self.isGraceCompleted = false
            }
            graceTimerItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: item)
        }
    }

    private var hasNotes: Bool {
        !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Pin stays visible when pinned; edit + unpinned pin only on hover.
    private var showSecondaryActions: Bool {
        isHovering || task.isPinned || isActive
    }
    
    /// Restrained priority color mapping.
    private var priorityRailColor: Color {
        switch task.priority {
        case 1: return Color.clear
        case 2: return AppTheme.warning
        case 3: return AppTheme.danger
        default: return AppTheme.violet
        }
    }
    
    var body: some View {
        let density = settings.uiDensity
        let completedFade = task.isCompleted || isGraceCompleted
        
        VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .center, spacing: 0) {
            // Restrained Luminous Priority Accent (replaces harsh 3pt colored bar)
            if !completedFade && !isSelecting && task.priority >= 2 {
                Capsule()
                    .fill(priorityRailColor)
                    .frame(width: 2.5, height: density == .compact ? 16 : 20)
                    .padding(.trailing, 6)
                    .help("优先级 \(task.priority)")
            } else {
                Color.clear.frame(width: 2.5).padding(.trailing, 6)
            }

            // Drag Handle (comfortable tactile grip for task reordering with hover feedback)
            if !completedFade && !isSelecting {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: AppTheme.iconAction, weight: .medium))
                    .foregroundColor(
                        isHovering
                        ? AppTheme.secondaryText(for: colorScheme).opacity(0.65)
                        : AppTheme.secondaryText(for: colorScheme).opacity(0.16)
                    )
                    .frame(width: 16, height: 24)
                    .contentShape(Rectangle())
                    .animation(AppTheme.springSnappy, value: isHovering)
                    .help("拖到侧栏改期 · 列表内拖动排序")
                    .accessibilityLabel("拖动任务到侧栏改期，或在列表内排序")
                    .draggable(task.id.uuidString)
                    .padding(.trailing, 4)
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
                    .buttonStyle(SpringScaleButtonStyle())
                    .accessibilityLabel(isSelected ? "取消选择" : "选择任务")
                } else {
                    AnimatedTaskCheckbox(isCompleted: completedFade) {
                        handleCheckboxTap()
                    }
                    .help(completedFade ? "标为未完成" : "标为完成")
                    .accessibilityLabel(completedFade ? "标为未完成" : "标为完成")
                    
                    if !completedFade {
                        focusButton(density: density)
                    }
                }
                
                VStack(alignment: .leading, spacing: density == .compact ? 2 : 4) {
                    // Primary: title + critical flags
                    HStack(spacing: 6) {
                        if task.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                                .help("已置顶")
                        }
                        
                        Text(task.title)
                            .font(TypeScale.rowTitle(compact: density == .compact))
                            .foregroundColor(
                                completedFade
                                ? AppTheme.secondaryText(for: colorScheme).opacity(0.65)
                                : AppTheme.primaryText(for: colorScheme)
                            )
                            .strikethrough(completedFade, color: AppTheme.secondaryText(for: colorScheme).opacity(0.40))
                            .lineLimit(2)
                            .animation(AppTheme.springInteractive, value: completedFade)

                        if isActive && !completedFade {
                            Text(isRunning ? "专注中" : "当前")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isRunning ? AppTheme.accent : AppTheme.secondaryText(for: colorScheme))
                        }

                        if task.isOverdue && !completedFade {
                            Text("逾期")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.danger)
                        }
                        
                        Spacer(minLength: 0)
                    }
                    
                    // Secondary metadata row
                    HStack(spacing: 8) {
                        pomodoroProgress
                        
                        HStack(spacing: 5) {
                            Circle()
                                .fill(task.category.color)
                                .frame(width: 6, height: 6)
                            Text(task.category.name)
                        }
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))

                        if task.recurrence != .none {
                            HStack(spacing: 3) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(task.recurrence.rawValue)
                            }
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        }
                        
                        if hasNotes {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: AppTheme.iconMeta, weight: .medium))
                                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.55))
                                .help(task.notes)
                        }
                        
                        if task.hasLink {
                            Button(action: openTaskLink) {
                                Image(systemName: "link")
                                    .font(.system(size: AppTheme.iconMeta, weight: .medium))
                                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .help(task.linkURL)
                        }
                        
                        if let due = task.dueDate {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.system(size: AppTheme.iconMeta, weight: .semibold))
                                Text(dueLabel(for: due))
                                    .font(TypeScale.meta.monospacedDigit())
                            }
                            .foregroundColor(
                                task.isOverdue && !task.isCompleted
                                ? AppTheme.danger.opacity(0.88)
                                : AppTheme.secondaryText(for: colorScheme).opacity(0.65)
                            )
                        }

                        Spacer(minLength: 0)

                        if !completedFade && !isSelecting {
                            secondaryActionButtons
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(completedFade ? 0.72 : 1)
            }
        }
        }
        .padding(.leading, density == .compact ? 8 : 10)
        .padding(.trailing, density == .compact ? 10 : 12)
        .padding(.vertical, density.rowVerticalPadding)
        .background(rowBackground)
        .contentShape(AppTheme.squircle(radius: AppTheme.radiusM))
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) {
            if !isSelecting { onEdit() }
        }
        .simultaneousGesture(TapGesture().onEnded {
            if isSelecting { onToggleSelect?() }
        })
        .contextMenu { if !isSelecting { contextMenuContent } }
        .opacity(isSelecting && !isSelected ? 0.88 : 1)
        .animation(AppTheme.springInteractive, value: isHovering)
        .onDisappear {
            if isPendingGraceCommit {
                isPendingGraceCommit = false
                graceTimerItem?.cancel()
                graceTimerItem = nil
                taskStore.toggleCompletion(for: task)
            }
        }
    }

    private func focusButton(density: UIDensity) -> some View {
        Button(action: handleFocusButton) {
            ZStack {
                if isActive && isRunning {
                    Circle()
                        .strokeBorder(AppTheme.accent.opacity(0.40), lineWidth: 1.5)
                        .frame(width: 25 * density.scale, height: 25 * density.scale)
                }
                Circle()
                    .fill(
                        isActive
                        ? AppTheme.accent
                        : AppTheme.elevatedBackground(for: colorScheme)
                    )
                    .frame(width: 22 * density.scale, height: 22 * density.scale)
                    .overlay(
                        Circle().strokeBorder(
                            isActive ? Color.clear : AppTheme.separatorLow(for: colorScheme),
                            lineWidth: 0.75
                        )
                    )
                Image(systemName: focusButtonIcon)
                    .font(.system(size: AppTheme.iconMeta, weight: .bold))
                    .foregroundColor(isActive ? .white : AppTheme.secondaryText(for: colorScheme))
            }
            .frame(width: 25 * density.scale, height: 25 * density.scale)
        }
        .buttonStyle(SpringScaleButtonStyle())
        .help(focusButtonHelp)
        .accessibilityLabel(focusButtonHelp)
    }

    private var secondaryActionButtons: some View {
        HStack(spacing: 3) {
            Button {
                taskStore.togglePin(for: task)
            } label: {
                Image(systemName: task.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: AppTheme.iconAction, weight: .medium))
                    .foregroundColor(
                        task.isPinned
                        ? AppTheme.accent
                        : AppTheme.secondaryText(for: colorScheme).opacity(0.60)
                    )
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(task.isPinned ? AppTheme.accent.opacity(0.12) : AppTheme.elevatedBackground(for: colorScheme).opacity(isHovering ? 0.8 : 0))
                    )
            }
            .buttonStyle(SpringScaleButtonStyle())
            .help(task.isPinned ? "取消置顶" : "置顶")
            .accessibilityLabel(task.isPinned ? "取消置顶" : "置顶")
            .opacity(task.isPinned || isHovering || isActive ? 1 : 0)

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: AppTheme.iconAction, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.60))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(AppTheme.elevatedBackground(for: colorScheme).opacity(isHovering ? 0.8 : 0))
                    )
            }
            .buttonStyle(SpringScaleButtonStyle())
            .help("编辑（也可双击）")
            .accessibilityLabel("编辑任务")
            .opacity(isHovering || isActive ? 1 : 0)

            Menu {
                Section("移到") {
                    Button("今天") { taskStore.moveTask(id: task.id, to: .todayTask) }
                    Button("明天") { taskStore.moveTask(id: task.id, to: .tomorrowTask) }
                    Button("收集箱") { taskStore.moveTask(id: task.id, to: .inboxTask) }
                }
                Menu("优先级") {
                    ForEach(1...4, id: \.self) { priority in
                        Button {
                            taskStore.updatePriority(for: task, to: priority)
                        } label: {
                            Text("\(priority) 级")
                            if task.priority == priority { Image(systemName: "checkmark") }
                        }
                    }
                }
                Divider()
                Button("删除任务", role: .destructive) {
                    taskStore.deleteTask(task)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: AppTheme.iconAction, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.60))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(AppTheme.elevatedBackground(for: colorScheme).opacity(isHovering ? 0.8 : 0))
                    )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("更多操作")
            .accessibilityLabel("更多任务操作")
            .opacity(isHovering || isActive ? 1 : 0)
        }
        .animation(AppTheme.springSnappy, value: isHovering)
        .allowsHitTesting(task.isPinned || isHovering || isActive)
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
        let sameYear = calendar.component(.year, from: due) == calendar.component(.year, from: Date())
        return (sameYear ? dueFormatter : dueFormatterWithYear).string(from: due)
    }
    
    private var pomodoroProgress: some View {
        HStack(spacing: 3) {
            Image(systemName: "timer")
                .font(.system(size: AppTheme.iconMeta, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.55))
            if task.completedPomodoros > task.estimatedPomodoros {
                Text("+\(task.completedPomodoros - task.estimatedPomodoros)")
                    .font(TypeScale.meta.monospacedDigit())
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.7))
            } else if task.estimatedPomodoros > 0 {
                Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                    .font(TypeScale.meta.monospacedDigit())
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.65))
            }
        }
    }
    
    private var rowBackground: some View {
        let selected = isSelecting && isSelected
        let emphasized = selected || isActive
        let fill: Color
        if selected {
            fill = AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.16)
        } else if isActive {
            fill = AppTheme.accent.opacity(colorScheme == .light ? 0.055 : 0.10)
        } else if isHovering {
            fill = AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.96 : 0.86)
        } else {
            // Resting rows stay quiet: no shadow, a barely-there surface.
            fill = AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.68 : 0.60)
        }
        let stroke: Color
        if emphasized {
            stroke = AppTheme.accent.opacity(selected ? 0.34 : 0.24)
        } else if isHovering {
            stroke = AppTheme.separator(for: colorScheme)
        } else {
            stroke = AppTheme.separatorLow(for: colorScheme).opacity(0.7)
        }
        return AppTheme.squircle(radius: AppTheme.radiusM)
            .fill(fill)
            .overlay(
                AppTheme.squircle(radius: AppTheme.radiusM)
                    .strokeBorder(stroke, lineWidth: 1)
            )
            .overlay(
                AppTheme.squircle(radius: AppTheme.radiusM)
                    .strokeBorder(
                        AppTheme.cardInnerHighlight(for: colorScheme),
                        lineWidth: isHovering || emphasized ? 0.75 : 0
                    )
            )
            .shadow(
                color: isHovering || emphasized ? AppTheme.softShadow(for: colorScheme) : .clear,
                radius: isHovering ? 8 : 4,
                y: 2
            )
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.16), value: selected)
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button(action: handleFocusButton) {
            Label(focusButtonHelp, systemImage: focusButtonIcon)
        }
        
        Button {
            if !task.isCompleted {
                AppHaptics.taskCompleted()
                if settings.soundEnabled {
                    NSSound(named: "Pop")?.play()
                }
            } else {
                AppHaptics.buttonClick()
            }
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
            ForEach(taskStore.allCategories) { category in
                Button {
                    taskStore.updateCategory(for: task, to: category)
                } label: {
                    HStack {
                        Label(category.name, systemImage: category.icon)
                        if task.category.id == category.id { Image(systemName: "checkmark") }
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
