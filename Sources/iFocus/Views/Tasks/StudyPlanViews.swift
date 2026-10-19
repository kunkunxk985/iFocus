import SwiftUI
import iFocusCore

struct StudyPlanImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var taskStore: TaskStore

    let onImported: () -> Void

    @State private var startMonday = PlanTemplates.defaultStartMonday(today: Date(), calendar: .current)
    @State private var result: TaskStore.StudyPlanImportResult?

    private var calendar: Calendar { .current }
    private var drafts: [PlanTaskDraft] {
        PlanTemplates.accelerated4Weeks(startMonday: startMonday, calendar: calendar)
    }
    private var existingKeys: Set<String> {
        Set(taskStore.tasks.compactMap(\.planKey))
    }
    private var existingDraftCount: Int {
        drafts.filter { existingKeys.contains($0.planKey) }.count
    }
    private var availableCount: Int {
        drafts.count - existingDraftCount
    }
    private var dailyDraft: PlanTaskDraft? {
        drafts.first(where: \.repeatsDaily)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.55)

            Group {
                if let result {
                    resultContent(result)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    previewContent
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(AppTheme.springGentle, value: result != nil)

            Divider().opacity(0.55)
            footer
        }
        .frame(width: 600, height: 700)
        .background(AppTheme.contentBackground(for: colorScheme))
        .onChange(of: startMonday) { selected in
            let monday = PlanTemplates.monday(onOrBefore: selected, calendar: calendar)
            if !calendar.isDate(selected, inSameDayAs: monday) {
                startMonday = monday
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("学习计划")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText(for: colorScheme))

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(AppTheme.elevatedBackground(for: colorScheme)))
                    .overlay(Circle().strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.75))
            }
            .buttonStyle(.plain)
            .help("关闭")
            .accessibilityLabel("关闭学习计划")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 15)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(result == nil ? "取消" : "关闭") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)

            Spacer()

            if let result {
                Button(result.addedCount > 0 ? "查看今天任务" : "完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
            } else {
                Button {
                    let imported = taskStore.importAcceleratedStudyPlan(
                        startMonday: startMonday,
                        calendar: calendar
                    )
                    result = imported
                    if imported.addedCount > 0 { onImported() }
                } label: {
                    Label(
                        availableCount > 0 ? "导入 \(availableCount) 项" : "已全部导入",
                        systemImage: availableCount > 0 ? "arrow.down.to.line" : "checkmark"
                    )
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .disabled(availableCount == 0)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private var previewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                routeOverview

                VStack(spacing: 12) {
                    ForEach(1...4, id: \.self) { week in
                        weekCard(week)
                    }
                }

                if let dailyDraft {
                    dailyPracticeRow(dailyDraft)
                }

                if existingDraftCount > 0 {
                    Text("已导入 \(existingDraftCount) 项 · 保留已有进度")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
                        .padding(.horizontal, 3)
                        .padding(.top, 1)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .accessibilityLabel("学习计划预览")
    }

    private var routeOverview: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("四周路线 · \(drafts.count) 项")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText(for: colorScheme))

                Text(routeDateRange)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
            }

            Spacer(minLength: 6)

            DatePicker("开始日期", selection: $startMonday, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .accessibilityLabel("路线开始日期，自动调整到周一")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(AppTheme.cardBackground(for: colorScheme))
        .clipShape(AppTheme.squircle(radius: 14))
        .overlay(AppTheme.squircle(radius: 14).strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.8))
    }

    private func weekCard(_ week: Int) -> some View {
        let weekStart = calendar.date(byAdding: .day, value: 7 * (week - 1), to: calendar.startOfDay(for: startMonday)) ?? startMonday
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let weekDrafts = drafts.filter { draft in
            guard let date = draft.startDate else { return false }
            return calendar.isDate(date, inSameDayAs: weekStart)
        }
        let tint = weekTint(week)

        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text("第 \(week) 周")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText(for: colorScheme))

                Text("\(shortDate(weekStart)) – \(shortDate(weekEnd))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.secondaryText(for: colorScheme))

                Spacer()

                Text("\(weekDrafts.count) 项")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
            }

            VStack(spacing: 0) {
                ForEach(Array(weekDrafts.enumerated()), id: \.element.planKey) { index, draft in
                    planRow(draft, tint: tint)
                    if index < weekDrafts.count - 1 {
                        Divider().padding(.leading, 25)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(AppTheme.cardBackground(for: colorScheme))
        .clipShape(AppTheme.squircle(radius: 14))
        .overlay(AppTheme.squircle(radius: 14).strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("第 \(week) 周，\(weekDrafts.count) 项")
    }

    private func planRow(_ draft: PlanTaskDraft, tint: Color) -> some View {
        let alreadyAdded = existingKeys.contains(draft.planKey)
        let detail: String = {
            if !draft.items.isEmpty { return "\(draft.items.count) \(draft.unit ?? "项")" }
            if draft.repeatsDaily { return "每日" }
            return "阶段任务"
        }()

        return HStack(spacing: 11) {
            Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(alreadyAdded ? Color.green : tint.opacity(0.7))
                .accessibilityHidden(true)

            Text(draft.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.primaryText(for: colorScheme))
                .lineLimit(1)

            Spacer(minLength: 6)

            Text(detail)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
                .lineLimit(1)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(draft.title)，\(detail)\(alreadyAdded ? "，已导入" : "")")
    }

    private func dailyPracticeRow(_ draft: PlanTaskDraft) -> some View {
        let isAdded = existingKeys.contains(draft.planKey)

        return HStack(spacing: 11) {
            Image(systemName: isAdded ? "checkmark.circle.fill" : "repeat")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isAdded ? Color.green : AppTheme.accent)
                .accessibilityHidden(true)

            Text(draft.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.primaryText(for: colorScheme))
                .lineLimit(1)

            Spacer(minLength: 6)

            Text("每日")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.cardBackground(for: colorScheme))
        .clipShape(AppTheme.squircle(radius: 14))
        .overlay(AppTheme.squircle(radius: 14).strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(draft.title)，每日\(isAdded ? "，已导入" : "")")
    }

    private func resultContent(_ result: TaskStore.StudyPlanImportResult) -> some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: result.addedCount > 0 ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.system(size: 48, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(result.addedCount > 0 ? Color.green : AppTheme.accent)
                .accessibilityHidden(true)

            Text(result.addedCount > 0 ? "已导入 \(result.addedCount) 项" : "路线已在计划中")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText(for: colorScheme))

            Text(result.skippedCount > 0
                 ? "已有 \(result.skippedCount) 项保持不变"
                 : "从 \(startMonday.formatted(date: .abbreviated, time: .omitted)) 开始")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText(for: colorScheme))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .accessibilityElement(children: .combine)
    }

    private var routeDateRange: String {
        let end = calendar.date(byAdding: .day, value: 27, to: calendar.startOfDay(for: startMonday)) ?? startMonday
        return "\(shortDate(startMonday)) – \(shortDate(end))"
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private func weekTint(_ week: Int) -> Color {
        switch week {
        case 1: return AppTheme.accent
        case 2: return Color(hex: "#4385F5")
        case 3: return Color(hex: "#8B6CE8")
        default: return Color(hex: "#E28A3B")
        }
    }
}
