import SwiftUI

/// Stable identity for the edit sheet — never use live `FocusTask` as `sheet(item:)`
/// while the timer ticks, or SwiftUI re-presents / re-layouts the form every second.
struct EditTaskSession: Identifiable, Equatable {
    let id: UUID
    let title: String
    let category: TaskCategory
    let priority: Int
    let estimatedPomodoros: Int
    let dueDate: Date?
    
    init(task: FocusTask) {
        self.id = task.id
        self.title = task.title
        self.category = task.category
        self.priority = task.priority
        self.estimatedPomodoros = task.estimatedPomodoros
        self.dueDate = task.dueDate
    }
}

/// Self-contained editor — no EnvironmentObject observation during editing.
/// Parent applies changes only on Save via `onSave`.
struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let session: EditTaskSession
    var onSave: (_ title: String, _ category: TaskCategory, _ priority: Int, _ estimatedPomodoros: Int, _ dueDate: Date?) -> Void
    
    @State private var title: String
    @State private var category: TaskCategory
    @State private var priority: Int
    @State private var estimatedPomodoros: Int
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    
    init(session: EditTaskSession, onSave: @escaping (String, TaskCategory, Int, Int, Date?) -> Void) {
        self.session = session
        self.onSave = onSave
        _title = State(initialValue: session.title)
        _category = State(initialValue: session.category)
        _priority = State(initialValue: session.priority)
        _estimatedPomodoros = State(initialValue: session.estimatedPomodoros)
        if let due = session.dueDate {
            _dueDate = State(initialValue: due)
            _hasDueDate = State(initialValue: true)
        } else {
            _dueDate = State(initialValue: Calendar.current.startOfDay(for: Date()))
            _hasDueDate = State(initialValue: false)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("编辑任务")
                .font(.headline)
                .padding(.top, 18)
                .padding(.bottom, 14)
            
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
                
                fieldRow("截止日期") {
                    Toggle("", isOn: $hasDueDate)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                
                if hasDueDate {
                    Divider().opacity(0.5)
                    fieldRow("日期") {
                        // Prefer compact over `.field` — field style re-layout fights parent
                        // invalidation and was a known freeze path on macOS.
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
                        hasDueDate ? Calendar.current.startOfDay(for: dueDate) : nil
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
        .frame(width: 400)
        // Isolation contract:
        // - no EnvironmentObject / ObservedObject
        // - only local @State mutations
        // - parent must not re-present this sheet on timer ticks
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
