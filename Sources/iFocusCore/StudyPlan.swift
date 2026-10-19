import Foundation

/// One tickable entry of a series task: 「第 6 集」, a chapter, a paper.
public struct ChecklistItem: Codable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    /// When it was ticked; nil while open.
    public var doneAt: Date?
    /// One-line takeaway (「每集写一两句话」).
    public var note: String?
    /// 「没懂」: worth reviewing later.
    public var flagged: Bool?

    public var isDone: Bool { doneAt != nil }
    public var isFlagged: Bool { flagged == true }

    public init(id: UUID = UUID(), title: String, doneAt: Date? = nil, note: String? = nil, flagged: Bool? = nil) {
        self.id = id
        self.title = title
        self.doneAt = doneAt
        self.note = note
        self.flagged = flagged
    }

    enum CodingKeys: String, CodingKey {
        case id, title, doneAt, note, flagged
    }

    /// Tolerant: a damaged item never takes its whole task down with it.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        doneAt = try? c.decodeIfPresent(Date.self, forKey: .doneAt)
        note = try? c.decodeIfPresent(String.self, forKey: .note)
        flagged = try? c.decodeIfPresent(Bool.self, forKey: .flagged)
    }
}

/// Checklist progress for a series task (episodes, chapters, papers…).
public enum ChecklistProgress {
    public static let defaultUnit = "项"

    public static func done(_ items: [ChecklistItem]) -> Int {
        items.filter(\.isDone).count
    }

    /// The first `limit` open items, in list order.
    public static func nextUnchecked(_ items: [ChecklistItem], limit: Int) -> [ChecklistItem] {
        Array(items.filter { !$0.isDone }.prefix(max(0, limit)))
    }

    /// Days left including today: a task due today has 1, due yesterday has 0.
    public static func daysLeft(due: Date, today: Date, calendar: Calendar) -> Int {
        let from = calendar.startOfDay(for: today)
        let to = calendar.startOfDay(for: due)
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        return days + 1
    }

    /// Calm pacing copy — never red, never 「逾期」 or 「落后」.
    public static func paceText(
        done: Int,
        total: Int,
        unit: String?,
        due: Date?,
        today: Date,
        calendar: Calendar
    ) -> String {
        let unit = (unit?.isEmpty == false ? unit : nil) ?? defaultUnit
        let remaining = max(0, total - done)
        if remaining == 0 { return "全部完成" }
        guard let due else { return "\(done)/\(total) \(unit)" }
        let days = daysLeft(due: due, today: today, calendar: calendar)
        if days > 7 {
            let c = calendar.dateComponents([.month, .day], from: due)
            return "截止 \(c.month ?? 0)/\(c.day ?? 0)"
        }
        if days >= 1 {
            let perDay = (remaining + days - 1) / days
            return "还剩 \(remaining) \(unit) · 每天 \(perDay) \(unit)就能按时完成"
        }
        return "还剩 \(remaining) \(unit) · 接着完成就好"
    }
}

/// One task the route import creates (or adopts).
public struct PlanTaskDraft: Equatable {
    public var planKey: String
    public var title: String
    public var items: [String]
    public var unit: String?
    public var startDate: Date?
    public var dueDate: Date?
    public var notes: String
    public var repeatsDaily: Bool

    public init(
        planKey: String,
        title: String,
        items: [String] = [],
        unit: String? = nil,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        notes: String = "",
        repeatsDaily: Bool = false
    ) {
        self.planKey = planKey
        self.title = title
        self.items = items
        self.unit = unit
        self.startDate = startDate
        self.dueDate = dueDate
        self.notes = notes
        self.repeatsDaily = repeatsDaily
    }
}

public enum PlanTemplates {
    public static let accelerated4WeeksName = "加速版 4 周路线"

