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
    let items: [ChecklistItem]
    let itemUnit: String
    let startDate: Date?
    
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
        self.items = task.checklist
        self.itemUnit = task.unitLabel
        self.startDate = task.startDate
    }
}

/// Self-contained editor — no EnvironmentObject observation during editing.
/// Parent applies changes only on Save via `onSave`.
struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let session: EditTaskSession
    var onSave: (
        _ title: String,
        _ category: TaskCategory,
        _ priority: Int,
        _ estimatedPomodoros: Int,
        _ dueDate: Date?,
        _ recurrence: TaskRecurrence,
        _ notes: String,
        _ linkURL: String,
        _ items: [ChecklistItem]?,
        _ itemUnit: String?,
        _ startDate: Date?
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
    @State private var checklistItems: [ChecklistItem]
    @State private var itemUnit: String
    @State private var newChecklistTitle = ""
    @State private var startDate: Date
    @State private var hasStartDate: Bool
    
    init(
        session: EditTaskSession,
        onSave: @escaping (
            String, TaskCategory, Int, Int, Date?, TaskRecurrence, String, String,
            [ChecklistItem]?, String?, Date?
        ) -> Void
    ) {
        self.session = session
        self.onSave = onSave
        _title = State(initialValue: session.title)
        _category = State(initialValue: session.category)
        _priority = State(initialValue: session.priority)
        _estimatedPomodoros = State(initialValue: session.estimatedPomodoros)
        _recurrence = State(initialValue: session.recurrence)
        _notes = State(initialValue: session.notes)
        _linkURL = State(initialValue: session.linkURL)
        _checklistItems = State(initialValue: session.items)
        _itemUnit = State(initialValue: session.itemUnit)
        _hasStartDate = State(initialValue: session.startDate != nil)
        _startDate = State(initialValue: session.startDate ?? Calendar.current.startOfDay(for: Date()))
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
                            ForEach(TaskCategory.allCases) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    
                    Divider().opacity(0.5)
                    
                    fieldRow("优先级") {
                        Picker("", selection: $priority) {
                            ForEach(1...4, id: \.self) { p in
                                Text("\(p) 级").tag(p)
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

                    checklistEditor
                    
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
                        linkURL,
                        normalizedChecklist.isEmpty ? nil : normalizedChecklist,
                        normalizedChecklist.isEmpty ? nil : normalizedUnit,
                        hasStartDate ? Calendar.current.startOfDay(for: startDate) : nil
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

    private var normalizedChecklist: [ChecklistItem] {
        checklistItems.compactMap { item in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            return ChecklistItem(
                id: item.id,
                title: title,
                doneAt: item.doneAt,
                note: item.note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                flagged: item.isFlagged ? true : nil
            )
        }
    }

    private var normalizedUnit: String {
        let value = itemUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? ChecklistProgress.defaultUnit : value
    }

    private var checklistEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("学习清单")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    Text("全部勾选后会自动完成任务；旗标表示需要回顾。")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }
                Spacer()
                HStack(spacing: 5) {
                    Text("单位")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    TextField("项", text: $itemUnit)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .accessibilityLabel("学习进度单位")
                }
            }

            if checklistItems.isEmpty {
                Text("例如：第 1 集、章节、论文。添加后可逐项记录进度。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .padding(.vertical, 3)
            } else {
                VStack(spacing: 7) {
                    ForEach(checklistItems) { item in
                        checklistEditorRow(item)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("添加一项，例如：第 1 集", text: $newChecklistTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addChecklistItem)
                Button(action: addChecklistItem) {
                    Label("添加", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(newChecklistTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack {
                Toggle("按开始日期加入今天", isOn: $hasStartDate)
                    .toggleStyle(.switch)
                    .font(.caption)
                Spacer()
                if hasStartDate {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .accessibilityLabel("任务开始日期")
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func checklistEditorRow(_ item: ChecklistItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Button {
                    updateChecklistItem(item.id) { current in
                        current.doneAt = current.isDone ? nil : Date()
                    }
                } label: {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(item.isDone ? Color.green : AppTheme.secondaryText(for: colorScheme))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isDone ? "标记未完成：\(item.title)" : "标记完成：\(item.title)")

                TextField("清单项目", text: Binding(
                    get: { checklistItems.first(where: { $0.id == item.id })?.title ?? "" },
                    set: { value in updateChecklistItem(item.id) { $0.title = value } }
                ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))

                Button {
                    updateChecklistItem(item.id) { $0.flagged = !$0.isFlagged }
                } label: {
                    Image(systemName: item.isFlagged ? "flag.fill" : "flag")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(item.isFlagged ? .orange : AppTheme.secondaryText(for: colorScheme).opacity(0.65))
                }
                .buttonStyle(.plain)
                .help(item.isFlagged ? "取消疑问标记" : "标记为没懂")
                .accessibilityLabel(item.isFlagged ? "取消疑问标记：\(item.title)" : "标记没懂：\(item.title)")

                Button {
                    checklistItems.removeAll { $0.id == item.id }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.65))
                }
                .buttonStyle(.plain)
                .help("删除这一项")
                .accessibilityLabel("删除清单项目：\(item.title)")
            }

            TextField("学习笔记（可选）", text: Binding(
                get: { checklistItems.first(where: { $0.id == item.id })?.note ?? "" },
                set: { value in updateChecklistItem(item.id) { $0.note = value } }
            ))
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(.leading, 24)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.elevatedBackground(for: colorScheme).opacity(0.75))
        )
    }

    private func addChecklistItem() {
        let title = newChecklistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        checklistItems.append(ChecklistItem(title: title))
        newChecklistTitle = ""
    }

    private func updateChecklistItem(_ id: UUID, _ update: (inout ChecklistItem) -> Void) {
        guard let index = checklistItems.firstIndex(where: { $0.id == id }) else { return }
        update(&checklistItems[index])
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

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
