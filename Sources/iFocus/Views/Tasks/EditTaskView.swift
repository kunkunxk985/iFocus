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

/// Self-contained editor — no EnvironmentObject observation during editing.
/// Parent applies changes only on Save via `onSave`.
struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let session: EditTaskSession
    let categories: [TaskCategory]
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
    @State private var category: TaskCategory
    @State private var priority: Int
    @State private var estimatedPomodoros: Int
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var recurrence: TaskRecurrence
    @State private var notes: String
    @State private var linkURL: String
    
    init(
        session: EditTaskSession,
        categories: [TaskCategory],
        onSave: @escaping (
            String, TaskCategory, Int, Int, Date?, TaskRecurrence, String, String
        ) -> Void
    ) {
        self.session = session
        var availableCategories = categories
        if !availableCategories.contains(where: { $0.id == session.category.id }) {
            availableCategories.insert(session.category, at: 0)
        }
        self.categories = availableCategories
        self.onSave = onSave
        _title = State(initialValue: session.title)
        _category = State(initialValue:
            availableCategories.first(where: { $0.id == session.category.id }) ?? session.category
        )
        _priority = State(initialValue: session.priority)
        _estimatedPomodoros = State(initialValue: session.estimatedPomodoros)
        _recurrence = State(initialValue: session.recurrence)
        _notes = State(initialValue: session.notes)
        _linkURL = State(initialValue: session.linkURL)
        if let due = session.dueDate {
            _dueDate = State(initialValue: due)
            _hasDueDate = State(initialValue: true)
        } else {
            _dueDate = State(initialValue: Calendar.current.startOfDay(for: Date()))
            _hasDueDate = State(initialValue: false)
        }
    }
    
    private var normalizedLink: String {
        linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var linkLooksValid: Bool {
        guard let url = URL(string: normalizedLink),
              let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("编辑任务")
                .font(.headline)
                .padding(.top, 18)
                .padding(.bottom, 14)
            
            ScrollView {
                VStack(spacing: 0) {
                    fieldRow("任务名称") {
                        TextField("输入名称", text: $title)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Divider().opacity(0.5)
                    
                    fieldRow("分类") {
                        Picker("", selection: $category) {
                            ForEach(categories) { cat in
                                Label(cat.name, systemImage: cat.icon).tag(cat)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                    
                    Divider().opacity(0.5)
                    
                    fieldRow("优先级") {
                        Picker("", selection: $priority) {
                            ForEach(1...4, id: \.self) { p in
                                Text(FocusTask.priorityLabel(for: p)).tag(p)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }
                    
                    Divider().opacity(0.5)
                    
                    fieldRow("预计番茄") {
                        Stepper(value: $estimatedPomodoros, in: 1...20) {
                            Text("\(estimatedPomodoros)")
                                .font(.body.monospacedDigit().weight(.semibold))
                                .frame(minWidth: 28, alignment: .trailing)
                        }
                    }
                    
                    Divider().opacity(0.5)
                    
                    fieldRow("重复") {
                        Picker("", selection: $recurrence) {
                            ForEach(TaskRecurrence.allCases) { r in
                                Text(r.rawValue).tag(r)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    
                    if recurrence != .none {
                        Text(recurrence == .daily
                             ? "完成后会生成下一天的同名任务"
                             : "完成后会生成一周后的同名任务")
                            .font(.caption2)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 6)
                    }
                    
                    Divider().opacity(0.5)
                    
                    fieldRow("截止日期") {
                        Toggle("", isOn: $hasDueDate)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    
                    if hasDueDate {
                        Divider().opacity(0.5)
                        fieldRow("日期") {
                            DatePicker(
                                "",
                                selection: $dueDate,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .frame(maxWidth: 160)
                        }
                    }
                    
                    Divider().opacity(0.5)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        TextEditor(text: $notes)
                            .font(.body)
                            .frame(minHeight: 72, maxHeight: 120)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(AppTheme.elevatedBackground(for: colorScheme))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    
                    Divider().opacity(0.5)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("链接")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                            Spacer()
                            if linkLooksValid {
                                Button("打开") {
                                    if let url = URL(string: normalizedLink) {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppTheme.accent)
                            }
                        }
                        TextField("https://…", text: $linkURL)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(AppTheme.elevatedBackground(for: colorScheme))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(
                                        normalizedLink.isEmpty
                                        ? AppTheme.separatorLow(for: colorScheme)
                                        : (linkLooksValid
                                           ? AppTheme.accent.opacity(0.35)
                                           : Color.red.opacity(0.35)),
                                        lineWidth: 1
                                    )
                            )
                        if !normalizedLink.isEmpty && !linkLooksValid {
                            Text("请输入 http:// 或 https:// 开头的链接")
                                .font(.caption2)
                                .foregroundColor(Color.red.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.cardBackground(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                )
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: 420)
            
            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("保存") {
                    onSave(
                        title,
                        category,
                        priority,
                        estimatedPomodoros,
                        hasDueDate ? Calendar.current.startOfDay(for: dueDate) : nil,
                        recurrence,
                        notes,
                        linkURL
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .frame(width: 480)
    }

    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            Spacer(minLength: 12)
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}
