import SwiftUI
import AppKit

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
                        ? Color(hex: "#10B981")
                        : AppTheme.secondaryText(for: colorScheme).opacity(0.40),
                        lineWidth: isCompleted ? 1.5 : 1.25
                    )
                    .background(
                        Circle()
                            .fill(
                                isCompleted
                                ? Color(hex: "#10B981")
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
        case 2: return Color(hex: "#F59E0B")
        case 3: return Color(hex: "#EF4444")
        default: return Color(hex: "#8B5CF6")
        }
    }
    
    var body: some View {
        let density = settings.uiDensity
        let completedFade = task.isCompleted || isGraceCompleted
        
        HStack(alignment: .center, spacing: 0) {
            // Restrained Luminous Priority Accent (replaces harsh 3pt colored bar)
            if !completedFade && !isSelecting && task.priority >= 2 {
                Capsule()
                    .fill(priorityRailColor)
                    .frame(width: 2.5, height: density == .compact ? 16 : 20)
                    .shadow(color: priorityRailColor.opacity(0.45), radius: 2.5, x: 0, y: 0)
                    .padding(.trailing, 6)
                    .help("优先级 \(task.priority)")
            } else {
                Color.clear.frame(width: 2.5).padding(.trailing, 6)
            }

            // Drag Handle (comfortable tactile grip for task reordering with hover feedback)
            if !completedFade && !isSelecting {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(
                        isHovering
                        ? AppTheme.secondaryText(for: colorScheme).opacity(0.75)
                        : AppTheme.secondaryText(for: colorScheme).opacity(0.22)
                    )
                    .frame(width: 14, height: 22)
                    .contentShape(Rectangle())
                    .animation(AppTheme.springSnappy, value: isHovering)
                    .help("拖拽可重新排序")
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
                } else {
                    AnimatedTaskCheckbox(isCompleted: completedFade) {
                        handleCheckboxTap()
                    }
                    .help(completedFade ? "标为未完成" : "标为完成")
                    
                    if !completedFade {
                        focusButton(density: density)
                    }
                }
                
                VStack(alignment: .leading, spacing: density == .compact ? 2 : 4) {
                    // Primary: title + critical flags
                    HStack(spacing: 6) {
                        if task.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(AppTheme.accent.opacity(0.85))
                                .help("已置顶")
                        }
                        
                        Text(task.title)
                            .font(.system(size: density == .compact ? 13.5 : 14.5, weight: .medium))
                            .foregroundColor(
                                completedFade
                                ? AppTheme.secondaryText(for: colorScheme).opacity(0.65)
                                : AppTheme.primaryText(for: colorScheme)
                            )
                            .strikethrough(completedFade, color: AppTheme.secondaryText(for: colorScheme).opacity(0.40))
                            .lineLimit(2)
                            .animation(AppTheme.springInteractive, value: completedFade)

                        // Refined priority micro-tag
                        if task.priority >= 2 && !completedFade {
                            HStack(spacing: 3) {
                                Image(systemName: priorityIcon(task.priority))
                                    .font(.system(size: 8.5, weight: .bold))
                                Text("\(task.priority) 级")
                                    .font(TypeScale.eyebrow)
                            }
                            .foregroundColor(priorityColor(task.priority))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(priorityColor(task.priority).opacity(colorScheme == .light ? 0.10 : 0.18))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(priorityColor(task.priority).opacity(colorScheme == .light ? 0.20 : 0.30), lineWidth: 0.75)
                            )
                        }
                        
                        if isActive && !completedFade {
                            Text(isRunning ? "专注中" : "当前")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(AppTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppTheme.accent.opacity(colorScheme == .light ? 0.12 : 0.20)))
                                .overlay(
                                    Capsule().strokeBorder(AppTheme.accent.opacity(0.25), lineWidth: 0.75)
                                )
                        }
                        
                        if task.isOverdue && !completedFade {
                            Text("逾期")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(Color(hex: "#EF4444"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(hex: "#EF4444").opacity(colorScheme == .light ? 0.10 : 0.18)))
                                .overlay(
                                    Capsule().strokeBorder(Color(hex: "#EF4444").opacity(0.25), lineWidth: 0.75)
                                )
                        }
                        
                        Spacer(minLength: 0)
                    }
                    
                    // Secondary metadata row
                    HStack(spacing: 8) {
                        pomodoroProgress
                        
                        HStack(spacing: 3) {
                            Image(systemName: task.category.icon)
                                .font(.system(size: 8.5, weight: .semibold))
                            Text(task.category.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(task.category.color.opacity(0.85))
                        
                        if task.recurrence != .none {
                            HStack(spacing: 3) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 8.5, weight: .semibold))
                                Text(task.recurrence.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(Color(hex: "#8B5CF6").opacity(0.85))
                        }
                        
                        if hasNotes {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.55))
                                .help(task.notes)
                        }
                        
                        if task.hasLink {
                            Button(action: openTaskLink) {
                                Image(systemName: "link")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(AppTheme.accent.opacity(0.80))
                            }
                            .buttonStyle(.plain)
                            .help(task.linkURL)
                        }
                        
                        if let due = task.dueDate {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 8.5, weight: .semibold))
                                Text(dueLabel(for: due))
                                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                            }
                            .foregroundColor(
                                task.isOverdue && !task.isCompleted
                                ? Color(hex: "#EF4444").opacity(0.88)
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
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(isActive ? .white : AppTheme.secondaryText(for: colorScheme))
            }
            .frame(width: 25 * density.scale, height: 25 * density.scale)
        }
        .buttonStyle(SpringScaleButtonStyle())
        .help(focusButtonHelp)
    }

    private var secondaryActionButtons: some View {
        HStack(spacing: 3) {
            Button {
                taskStore.togglePin(for: task)
            } label: {
                Image(systemName: task.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(
                        task.isPinned
                        ? AppTheme.accent
                        : AppTheme.secondaryText(for: colorScheme).opacity(0.60)
                    )
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(task.isPinned ? AppTheme.accent.opacity(0.12) : AppTheme.elevatedBackground(for: colorScheme).opacity(isHovering ? 0.8 : 0))
                    )
            }
            .buttonStyle(SpringScaleButtonStyle())
            .help(task.isPinned ? "取消置顶" : "置顶")
            .opacity(task.isPinned || isHovering || isActive ? 1 : 0)

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.60))
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(AppTheme.elevatedBackground(for: colorScheme).opacity(isHovering ? 0.8 : 0))
                    )
            }
            .buttonStyle(SpringScaleButtonStyle())
            .help("编辑（也可双击）")
            .opacity(isHovering || isActive ? 1 : 0)
        }
        .animation(AppTheme.springSnappy, value: isHovering)
        .allowsHitTesting(showSecondaryActions)
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
        let isOverdue = task.isOverdue && !task.isCompleted
        return AppTheme.squircle(radius: AppTheme.radiusM)
            .fill(
                isActive
                ? AppTheme.cardBackground(for: colorScheme)
                : AppTheme.cardBackground(for: colorScheme)
            )
            .overlay(
                AppTheme.squircle(radius: AppTheme.radiusM)
                    .strokeBorder(
                        isActive
                        ? AppTheme.accent.opacity(0.38)
                        : (isOverdue
                           ? Color(hex: "#EF4444").opacity(0.24)
                           : (isHovering
                              ? AppTheme.separator(for: colorScheme)
                              : AppTheme.separatorLow(for: colorScheme))),
                        lineWidth: isActive ? 1.25 : 1
                    )
            )
            .overlay(
                AppTheme.squircle(radius: AppTheme.radiusM)
                    .strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 0.75)
            )
            .multiLayerShadow(
                elevation: isHovering ? .elevated : .row,
                colorScheme: colorScheme
            )
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
