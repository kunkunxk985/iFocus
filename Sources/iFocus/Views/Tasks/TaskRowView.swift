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
                        ? AppTheme.accent
                        : AppTheme.secondaryText(for: colorScheme).opacity(0.40),
                        lineWidth: isCompleted ? 1.5 : 1.25
                    )
                    .background(
                        Circle()
                            .fill(
                                isCompleted
                                ? AppTheme.accent
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

    /// Task has secondary metadata to display.
    private var hasMetadata: Bool {
        task.timeSpentMinutes > 0 || hasNotes || task.hasLink || task.dueDate != nil
    }

    /// Unified whisper-quiet metadata opacity (0.50 light / 0.55 dark).
    private var metadataForeground: Color {
        AppTheme.secondaryText(for: colorScheme).opacity(colorScheme == .light ? 0.50 : 0.55)
    }

    /// Serene warm rose overdue tone (Things 3 / Apple Reminders style).
    private var overdueWarmRose: Color {
        colorScheme == .light
            ? Color(red: 0.82, green: 0.38, blue: 0.40)
            : Color(red: 0.90, green: 0.48, blue: 0.50)
    }

    /// Pin stays visible when pinned; edit + unpinned pin only on hover or active.
    private var showSecondaryActions: Bool {
        isHovering || task.isPinned || isActive
    }
    
    var body: some View {
        let density = settings.uiDensity
        let completedFade = task.isCompleted || isGraceCompleted
        
        HStack(alignment: .top, spacing: 0) {
            // Invariant 20pt leading slot: drag handle or transparent placeholder
            Group {
                if !completedFade && !isSelecting {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: AppTheme.iconAction, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.60))
                        .frame(width: 16, height: 24)
                        .contentShape(Rectangle())
                        .opacity(isHovering ? 1.0 : 0.0)
                        .animation(AppTheme.springSnappy, value: isHovering)
                        .help("拖到侧栏改期 · 列表内拖动排序")
                        .accessibilityLabel("拖动任务到侧栏改期，或在列表内排序")
                        .draggable(task.id.uuidString)
                        .padding(.trailing, 4)
                } else {
                    Color.clear
                        .frame(width: 20, height: 24)
                        .allowsHitTesting(false)
                }
            }
            .padding(.top, density == .compact ? 1.5 : 2)
            
            HStack(alignment: .top, spacing: 10 * density.scale) {
                // Checkbox slot (invariant 24x24 touch target, top-aligned with optical offset)
                Group {
                    if isSelecting {
                        Button {
                            onToggleSelect?()
                        } label: {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText(for: colorScheme).opacity(0.5))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(SpringScaleButtonStyle())
                        .accessibilityLabel(isSelected ? "取消选择" : "选择任务")
                    } else {
                        AnimatedTaskCheckbox(isCompleted: completedFade) {
                            handleCheckboxTap()
                        }
                        .help(completedFade ? "标为未完成" : "标为完成")
                        .accessibilityLabel(completedFade ? "标为未完成" : "标为完成")
                    }
                }
                .padding(.top, density == .compact ? 1.5 : 2)
                
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
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(isRunning ? AppTheme.accent : AppTheme.secondaryText(for: colorScheme))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.16))
                                )
                        }

                        if task.isOverdue && !completedFade {
                            Text("逾期")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(overdueWarmRose)
                        }
                        
                        Spacer(minLength: 0)
                    }
                    
                    // Secondary metadata row (conditional — rendered ONLY when metadata exists)
                    if hasMetadata {
                        HStack(spacing: 8) {
                            focusDurationMeta
                            
                            if hasNotes {
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: AppTheme.iconMeta, weight: .medium))
                                    .foregroundColor(metadataForeground)
                                    .help(task.notes)
                            }
                            
                            if task.hasLink {
                                Button(action: openTaskLink) {
                                    Image(systemName: "link")
                                        .font(.system(size: AppTheme.iconMeta, weight: .medium))
                                        .foregroundColor(metadataForeground)
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
                                    ? overdueWarmRose
                                    : metadataForeground
                                )
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(completedFade ? 0.72 : 1)

                if !completedFade && !isSelecting {
                    secondaryActionButtons
                        .padding(.top, density == .compact ? 0 : 1)
                }
            }
        }
        .padding(.leading, density == .compact ? 8 : 10)
        .padding(.trailing, density == .compact ? 10 : 12)
        .padding(.vertical, density.rowVerticalPadding)
        .background(rowBackground)
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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

    private var secondaryActionButtons: some View {
        HStack(spacing: 2) {
            Button(action: handleFocusButton) {
                Image(systemName: focusButtonIcon)
                    .font(.system(size: AppTheme.iconAction, weight: .bold))
                    .foregroundColor(
                        isActive
                        ? AppTheme.accent
                        : AppTheme.secondaryText(for: colorScheme).opacity(0.70)
                    )
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SpringScaleButtonStyle())
            .help(focusButtonHelp)
            .accessibilityLabel(focusButtonHelp)
            .opacity(isActive || isHovering ? 1 : 0)

            Button {
                AppHaptics.buttonClick()
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
                    .contentShape(Rectangle())
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
                    .contentShape(Rectangle())
            }
            .buttonStyle(SpringScaleButtonStyle())
            .help("编辑（也可双击）")
            .accessibilityLabel("编辑任务")
            .opacity(isHovering || isActive ? 1 : 0)

            Button {
                AppHaptics.buttonClick()
                taskStore.deleteTask(task)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: AppTheme.iconAction, weight: .medium))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.60))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SpringScaleButtonStyle())
            .help("删除任务")
            .accessibilityLabel("删除任务")
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
        let sameYear = calendar.component(.year, from: due) == calendar.component(.year, from: Date())
        return (sameYear ? dueFormatter : dueFormatterWithYear).string(from: due)
    }
    
    @ViewBuilder
    private var focusDurationMeta: some View {
        if task.timeSpentMinutes > 0 {
            focusDurationLabel(
                FocusStats.formatTotalMinutes(task.timeSpentMinutes)
                    .replacingOccurrences(of: "分钟", with: "分"),
                help: task.isCompleted ? "累计专注时长" : "已累计专注时长"
            )
        }
    }

    private func focusDurationLabel(_ text: String, help: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "clock")
                .font(.system(size: AppTheme.iconMeta, weight: .semibold))
            Text(text)
                .font(TypeScale.meta.monospacedDigit())
        }
        .foregroundColor(metadataForeground)
        .help(help)
    }
    
    private var rowBackground: some View {
        let selected = isSelecting && isSelected
        let fill: Color
        if selected {
            fill = AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.16)
        } else if isActive {
            fill = AppTheme.accent.opacity(colorScheme == .light ? 0.06 : 0.10)
        } else if isHovering {
            fill = Color.primary.opacity(colorScheme == .light ? 0.035 : 0.055)
        } else {
            fill = Color.clear
        }
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(fill)
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
        
        Menu("移到") {
            Button("今天") {
                taskStore.moveTask(id: task.id, to: .todayTask)
            }
            Button("明天") {
                taskStore.moveTask(id: task.id, to: .tomorrowTask)
            }
            Button("稍后") {
                taskStore.moveTask(id: task.id, to: .weekTask)
            }
            Button("收集箱") {
                taskStore.moveTask(id: task.id, to: .inboxTask)
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

extension FocusTask {
    static func priorityLabel(for priority: Int) -> String {
        switch priority {
        case 1: return "普通"
        case 2: return "中"
        case 3: return "高"
        default: return "紧急"
        }
    }
}