    /// Monday of the week to start from: this week's Monday, or tomorrow when today is Sunday.
    public static func defaultStartMonday(today: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: today)
        let weekday = calendar.component(.weekday, from: day) // 1 = Sunday
        if weekday == 1 {
            return calendar.date(byAdding: .day, value: 1, to: day) ?? day
        }
        return calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: day) ?? day
    }

    /// The Monday on or before `date` (any picked day maps to its week's Monday).
    public static func monday(onOrBefore date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        return calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: day) ?? day
    }

    /// 林画's accelerated 4-week route. Every date is computed from `startMonday`:
    /// week k starts at startMonday + 7(k−1) days and ends 6 days later.
    public static func accelerated4Weeks(startMonday: Date, calendar: Calendar) -> [PlanTaskDraft] {
        let monday = calendar.startOfDay(for: startMonday)
        func weekStart(_ k: Int) -> Date {
            calendar.date(byAdding: .day, value: 7 * (k - 1), to: monday) ?? monday
        }
        func weekEnd(_ k: Int) -> Date {
            calendar.date(byAdding: .day, value: 6, to: weekStart(k)) ?? weekStart(k)
        }
        func numbered(_ count: Int, _ unit: String) -> [String] {
            (1...count).map { "第 \($0) \(unit)" }
        }

        return [
            PlanTaskDraft(
                planKey: "accel.linalg", title: "3b1b 线性代数的本质",
                items: numbered(16, "集"), unit: "集", startDate: weekStart(1), dueDate: weekEnd(1),
                notes: "上午约 2 小时，每天 2～3 集；每集写一两句话就往下走，没懂的标「没懂」"
            ),
            PlanTaskDraft(
                planKey: "accel.calculus", title: "3b1b 微积分的本质",
                items: numbered(12, "集"), unit: "集", startDate: weekStart(2), dueDate: weekEnd(2),
                notes: "每天 2 集"
            ),
            PlanTaskDraft(
                planKey: "accel.nn1", title: "3b1b 神经网络 第 1–4 章",
                items: numbered(4, "章"), unit: "章", startDate: weekStart(3), dueDate: weekEnd(3),
                notes: "神经网络是什么、梯度下降、反向传播"
            ),
            PlanTaskDraft(
                planKey: "accel.nn2", title: "3b1b 神经网络 后几章",
                items: ["GPT", "注意力机制", "大模型怎么存知识"], unit: "章",
                startDate: weekStart(4), dueDate: weekEnd(4)
            ),
            PlanTaskDraft(
                planKey: "accel.python", title: "Python 基础",
                items: ["装好 Python 和 VS Code，跑通 print(\"hello\")", "列表", "字典", "函数", "类", "文件读写"],
                unit: "项", startDate: weekStart(1), dueDate: weekEnd(2),
                notes: "廖雪峰 Python 教程或《Python 编程：从入门到实践》前半本"
            ),
            PlanTaskDraft(
                planKey: "accel.numpy", title: "NumPy + Matplotlib 入门",
                items: ["用 NumPy 做矩阵乘法", "用代码验证线性变换", "用 Matplotlib 画函数和它的导数"],
                unit: "项", startDate: weekStart(2), dueDate: weekEnd(2)
            ),
            PlanTaskDraft(
                planKey: "accel.mnist", title: "用 NumPy 从零写手写数字识别网络",
                items: ["加载 MNIST 数据", "前向传播", "反向传播", "训练并测准确率"],
                unit: "项", startDate: weekStart(3), dueDate: weekEnd(3),
                notes: "参考 Michael Nielsen《Neural Networks and Deep Learning》"
            ),
            PlanTaskDraft(
                planKey: "accel.d2l", title: "开始《动手学深度学习》PyTorch 版",
                startDate: weekStart(4), dueDate: weekEnd(4)
            ),
            PlanTaskDraft(
                planKey: "accel.papers", title: "导师近两年论文 2 篇",
                items: ["论文 1", "论文 2"], unit: "篇", startDate: weekStart(1), dueDate: weekEnd(1),
                notes: "先读摘要和引言"
            ),
            PlanTaskDraft(
                planKey: "accel.leetcode", title: "LeetCode 简单题（Python）",
                dueDate: monday, notes: "每天 1 道，用 Python 写", repeatsDaily: true
            ),
        ]
    }
}
