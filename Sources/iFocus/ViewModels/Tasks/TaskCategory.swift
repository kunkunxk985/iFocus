import SwiftUI

/// A task category. Built-ins still encode as their legacy Chinese name, so data
/// written by earlier versions decodes unchanged. Custom categories carry their
/// own stable id and presentation and encode as objects inside tasks and history.
struct TaskCategory: Identifiable, Hashable, Codable, CaseIterable {
    let id: String
    let name: String
    let colorHex: String
    let icon: String
    let isBuiltIn: Bool

    /// Legacy display value used by older call sites and tests.
    var rawValue: String { name }

    var color: Color { Color(hex: colorHex) }

    static let work = TaskCategory(
        id: "work", name: "工作", colorHex: "#E65C40", icon: "briefcase.fill", isBuiltIn: true
    )
    static let study = TaskCategory(
        id: "study", name: "学习", colorHex: "#3B82F6", icon: "book.fill", isBuiltIn: true
    )
    static let life = TaskCategory(
        id: "life", name: "生活", colorHex: "#10B981", icon: "heart.fill", isBuiltIn: true
    )
    static let important = TaskCategory(
        id: "important", name: "重要", colorHex: "#8B5CF6", icon: "flag.fill", isBuiltIn: true
    )
    static let home = TaskCategory(
        id: "home", name: "家", colorHex: "#F59E0B", icon: "house.fill", isBuiltIn: true
    )
    static let other = TaskCategory(
        id: "other", name: "其他", colorHex: "#6B7280", icon: "questionmark.circle.fill", isBuiltIn: true
    )

    /// Built-ins only; UI code that must include custom categories uses
    /// `TaskStore.allCategories` instead.
    static var builtIn: [TaskCategory] { [work, study, life, important, home, other] }
    static var allCases: [TaskCategory] { builtIn }

    static let fallbackColorHex = "#6B7280"
    static let maxNameLength = 12
    static let maxCustomCount = 12

    init(
        id: String,
        name: String,
        colorHex: String,
        icon: String,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.isBuiltIn = isBuiltIn
    }

    static func resolveBuiltIn(_ raw: String) -> TaskCategory? {
        builtIn.first { $0.name == raw || $0.id == raw }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, icon
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let raw = try? container.decode(String.self) {
            if let builtIn = Self.resolveBuiltIn(raw) {
                self = builtIn
            } else {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                self = TaskCategory(
                    id: "custom-legacy-\(trimmed)",
                    name: trimmed.isEmpty ? "其他" : trimmed,
                    colorHex: Self.fallbackColorHex,
                    icon: "tag.fill",
                    isBuiltIn: false
                )
            }
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedID = try container.decode(String.self, forKey: .id)
        let decodedName = try container.decode(String.self, forKey: .name)
        if let builtIn = Self.builtIn.first(where: { $0.id == decodedID || $0.name == decodedName }) {
            self = builtIn
            return
        }
        self = TaskCategory(
            id: decodedID,
            name: decodedName,
            colorHex: try container.decodeIfPresent(String.self, forKey: .colorHex) ?? Self.fallbackColorHex,
            icon: try container.decodeIfPresent(String.self, forKey: .icon) ?? "tag.fill",
            isBuiltIn: false
        )
    }

    func encode(to encoder: Encoder) throws {
        if isBuiltIn {
            var container = encoder.singleValueContainer()
            try container.encode(name)
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(colorHex, forKey: .colorHex)
            try container.encode(icon, forKey: .icon)
        }
    }
}

struct CategoryColorOption: Identifiable, Equatable {
    let name: String
    let hex: String

    var id: String { hex }
}

enum CategoryValidationError: LocalizedError, Equatable {
    case emptyName
    case nameTooLong
    case duplicateName
    case limitReached
    case notFound

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "分类名称不能为空。"
        case .nameTooLong:
            return "分类名称最多 \(TaskCategory.maxNameLength) 个字符。"
        case .duplicateName:
            return "已经有同名分类了，换一个名称试试。"
        case .limitReached:
            return "最多可以创建 \(TaskCategory.maxCustomCount) 个自定义分类。"
        case .notFound:
            return "这个分类已经不存在，可能已被删除。"
        }
    }
}
