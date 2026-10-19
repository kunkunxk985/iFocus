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
        .frame(width: 620, height: 720)
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
            ZStack {
                AppTheme.squircle(radius: 12)
                    .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.12 : 0.20))
                Image(systemName: "map.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: 38, height: 38)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(result == nil ? "学习路线" : "路线已处理")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText(for: colorScheme))
                Text(result == nil ? "加速版 · 四周路线" : "学习计划导入结果")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(AppTheme.elevatedBackground(for: colorScheme)))
                    .overlay(Circle().strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.75))
            }
            .buttonStyle(.plain)
            .help("关闭")
            .accessibilityLabel("关闭学习计划导入")
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 14)
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
            VStack(alignment: .leading, spacing: 16) {
                routeOverview

                HStack(alignment: .firstTextBaseline) {
                    Text("四周路线")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText(for: colorScheme))
                    Spacer()
                    Text("按周推进 · 可随时调整")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
                }
                .padding(.horizontal, 2)
                .padding(.top, 2)

                VStack(spacing: 9) {
                    ForEach(1...4, id: \.self) { week in
                        weekCard(week)
                    }
                }

                if let dailyDraft {
                    dailyPracticeCard(dailyDraft)
                }

                if existingDraftCount > 0 {
                    Label(
                        "已有 \(existingDraftCount) 项会自动跳过，原有进度和笔记会保留。",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 3)
                    .padding(.bottom, 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .accessibilityLabel("学习计划路线预览")
    }

    private var routeOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent.opacity(0.22), AppTheme.accent.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("从数学基础走向深度学习")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .tracking(-0.2)
                        .foregroundStyle(AppTheme.primaryText(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text("循序推进，把大目标拆成每周可完成的小步。")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                metric(value: "4 周", caption: "学习阶段", symbol: "calendar", tint: AppTheme.accent)
                metric(value: "\(drafts.count) 项", caption: "路线任务", symbol: "checklist", tint: Color(hex: "#4385F5"))
                metric(value: "每日 1 题", caption: "持续练习", symbol: "repeat", tint: Color(hex: "#8B6CE8"))
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("开始日期")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
                    Text(routeDateRange)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.primaryText(for: colorScheme))
                }
                Spacer(minLength: 4)
                DatePicker("路线开始日期", selection: $startMonday, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .accessibilityLabel("路线开始日期，自动调整到周一")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.72 : 0.58))
            .clipShape(AppTheme.squircle(radius: 11))
            .overlay(AppTheme.squircle(radius: 11).strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.75))
        }
        .padding(17)
        .background(overviewSurface)
        .accessibilityElement(children: .contain)
    }

    private var overviewSurface: some View {
        AppTheme.squircle(radius: 18)
            .fill(
                LinearGradient(
                    colors: colorScheme == .light
                        ? [Color.white, Color(hex: "#F7F8FC"), AppTheme.accent.opacity(0.055)]
                        : [Color(hex: "#26262C"), Color(hex: "#202025"), AppTheme.accent.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.accent.opacity(colorScheme == .light ? 0.13 : 0.17), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 125
                        )
                    )
                    .frame(width: 250, height: 250)
                    .offset(x: 76, y: -84)
                    .allowsHitTesting(false)
            }
            .overlay(AppTheme.squircle(radius: 18).strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1))
            .overlay(AppTheme.squircle(radius: 18).strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 0.75))
            .clipShape(AppTheme.squircle(radius: 18))
            .shadow(color: AppTheme.softShadow(for: colorScheme), radius: 12, x: 0, y: 5)
    }

    private func metric(value: String, caption: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(colorScheme == .light ? 0.11 : 0.18), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText(for: colorScheme))
                Text(caption)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground(for: colorScheme).opacity(colorScheme == .light ? 0.72 : 0.54), in: AppTheme.squircle(radius: 10))
        .overlay(AppTheme.squircle(radius: 10).strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.6))
        .accessibilityElement(children: .combine)
    }

    private func weekCard(_ week: Int) -> some View {
        let weekStart = calendar.date(byAdding: .day, value: 7 * (week - 1), to: calendar.startOfDay(for: startMonday)) ?? startMonday
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let weekDrafts = drafts.filter { draft in
            guard let date = draft.startDate else { return false }
            return calendar.isDate(date, inSameDayAs: weekStart)
        }
        let tint = weekTint(week)

        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Text(String(format: "%02d", week))
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(colorScheme == .light ? 0.12 : 0.20), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("第 \(week) 周")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText(for: colorScheme))
                    Text("\(shortDate(weekStart)) – \(shortDate(weekEnd))")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
                }

                Spacer()

                Text("\(weekDrafts.count) 项")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tint.opacity(colorScheme == .light ? 0.09 : 0.15), in: Capsule())
            }

            VStack(spacing: 2) {
                ForEach(weekDrafts, id: \.planKey) { draft in
                    planRow(draft, tint: tint)
                }
            }
            .padding(.leading, 37)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(AppTheme.cardBackground(for: colorScheme))
        .clipShape(AppTheme.squircle(radius: 14))
        .overlay(AppTheme.squircle(radius: 14).strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.9))
        .shadow(color: AppTheme.softShadow(for: colorScheme).opacity(0.65), radius: 7, x: 0, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("第 \(week) 周，\(weekDrafts.count) 项")
    }

    private func planRow(_ draft: PlanTaskDraft, tint: Color) -> some View {
        let alreadyAdded = existingKeys.contains(draft.planKey)
        let detail: String = {
            if !draft.items.isEmpty { return "\(draft.items.count) \(draft.unit ?? "项")" }
            if draft.repeatsDaily { return "每日练习" }
            return "阶段任务"
        }()

        return HStack(spacing: 8) {
            Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(alreadyAdded ? Color.green : tint.opacity(0.64))
                .accessibilityHidden(true)

            Text(draft.title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(AppTheme.primaryText(for: colorScheme).opacity(0.92))
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(detail)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.contentBackground(for: colorScheme).opacity(colorScheme == .light ? 0.62 : 0.52), in: AppTheme.squircle(radius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(draft.title)，\(detail)\(alreadyAdded ? "，已存在" : "")")
    }

    private func dailyPracticeCard(_ draft: PlanTaskDraft) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: "#8B6CE8").opacity(colorScheme == .light ? 0.12 : 0.20))
                Image(systemName: existingKeys.contains(draft.planKey) ? "checkmark" : "repeat")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#8B6CE8"))
            }
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text("每日练习")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "#8B6CE8"))
                    Text("持续习惯")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
                }
                Text(draft.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText(for: colorScheme))
                    .lineLimit(1)
                Text(draft.notes)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if existingKeys.contains(draft.planKey) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
                    .accessibilityLabel("已存在")
            }
        }
        .padding(12)
        .background(AppTheme.squircle(radius: 13).fill(Color(hex: "#8B6CE8").opacity(colorScheme == .light ? 0.055 : 0.10)))
        .overlay(AppTheme.squircle(radius: 13).strokeBorder(Color(hex: "#8B6CE8").opacity(0.16), lineWidth: 0.8))
        .accessibilityElement(children: .combine)
    }

    private func resultContent(_ result: TaskStore.StudyPlanImportResult) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 22)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.accent.opacity(0.18), AppTheme.accent.opacity(0.04)],
                            center: .center,
                            startRadius: 8,
                            endRadius: 66
                        )
                    )
                    .frame(width: 116, height: 116)
                Image(systemName: result.addedCount > 0 ? "checkmark.circle.fill" : "info.circle.fill")
                    .font(.system(size: 48, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(result.addedCount > 0 ? Color.green : AppTheme.accent)
            }
            .accessibilityHidden(true)

            Text(result.addedCount > 0 ? "路线已加入任务" : "路线已是最新")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .tracking(-0.25)
                .foregroundStyle(AppTheme.primaryText(for: colorScheme))
                .padding(.top, 12)

            Text(result.addedCount > 0
                 ? "接下来按周推进即可，已有记录会继续保留。"
                 : "这条路线已全部存在，没有重复创建任务。")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)

            HStack(spacing: 10) {
                resultMetric(value: result.addedCount, title: "新增任务", symbol: "plus", tint: Color(hex: "#1FA978"))
                resultMetric(value: result.skippedCount, title: "保留已有", symbol: "checkmark", tint: AppTheme.accent)
            }
            .padding(.top, 22)

            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(AppTheme.accent)
                Text("从 \(startMonday.formatted(date: .abbreviated, time: .omitted)) 开始 · 日期已对齐到周一")
                    .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
            }
            .font(.system(size: 10.5, weight: .medium))
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(AppTheme.elevatedBackground(for: colorScheme).opacity(0.65), in: Capsule())
            .padding(.top, 16)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .accessibilityElement(children: .combine)
    }

    private func resultMetric(value: Int, title: String, symbol: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
                Text("\(value)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground(for: colorScheme), in: AppTheme.squircle(radius: 13))
        .overlay(AppTheme.squircle(radius: 13).strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.8))
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
