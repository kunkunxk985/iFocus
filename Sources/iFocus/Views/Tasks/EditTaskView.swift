import SwiftUI
import AppKit
import iFocusCore

/// Stable identity for the edit sheet — never use live `FocusTask` as `sheet(item:)`
/// while the timer ticks, or SwiftUI re-presents / re-layouts the form every second.
struct EditTaskSession: Identifiable, Equatable {
    let id: UUID
    let title: String
    let category: TaskCategory
    let priority: Int
    let estimatedPomodoros: Int
    let dueDate: Date?
    let recurrence: TaskRecurrence
    let notes: String
    let linkURL: String
    
    init(task: FocusTask) {
        self.id = task.id
        self.title = task.title
        self.category = task.category
        self.priority = task.priority
        self.estimatedPomodoros = task.estimatedPomodoros
        self.dueDate = task.dueDate
        self.recurrence = task.recurrence
        self.notes = task.notes
        self.linkURL = task.linkURL
    }
}

/// Things 3 style floating card task editor (Milestone 2 - R1).
/// Features:
/// - 460pt continuous squircle with `.floatingCardSurface(cornerRadius: 18)`.
/// - Top-right `FloatingModalCloseButton`.
/// - Borderless 16pt rounded title input (`.font(.system(size: 16, weight: .semibold, design: .rounded))`).
/// - Things 3 date capsule presets (`[ 无 ]`, `[ 今天 ]`, `[ 明天 ]`, `[ 稍后 ]`, `[ 自定义日期… ⌵ ]`) with popover.
/// - Embedded squircle cards for notes (multi-line TextEditor, Enter doesn't dismiss) and URL.
/// - Valid URL highlighting and native opening via `NSWorkspace.shared.open`.
/// - Bottom shortcut hints (`⌘↵ 保存 · Esc 取消`) with keyboard shortcuts.
/// - Preserves existing category, priority, pomodoros, and recurrence.
struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let session: EditTaskSession
    let categories: [TaskCategory]
    var onCancel: (() -> Void)? = nil
    var onSave: (
        _ title: String,
        _ category: TaskCategory,
        _ priority: Int,
        _ estimatedPomodoros: Int,
        _ dueDate: Date?,
        _ recurrence: TaskRecurrence,
        _ notes: String,
        _ linkURL: String
    ) -> Void
    
    @State private var title: String
    @State private var dueDate: Date?
    @State private var notes: String
    @State private var linkURL: String
    
    @State private var isShowingCustomDatePicker = false
    @State private var customDateSelection: Date = Date()
    
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool
    @FocusState private var isLinkFocused: Bool
    
    private let calendar = Calendar.current
    
    init(
        session: EditTaskSession,
        categories: [TaskCategory] = [],
        onCancel: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        onSave: @escaping (
            String, TaskCategory, Int, Int, Date?, TaskRecurrence, String, String
        ) -> Void
    ) {
        self.session = session
        self.categories = categories
        self.onCancel = onCancel ?? onDismiss
        self.onSave = onSave
        _title = State(initialValue: session.title)
        _notes = State(initialValue: session.notes)
        _linkURL = State(initialValue: session.linkURL)
        _dueDate = State(initialValue: session.dueDate)
        _customDateSelection = State(initialValue: session.dueDate ?? Calendar.current.startOfDay(for: Date()))
    }
    
    // MARK: - Validation & Helpers
    
    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var normalizedLink: String {
        linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var linkLooksValid: Bool {
        guard let url = URL(string: normalizedLink),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = url.host,
              !host.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        return true
    }
    
    private var activeDatePreset: DatePreset {
        classifyDate(dueDate)
    }
    
    enum DatePreset: Equatable {
        case none
        case today
        case tomorrow
        case later
        case custom(Date)
    }
    
    private func classifyDate(_ date: Date?) -> DatePreset {
        guard let date = date else { return .none }
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        
        if target == today {
            return .today
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), target == tomorrow {
            return .tomorrow
        } else if let later = calendar.date(byAdding: .day, value: 2, to: today), target == later {
            return .later
        } else {
            return .custom(target)
        }
    }
    
    private func formatCustomDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    // MARK: - Main Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. Borderless 16pt Rounded Title Input
            titleSection
            
            // 2. Things 3 Date Capsule Presets & Popover
            dateCapsulesSection
            
            // 3. Embedded Notes Squircle Card (Multi-line, Enter doesn't dismiss)
            notesSection
            
            // 4. Embedded URL Squircle Card with clickable link
            urlSection
            
            Divider()
                .padding(.vertical, 2)
            
            // 5. Action Buttons & Shortcut Hints
            footerSection
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 16)
        .frame(width: 460)
        .floatingCardSurface(cornerRadius: 18)
        .overlay(alignment: .topTrailing) {
            FloatingModalCloseButton {
                handleCancel()
            }
            .padding([.top, .trailing], 14)
        }
        .onAppear {
            DispatchQueue.main.async {
                isTitleFocused = true
            }
        }
        .onExitCommand {
            handleCancel()
        }
    }
    
    // MARK: - 1. Title Section
    
    private var titleSection: some View {
        HStack(alignment: .center, spacing: 10) {
            TextField("任务名称", text: $title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .textFieldStyle(.plain)
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .focused($isTitleFocused)
            
            if !title.isEmpty {
                Button {
                    title = ""
                    isTitleFocused = true
                    AppHaptics.selectionChanged()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.60))
                }
                .buttonStyle(.plain)
                .help("清空任务名称")
                .accessibilityLabel("清空任务名称")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.trailing, 28) // Clearance for top-right FloatingModalCloseButton
    }
    
    // MARK: - 2. Date Capsules Section
    
    private var dateCapsulesSection: some View {
        HStack(spacing: 6) {
            dateCapsule(title: "无", isSelected: activeDatePreset == .none) {
                dueDate = nil
            }
            
            dateCapsule(title: "今天", isSelected: activeDatePreset == .today) {
                dueDate = calendar.startOfDay(for: Date())
            }
            
            dateCapsule(title: "明天", isSelected: activeDatePreset == .tomorrow) {
                let today = calendar.startOfDay(for: Date())
                dueDate = calendar.date(byAdding: .day, value: 1, to: today)
            }
            
            dateCapsule(title: "稍后", isSelected: activeDatePreset == .later) {
                let today = calendar.startOfDay(for: Date())
                dueDate = calendar.date(byAdding: .day, value: 2, to: today)
            }
            
            // Custom Date Capsule with Popover
            customDateCapsule
            
            Spacer(minLength: 0)
        }
    }
    
    private func dateCapsule(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            AppHaptics.selectionChanged()
            withAnimation(AppTheme.springInteractive) {
                action()
            }
        } label: {
            HStack(spacing: 4) {
                if isSelected {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 4, height: 4)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(
                        isSelected
                        ? AppTheme.accent
                        : AppTheme.secondaryText(for: colorScheme).opacity(colorScheme == .light ? 0.75 : 0.65)
                    )
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(
                        isSelected
                        ? AppTheme.accent.opacity(colorScheme == .light ? 0.12 : 0.20)
                        : AppTheme.elevatedBackground(for: colorScheme).opacity(0.40)
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected
                        ? AppTheme.accent.opacity(0.35)
                        : AppTheme.separatorLow(for: colorScheme),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(SpringScaleButtonStyle(pressedScale: 0.96))
        .help("设置截止日期为：\(title)")
    }
    
    private var customDateCapsule: some View {
        let isCustomActive: Bool = {
            if case .custom = activeDatePreset { return true }
            return false
        }()
        
        let labelText: String = {
            if case .custom(let date) = activeDatePreset {
                return "\(formatCustomDate(date)) ⌵"
            }
            return "自定义日期… ⌵"
        }()
        
        return Button {
            AppHaptics.selectionChanged()
            if let due = dueDate {
                customDateSelection = due
            } else {
                customDateSelection = calendar.startOfDay(for: Date())
            }
            isShowingCustomDatePicker.toggle()
        } label: {
            HStack(spacing: 4) {
                if isCustomActive {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 4, height: 4)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
                Text(labelText)
                    .font(.system(size: 11.5, weight: isCustomActive ? .semibold : .regular, design: .rounded))
                    .foregroundColor(
                        isCustomActive
                        ? AppTheme.accent
                        : AppTheme.secondaryText(for: colorScheme).opacity(colorScheme == .light ? 0.75 : 0.65)
                    )
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(
                        isCustomActive
                        ? AppTheme.accent.opacity(colorScheme == .light ? 0.12 : 0.20)
                        : AppTheme.elevatedBackground(for: colorScheme).opacity(0.40)
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isCustomActive
                        ? AppTheme.accent.opacity(0.35)
                        : AppTheme.separatorLow(for: colorScheme),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(SpringScaleButtonStyle(pressedScale: 0.96))
        .help("选择自定义日期")
        .popover(isPresented: $isShowingCustomDatePicker, arrowEdge: .bottom) {
            customDatePickerPopover
        }
    }
    
    private var customDatePickerPopover: some View {
        VStack(spacing: 10) {
            DatePicker(
                "选择截止日期",
                selection: $customDateSelection,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(8)
            .onChange(of: customDateSelection) { newDate in
                dueDate = calendar.startOfDay(for: newDate)
                AppHaptics.selectionChanged()
            }
            
            Divider()
                .opacity(0.5)
            
            HStack {
                Button("清除") {
                    dueDate = nil
                    isShowingCustomDatePicker = false
                    AppHaptics.selectionChanged()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                
                Spacer()
                
                Button("完成") {
                    dueDate = calendar.startOfDay(for: customDateSelection)
                    isShowingCustomDatePicker = false
                    AppHaptics.selectionChanged()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(AppTheme.accent)
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .frame(width: 260)
    }
    
    // MARK: - 3. Notes Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("备注")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))

            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("添加详细备注…")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.45))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $notes)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 70, maxHeight: 110)
                    .focused($isNotesFocused)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.elevatedBackground(for: colorScheme).opacity(colorScheme == .light ? 0.70 : 0.50))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isNotesFocused
                        ? AppTheme.accent.opacity(0.50)
                        : AppTheme.separatorLow(for: colorScheme),
                        lineWidth: isNotesFocused ? 1.0 : 0.75
                    )
            )
            .shadow(
                color: isNotesFocused ? AppTheme.accent.opacity(0.12) : .clear,
                radius: 4,
                x: 0,
                y: 1
            )
            .animation(AppTheme.springInteractive, value: isNotesFocused)
        }
    }
    
    // MARK: - 4. URL Section
    
    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("链接")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                
                Spacer()
                
                if linkLooksValid, let url = URL(string: normalizedLink) {
                    Button {
                        AppHaptics.buttonClick()
                        NSWorkspace.shared.open(url)
                    } label: {
                        HStack(spacing: 3) {
                            Text("打开链接")
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .help("在浏览器中打开：\(normalizedLink)")
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(
                        linkLooksValid
                        ? AppTheme.accent
                        : (!normalizedLink.isEmpty ? AppTheme.danger : AppTheme.secondaryText(for: colorScheme).opacity(0.60))
                    )
                    .frame(width: 16)

                TextField("https://…", text: $linkURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    .focused($isLinkFocused)

                if !linkURL.isEmpty {
                    Button {
                        linkURL = ""
                        isLinkFocused = true
                        AppHaptics.selectionChanged()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.60))
                    }
                    .buttonStyle(.plain)
                    .help("清空链接")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.elevatedBackground(for: colorScheme).opacity(colorScheme == .light ? 0.70 : 0.50))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        normalizedLink.isEmpty
                        ? (isLinkFocused ? AppTheme.accent.opacity(0.45) : AppTheme.separatorLow(for: colorScheme))
                        : (linkLooksValid
                           ? AppTheme.accent.opacity(0.50)
                           : AppTheme.danger.opacity(0.50)),
                        lineWidth: (isLinkFocused || !normalizedLink.isEmpty) ? 1.0 : 0.75
                    )
            )
            .shadow(
                color: isLinkFocused ? AppTheme.accent.opacity(0.12) : .clear,
                radius: 4,
                x: 0,
                y: 1
            )
            .animation(AppTheme.springInteractive, value: isLinkFocused)
            .animation(AppTheme.springInteractive, value: linkLooksValid)

            if !normalizedLink.isEmpty && !linkLooksValid {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                    Text("请输入以 http:// 或 https:// 开头的有效网址")
                        .font(.system(size: 10.5, weight: .medium))
                }
                .foregroundColor(AppTheme.danger.opacity(0.85))
                .padding(.leading, 2)
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - 5. Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button("取消") {
                    handleCancel()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    Capsule()
                        .fill(AppTheme.elevatedBackground(for: colorScheme))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.75)
                )
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    handleSave()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    Capsule()
                        .fill(AppTheme.accent)
                )
                .shadow(color: AppTheme.accent.opacity(isSaveDisabled ? 0 : 0.30), radius: 4, x: 0, y: 1.5)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(isSaveDisabled)
                .opacity(isSaveDisabled ? 0.45 : 1.0)
            }

            FloatingModalShortcutHint(hint: "⌘↵ 保存 · Esc 取消")
        }
    }
    
    // MARK: - Actions
    
    private func handleCancel() {
        AppHaptics.buttonClick()
        if let onCancel = onCancel {
            onCancel()
        } else {
            dismiss()
        }
    }
    
    private func handleSave() {
        guard !isSaveDisabled else { return }
        AppHaptics.buttonClick()
        let resolvedDueDate: Date? = {
            guard let due = dueDate else { return nil }
            return calendar.startOfDay(for: due)
        }()
        
        onSave(
            title.trimmingCharacters(in: .whitespacesAndNewlines),
            session.category,
            session.priority,
            session.estimatedPomodoros,
            resolvedDueDate,
            session.recurrence,
            notes,
            normalizedLink
        )
        if let onCancel = onCancel {
            onCancel()
        } else {
            dismiss()
        }
    }
}
