import SwiftUI

/// One place to define the categories used by tasks, filters, analytics and profile.
/// Built-ins stay fixed so historical grouping never changes underneath the user.
struct CategoryManagementView: View {
    @EnvironmentObject private var taskStore: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedID: String?
    @State private var isCreating = false
    @State private var draftName = ""
    @State private var draftColorHex = CategoryPalette.options[0].hex
    @State private var draftIcon = CategoryIcons.options[0]
    @State private var validationMessage: String?
    @State private var showSaved = false
    @State private var pendingDelete: TaskCategory?
    @State private var didPrepare = false

    private var selectedCategory: TaskCategory? {
        taskStore.customCategories.first { $0.id == selectedID }
    }

    private var primary: Color {
        AppTheme.primaryText(for: colorScheme)
    }

    private var secondary: Color {
        AppTheme.secondaryText(for: colorScheme)
    }

    private var separator: Color {
        AppTheme.separatorLow(for: colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.6)

            HStack(spacing: 0) {
                listPane
                    .frame(width: 238)

                Rectangle()
                    .fill(separator)
                    .frame(width: 0.5)

                editorPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 690, height: 560)
        .background(AppTheme.cardBackground(for: colorScheme))
        .onAppear(perform: prepare)
        .alert(item: $pendingDelete) { category in
            Alert(
                title: Text("删除「\(category.name)」？"),
                message: Text("相关任务和专注记录会移到「其他」，这个操作不能撤销。"),
                primaryButton: .destructive(Text("删除分类")) {
                    delete(category)
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.12 : 0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: "tag.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("分类管理")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(primary)
                Text("自定义名称、颜色与图标，任务、筛选、统计和资料会自动使用。")
                    .font(.system(size: 11.5))
                    .foregroundColor(secondary)
            }

            Spacer()

            Button("完成") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - List

    private var listPane: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sectionLabel("内置分类")

                    VStack(spacing: 1) {
                        ForEach(TaskCategory.builtIn) { category in
                            builtInRow(category)
                        }
                    }

                    HStack(spacing: 6) {
                        sectionLabel("自定义")
                        Spacer()
                        Text("\(taskStore.customCategories.count)/\(TaskCategory.maxCustomCount)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(secondary.opacity(0.7))
                    }

                    if taskStore.customCategories.isEmpty {
                        Text("还没有自定义分类。\n比如「阅读」「健身」「副业」。")
                            .font(.system(size: 11))
                            .foregroundColor(secondary.opacity(0.85))
                            .lineSpacing(3)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 1) {
                            ForEach(taskStore.customCategories) { category in
                                customRow(category)
                            }
                        }
                    }
                }
                .padding(14)
            }

            Divider().opacity(0.6)

            Button {
                beginCreating()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 10.5, weight: .semibold))
                    Text("新建分类")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(
                    taskStore.customCategories.count >= TaskCategory.maxCustomCount
                        ? secondary.opacity(0.45)
                        : AppTheme.accent
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(taskStore.customCategories.count >= TaskCategory.maxCustomCount)
            .help(
                taskStore.customCategories.count >= TaskCategory.maxCustomCount
                    ? "最多 \(TaskCategory.maxCustomCount) 个自定义分类"
                    : "新建一个自定义分类"
            )
        }
        .background(AppTheme.elevatedBackground(for: colorScheme).opacity(0.55))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.5)
            .foregroundColor(secondary.opacity(0.8))
            .padding(.leading, 8)
    }

    private func builtInRow(_ category: TaskCategory) -> some View {
        HStack(spacing: 9) {
            categoryGlyph(category, size: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(category.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(primary)
                Text("\(taskCountLabel(category)) · 内置")
                    .font(.system(size: 10))
                    .foregroundColor(secondary.opacity(0.7))
            }

            Spacer(minLength: 0)

            Image(systemName: "lock.fill")
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundColor(secondary.opacity(0.35))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    private func customRow(_ category: TaskCategory) -> some View {
        let isSelected = !isCreating && category.id == selectedID
        return Button {
            select(category)
        } label: {
            HStack(spacing: 9) {
                categoryGlyph(category, size: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(category.name)
                        .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(primary)
                        .lineLimit(1)
                    Text(taskCountLabel(category))
                        .font(.system(size: 10))
                        .foregroundColor(secondary.opacity(0.7))
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(secondary.opacity(0.55))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected
                          ? AppTheme.cardBackground(for: colorScheme).opacity(0.85)
                          : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Editor

    @ViewBuilder
    private var editorPane: some View {
        if isCreating || selectedCategory != nil {
            editor
        } else {
            VStack(spacing: 10) {
                Image(systemName: "tag")
                    .font(.system(size: 26, weight: .light))
                    .foregroundColor(secondary.opacity(0.55))
                Text("选择一个分类进行编辑")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(secondary)
                Text("或新建一个自定义分类。")
                    .font(.system(size: 11))
                    .foregroundColor(secondary.opacity(0.8))
                Button("新建分类") {
                    beginCreating()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: draftColorHex).opacity(colorScheme == .light ? 0.14 : 0.22))
                        .frame(width: 48, height: 48)
                    Image(systemName: draftIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: draftColorHex))
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(isCreating ? "新分类" : (selectedCategory?.name ?? "分类"))
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundColor(primary)
                    Text(isCreating
                         ? "填写名称，再挑一个颜色和图标。"
                         : "修改会同步到这个分类下的任务与专注记录。")
                        .font(.system(size: 11))
                        .foregroundColor(secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("名称")

                TextField("例如：阅读、健身、副业", text: $draftName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .accessibilityLabel("分类名称")
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.elevatedBackground(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                validationMessage == nil
                                    ? separator
                                    : AppTheme.danger.opacity(0.55),
                                lineWidth: 1
                            )
                    )
                    .onChange(of: draftName) { _ in
                        validationMessage = nil
                        showSaved = false
                    }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let validationMessage {
                        Text(validationMessage)
                            .font(.system(size: 10.5))
                            .foregroundColor(AppTheme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Text("\(draftName.count)/\(TaskCategory.maxNameLength)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(
                            draftName.count > TaskCategory.maxNameLength
                                ? AppTheme.danger
                                : secondary.opacity(0.65)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("颜色")

                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(26), spacing: 9), count: 10),
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(CategoryPalette.options) { option in
                        colorSwatch(option)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("图标")

                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(34), spacing: 7), count: 8),
                    alignment: .leading,
                    spacing: 7
                ) {
                    ForEach(CategoryIcons.options, id: \.self) { icon in
                        iconChoice(icon)
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                if !isCreating, let selectedCategory {
                    Button(role: .destructive) {
                        pendingDelete = selectedCategory
                    } label: {
                        Label("删除分类", systemImage: "trash")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(AppTheme.danger)
                    .help("把相关任务与记录移到「其他」")
                }

                Spacer()

                if showSaved {
                    Label("已保存", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.success)
                }

                Button(isCreating ? "添加分类" : "保存更改") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(secondary)
    }

    private func colorSwatch(_ option: CategoryColorOption) -> some View {
        let isSelected = draftColorHex == option.hex
        return Button {
            draftColorHex = option.hex
            showSaved = false
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: option.hex))
                    .frame(width: 24, height: 24)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 26, height: 26)
            .overlay(
                Circle()
                    .strokeBorder(
                        isSelected ? primary.opacity(0.62) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(option.name)
        .accessibilityLabel("颜色：\(option.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func iconChoice(_ icon: String) -> some View {
        let isSelected = draftIcon == icon
        let tint = Color(hex: draftColorHex)
        return Button {
            draftIcon = icon
            showSaved = false
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(isSelected ? .white : secondary)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? tint : AppTheme.elevatedBackground(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : separator, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("图标：\(CategoryIcons.name(for: icon))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func categoryGlyph(_ category: TaskCategory, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(category.color.opacity(colorScheme == .light ? 0.13 : 0.20))
                .frame(width: size, height: size)
            Image(systemName: category.icon)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundColor(category.color)
        }
        .accessibilityHidden(true)
    }

    // MARK: - State

    private func prepare() {
        guard !didPrepare else { return }
        didPrepare = true
        if let first = taskStore.customCategories.first {
            select(first)
        } else {
            beginCreating()
        }
    }

    private func beginCreating() {
        isCreating = true
        selectedID = nil
        draftName = ""
        draftIcon = CategoryIcons.options[0]
        draftColorHex = suggestedColorHex()
        validationMessage = nil
        showSaved = false
    }

    private func select(_ category: TaskCategory) {
        isCreating = false
        selectedID = category.id
        draftName = category.name
        draftColorHex = category.colorHex
        draftIcon = category.icon
        validationMessage = nil
        showSaved = false
    }

    private func suggestedColorHex() -> String {
        let used = Set(taskStore.allCategories.map(\.colorHex))
        return CategoryPalette.options.first(where: { !used.contains($0.hex) })?.hex
            ?? CategoryPalette.options[0].hex
    }

    private func save() {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let result: Result<TaskCategory, CategoryValidationError>
        if isCreating {
            result = taskStore.addCustomCategory(
                name: name,
                colorHex: draftColorHex,
                icon: draftIcon
            )
        } else if let selectedCategory {
            result = taskStore.updateCustomCategory(
                id: selectedCategory.id,
                name: name,
                colorHex: draftColorHex,
                icon: draftIcon
            )
        } else {
            return
        }

        switch result {
        case .success(let category):
            isCreating = false
            selectedID = category.id
            draftName = category.name
            draftColorHex = category.colorHex
            draftIcon = category.icon
            validationMessage = nil
            showSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                showSaved = false
            }
        case .failure(let error):
            validationMessage = error.localizedDescription
            showSaved = false
        }
    }

    private func delete(_ category: TaskCategory) {
        taskStore.deleteCustomCategory(id: category.id)
        if let next = taskStore.customCategories.first {
            select(next)
        } else {
            beginCreating()
        }
    }

    private func taskCountLabel(_ category: TaskCategory) -> String {
        let count = taskStore.tasks.filter { $0.category.id == category.id }.count
        return count == 1 ? "1 个任务" : "\(count) 个任务"
    }
}

// MARK: - Choices

private enum CategoryPalette {
    static let options: [CategoryColorOption] = [
        CategoryColorOption(name: "珊瑚", hex: "#E65C40"),
        CategoryColorOption(name: "蓝色", hex: "#3B82F6"),
        CategoryColorOption(name: "绿色", hex: "#10B981"),
        CategoryColorOption(name: "紫色", hex: "#8B5CF6"),
        CategoryColorOption(name: "琥珀", hex: "#F59E0B"),
        CategoryColorOption(name: "青色", hex: "#14B8A6"),
        CategoryColorOption(name: "粉色", hex: "#EC4899"),
        CategoryColorOption(name: "靛蓝", hex: "#6366F1"),
        CategoryColorOption(name: "灰色", hex: "#6B7280"),
        CategoryColorOption(name: "红色", hex: "#EF4444")
    ]
}

private enum CategoryIcons {
    static let options: [String] = [
        "tag.fill",
        "briefcase.fill",
        "book.fill",
        "heart.fill",
        "flag.fill",
        "house.fill",
        "cart.fill",
        "figure.run",
        "paintbrush.fill",
        "music.note",
        "graduationcap.fill",
        "leaf.fill",
        "star.fill",
        "lightbulb.fill",
        "pawprint.fill",
        "airplane"
    ]

    private static let names: [String: String] = [
        "tag.fill": "标签",
        "briefcase.fill": "工作包",
        "book.fill": "书",
        "heart.fill": "心形",
        "flag.fill": "旗帜",
        "house.fill": "房子",
        "cart.fill": "购物车",
        "figure.run": "跑步",
        "paintbrush.fill": "画笔",
        "music.note": "音符",
        "graduationcap.fill": "学位帽",
        "leaf.fill": "叶子",
        "star.fill": "星星",
        "lightbulb.fill": "灯泡",
        "pawprint.fill": "爪印",
        "airplane": "飞机"
    ]

    static func name(for icon: String) -> String {
        names[icon] ?? "图标"
    }
}
