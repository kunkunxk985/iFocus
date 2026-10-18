import SwiftUI
import AppKit
import iFocusCore

private enum SettingsWindowPanel: String, CaseIterable, Identifiable {
    case general = "通用"
    case timer = "专注与计时"
    case appearance = "外观与声音"
    case data = "数据与备份"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .timer: return "timer"
        case .appearance: return "paintpalette.fill"
        case .data: return "externaldrive.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .general: return Color(hex: "#3B82F6")
        case .timer: return Color(hex: "#E85A3C")
        case .appearance: return Color(hex: "#8B5CF6")
        case .data: return Color(hex: "#10B981")
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "开机启动与快捷键操作"
        case .timer: return "番茄时长、自动流转与每日目标"
        case .appearance: return "界面外观、菜单栏与提示音"
        case .data: return "本地数据存储与安全备份"
        }
    }
}

struct SettingsWindowView: View {
    @State private var selectedPanel: SettingsWindowPanel = .general
    @State private var pendingRestorePreview: DataBackupService.RestorePreview?
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.colorScheme) private var colorScheme

    private let sidebarWidth: CGFloat = 200

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
                .frame(width: sidebarWidth)

            // Content pane
            VStack(alignment: .leading, spacing: 0) {
                panelHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch selectedPanel {
                        case .general: generalPanel
                        case .timer: timerPanel
                        case .appearance: appearancePanel
                        case .data: dataPanel
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)
                }
                .softScroll()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.contentBackground(for: colorScheme).ignoresSafeArea())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Same canvas as the main window behind the glass sidebar card; with a clear root the
        // margin around the card and the gap before the content pane showed the desktop.
        .background(AppTheme.contentBackground(for: colorScheme).ignoresSafeArea())
        // Like the main window: the sidebar card runs under the transparent titlebar so the
        // traffic lights sit on it. Otherwise they float over the clear window background,
        // look misplaced, and clicks on them can fall through the window.
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            timerStore.updateNotificationStatus()
            settings.refreshLaunchAtLoginFromSystem()
        }
        .onDisappear {
            settings.sanitizeUsername()
        }
        .alert(item: $pendingRestorePreview) { preview in
            Alert(
                title: Text("确认覆盖当前数据？"),
                message: Text(restorePreviewMessage(preview)),
                primaryButton: .destructive(Text("覆盖并恢复")) {
                    performRestore(preview)
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    // MARK: - Sidebar

    private var settingsSidebar: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    Spacer(minLength: 0)
                }
                .frame(height: AppTheme.topHeaderHeight)

                Text("偏好设置")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                VStack(spacing: 3) {
                    ForEach(SettingsWindowPanel.allCases) { panel in
                        settingsSidebarRow(panel)
                    }
                }
                .padding(.horizontal, 10)

                Spacer()

                // Footer version mark
                VStack(alignment: .leading, spacing: 3) {
                    Divider().opacity(0.3)
                    HStack {
                        Text("iFocus \(AppVersion.short) (\(AppVersion.build))")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.75))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                }
            }
        }
        .adaptiveGlass(cornerRadius: AppTheme.radiusXL, fallbackMaterial: .sidebar)
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
    }

    private func settingsSidebarRow(_ panel: SettingsWindowPanel) -> some View {
        let isSelected = selectedPanel == panel
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedPanel = panel
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(panel.iconColor.opacity(isSelected ? 0.22 : 0.12))
                        .frame(width: 26, height: 26)
                    Image(systemName: panel.icon)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(panel.iconColor)
                }

                Text(panel.rawValue)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected
                                     ? AppTheme.primaryText(for: colorScheme)
                                     : AppTheme.primaryText(for: colorScheme).opacity(0.85))

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected
                          ? AppTheme.accent.opacity(colorScheme == .light ? 0.11 : 0.18)
                          : Color.clear)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(AppTheme.accent)
                        .frame(width: 3, height: 16)
                        .padding(.leading, 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var panelHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selectedPanel.iconColor.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: selectedPanel.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(selectedPanel.iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedPanel.rawValue)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                Text(selectedPanel.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, AppTheme.detailTopInset)
        .padding(.bottom, 16)
    }

    // MARK: - Panels

    // 1. General Panel (通用)
    private var generalPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsGroup(title: "启动与习惯") {
                SettingsRow(
                    title: "登录时自动打开 iFocus",
                    subtitle: "开机登录 Mac 时自动在后台就绪"
                ) {
                    Toggle("", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { newValue in
                            settings.launchAtLogin = newValue
                            settings.applyLaunchAtLoginPreference()
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                SettingsDivider()

                SettingsRow(
                    title: "智能进入今日清单",
                    subtitle: "若今天有待办事项，启动时优先进入「今天」"
                ) {
                    Toggle("", isOn: $settings.smartLaunchLanding)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            SettingsGroup(title: "快捷键与操作") {
                SettingsRow(
                    title: "开始 / 暂停全局快捷键",
                    subtitle: "处于前台时随时起停计时"
                ) {
                    Picker("", selection: $settings.toggleShortcut) {
                        ForEach(ToggleShortcutPreset.allCases) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }

                SettingsDivider()

                SettingsRow(
                    title: "常用操作一览",
                    subtitle: "提高日常使用效率"
                ) {
                    VStack(alignment: .trailing, spacing: 5) {
                        shortcutBadge("空格", "专注页快速起停")
                        shortcutBadge("⌘1", "专注钟")
                        shortcutBadge("⌘2", "数据统计")
                        shortcutBadge("⌘3", "今天清单")
                        shortcutBadge("⌘,", "打开设置")
                    }
                }
            }
        }
    }

    private func shortcutBadge(_ key: String, _ desc: String) -> some View {
        HStack(spacing: 6) {
            Text(desc)
                .font(.system(size: 11.5))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(AppTheme.elevatedBackground(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                )
        }
    }

    // 2. Timer Panel (专注与计时)
    private var timerPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsGroup(title: "番茄时钟节奏") {
                SettingsRow(
                    title: "专注用正计时",
                    subtitle: "从 00:00 往上数，学完点「完成」记录；满 \(TimerStore.countUpCapMinutes / 60) 小时自动结束"
                ) {
                    Toggle("", isOn: $settings.countUpWork)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .onChange(of: settings.countUpWork) { _ in
                    if timerStore.mode == .work { timerStore.syncDurationFromSettingsIfIdle() }
                }

                SettingsDivider()

                DurationSettingRow(
                    title: "专注时长",
                    subtitle: "单次专注倒计时",
                    minutes: $settings.workMinutes,
                    range: 1...90,
                    step: 5,
                    quickPills: [15, 25, 45, 60]
                ) {
                    if timerStore.mode == .work { timerStore.syncDurationFromSettingsIfIdle() }
                }

                SettingsDivider()

                DurationSettingRow(
                    title: "短休息",
                    subtitle: "单个番茄结束后的放松时长",
                    minutes: $settings.shortBreakMinutes,
                    range: 1...30,
                    step: 1,
                    quickPills: [3, 5, 10]
                ) {
                    if timerStore.mode == .shortBreak { timerStore.syncDurationFromSettingsIfIdle() }
                }

                SettingsDivider()

                DurationSettingRow(
                    title: "长休息",
                    subtitle: "完成数个番茄后深度休息时长",
                    minutes: $settings.longBreakMinutes,
                    range: 5...60,
                    step: 5,
                    quickPills: [15, 20, 30]
                ) {
                    if timerStore.mode == .longBreak { timerStore.syncDurationFromSettingsIfIdle() }
                }

                SettingsDivider()

                SettingsRow(
                    title: "长休触发间隔",
                    subtitle: "每完成特定个专注番茄后进入长休"
                ) {
                    HStack(spacing: 6) {
                        Text("每 \(settings.longBreakEvery) 个番茄")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primaryText(for: colorScheme))
                        Stepper("", value: $settings.longBreakEvery, in: 2...8, step: 1)
                            .labelsHidden()
                            .controlSize(.small)
                    }
                }
            }

            SettingsGroup(title: "自动化流转") {
                SettingsRow(
                    title: "专注结束后自动休息",
                    subtitle: "番茄倒计时归零后自动开启休息计时"
                ) {
                    Toggle("", isOn: $settings.autoStartBreaks)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                SettingsDivider()

                SettingsRow(
                    title: "休息结束后自动专注",
                    subtitle: "休息倒计时结束后自动开启下一轮专注"
                ) {
                    Toggle("", isOn: $settings.autoStartWork)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                SettingsDivider()

                SettingsRow(
                    title: "严格自律模式",
                    subtitle: "专注进行中禁用跳过按键，避免中途分心"
                ) {
                    Toggle("", isOn: $settings.strictMode)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            SettingsGroup(title: "每日目标与提醒") {
                SettingsRow(
                    title: "每日目标番茄数",
                    subtitle: "今天计划达成的专注目标"
                ) {
                    HStack(spacing: 6) {
                        Text("\(settings.dailyGoal) 个番茄")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primaryText(for: colorScheme))
                        Stepper("", value: $settings.dailyGoal, in: 1...20, step: 1)
                            .labelsHidden()
                            .controlSize(.small)
                    }
                }

                SettingsDivider()

                SettingsRow(
                    title: "暂停过久提醒",
                    subtitle: "计时暂停超过设定时长后提醒恢复专注"
                ) {
                    HStack(spacing: 8) {
                        if settings.pauseReminderEnabled {
                            HStack(spacing: 4) {
                                Text("\(settings.pauseReminderMinutes) 分钟")
                                    .font(.system(size: 12, weight: .semibold))
                                Stepper("", value: $settings.pauseReminderMinutes, in: 1...60, step: 1)
                                    .labelsHidden()
                                    .controlSize(.small)
                            }
                        }
                        Toggle("", isOn: $settings.pauseReminderEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
            }
        }
    }

    // 3. Appearance & Audio Panel (外观与声音)
    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsGroup(title: "界面外观") {
                SettingsRow(
                    title: "外观模式",
                    subtitle: "窗口与界面主题明暗"
                ) {
                    Picker("", selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                }

                SettingsDivider()

                SettingsRow(
                    title: "主强调色",
                    subtitle: "按钮、图表与状态指示色"
                ) {
                    HStack(spacing: 10) {
                        ForEach(AccentPreset.allCases) { preset in
                            let selected = settings.accentPreset == preset
                            Button {
                                settings.accentPreset = preset
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(preset.color)
                                        .frame(width: 22, height: 22)
                                    if selected {
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                            .frame(width: 14, height: 14)
                                    }
                                }
                                .padding(3)
                                .background(
                                    Circle()
                                        .stroke(selected ? preset.color : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                            .help(preset.label)
                        }
                    }
                }

                SettingsDivider()

                SettingsRow(
                    title: "菜单栏图标样式",
                    subtitle: "顶部系统菜单栏常驻显示"
                ) {
                    Picker("", selection: $settings.menuBarDisplayStyle) {
                        ForEach(MenuBarDisplayStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }

                SettingsDivider()

                SettingsRow(
                    title: "动态光晕与微动效",
                    subtitle: "表盘呼吸感光圈与达成微弹动效"
                ) {
                    Toggle("", isOn: $settings.decorativeMotionEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            SettingsGroup(title: "声音与通知") {
                SettingsRow(
                    title: "结束提示音",
                    subtitle: "专注钟或休息倒计时完成时播放"
                ) {
                    Toggle("", isOn: $settings.soundEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                if settings.soundEnabled {
                    SettingsDivider()

                    SettingsRow(
                        title: "提示音效",
                        subtitle: "可点按试听音效"
                    ) {
                        HStack(spacing: 8) {
                            Picker("", selection: $settings.soundName) {
                                ForEach(SettingsStore.availableSounds, id: \.self) { name in
                                    Text(name as String).tag(name)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)

                            Button {
                                NSSound(named: settings.soundName)?.play()
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.accent)
                                    .frame(width: 26, height: 26)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(AppTheme.accent.opacity(0.12))
                                    )
                            }
                            .buttonStyle(.plain)
                            .help("试听声音")
                        }
                    }
                }

                SettingsDivider()

                SettingsRow(
                    title: "触觉反馈",
                    subtitle: "完成任务、切换模式与按键时的触感反馈"
                ) {
                    Toggle("", isOn: $settings.hapticsEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                SettingsDivider()

                SettingsRow(
                    title: "系统通知",
                    subtitle: "倒计时结束时在屏幕右上角发送横幅"
                ) {
                    HStack(spacing: 8) {
                        Text(timerStore.notificationStatus)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(timerStore.notificationStatus == "已拒绝" ? .red : AppTheme.secondaryText(for: colorScheme))

                        if timerStore.notificationStatus == "已授权" {
                            Button("发送测试通知") {
                                timerStore.notificationFeedback = nil
                                timerStore.sendTestNotification()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Button(timerStore.notificationActionTitle) {
                                timerStore.handleNotificationPermissionAction()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                SettingsDivider()

                SettingsRow(
                    title: "Dock 图标轻弹",
                    subtitle: "计时结束时 Dock 图标轻弹一次"
                ) {
                    Toggle("", isOn: $settings.dockBounceOnComplete)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
        }
    }

    // 4. Data & Backup Panel (数据与备份)
    private var dataPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsGroup(title: "本地数据状态") {
                SettingsRow(
                    title: "当前记录概览",
                    subtitle: "\(taskStore.tasks.count) 个任务 · \(taskStore.focusSessions.count) 次专注历史"
                ) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#10B981"))
                        Text("纯本地离线存储")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#10B981"))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#10B981").opacity(0.12))
                    )
                }
            }

            SettingsGroup(title: "备份与恢复") {
                SettingsRow(
                    title: "导出完整数据备份",
                    subtitle: "包含所有清单任务、番茄记录与偏好设置"
                ) {
                    Button("导出备份…") {
                        switch DataBackupService.exportBackup(
                            taskStore: taskStore,
                            settings: settings,
                            appVersion: AppVersion.short
                        ) {
                        case .success(let url):
                            settings.backupFeedback = "已成功导出到：\(url.lastPathComponent)"
                        case .failure(let error):
                            if !(error is DataBackupService.CancelError) {
                                settings.backupFeedback = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }

                SettingsDivider()

                SettingsRow(
                    title: "从备份文件恢复",
                    subtitle: "安全导入此前的备份，覆盖前会自动备份当前数据"
                ) {
                    Button("从备份恢复…") {
                        switch DataBackupService.selectBackup() {
                        case .success(let preview):
                            settings.backupFeedback = nil
                            pendingRestorePreview = preview
                        case .failure(let error):
                            if !(error is DataBackupService.CancelError) {
                                settings.backupFeedback = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }

            if let feedback = settings.backupFeedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .padding(.horizontal, 6)
            }

            SettingsGroup(title: "数据安全与存储目录") {
                SettingsRow(
                    title: "每日自动安全快照",
                    subtitle: "每次启动自动保留最近 5 天的数据快照，升级无忧"
                ) {
                    Text("自动保护中")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#10B981"))
                }

                SettingsDivider()

                SettingsRow(
                    title: "在访达 (Finder) 中显示数据",
                    subtitle: "查看 tasks.json 与 focus_sessions.json 所在目录"
                ) {
                    Button("打开数据文件夹") {
                        settings.openDataFolderInFinder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                SettingsDivider()

                SettingsRow(
                    title: "学习记录（表格与周报）",
                    subtitle: "每次记录专注都会自动更新 ~/StudyLog 里的 sessions.csv 和每周报告"
                ) {
                    Button("打开学习记录") {
                        settings.openStudyLogFolderInFinder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private func restorePreviewMessage(_ preview: DataBackupService.RestorePreview) -> String {
        let summary = preview.summary
        var lines = [
            "备份文件：\(preview.package.directory.lastPathComponent)",
            "任务条数：\(summary.taskCount.map(String.init) ?? "未包含")",
            "专注历史：\(summary.sessionCount.map(String.init) ?? "未包含")"
        ]
        if let manifest = preview.package.manifest {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            lines.append("导出版本：\(manifest.appVersion) · \(formatter.string(from: manifest.exportedAt))")
        }
        lines.append("当前数据会在覆盖前自动存档，若恢复失败将自动回滚。")
        return lines.joined(separator: "\n")
    }

    private func performRestore(_ preview: DataBackupService.RestorePreview) {
        switch DataBackupService.restoreBackup(
            preview,
            taskStore: taskStore,
            settings: settings,
            timerStore: timerStore
        ) {
        case .success(let outcome):
            let summary = outcome.preview.summary
            let tasks = summary.taskCount.map { "\($0) 任务" } ?? "任务未变"
            let sessions = summary.sessionCount.map { "\($0) 条记录" } ?? "记录未变"
            settings.backupFeedback = "已成功恢复（\(tasks) · \(sessions)）"
            timerStore.updateStatsFromHistory(taskStore: taskStore)
        case .failure(let error):
            settings.backupFeedback = "恢复未完成：\(error.localizedDescription)；当前数据已安全保留。"
        }
    }
}

// MARK: - Reusable Settings Components

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.cardBackground(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
            )
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 16)
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct SettingsDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Divider()
            .padding(.leading, 14)
            .opacity(colorScheme == .light ? 0.6 : 0.4)
    }
}

private struct DurationSettingRow: View {
    let title: String
    let subtitle: String
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    let step: Int
    let quickPills: [Int]
    var onCommit: () -> Void = {}
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
            Spacer(minLength: 12)

            // Quick preset pills
            HStack(spacing: 4) {
                ForEach(quickPills, id: \.self) { pill in
                    Button {
                        minutes = pill
                        onCommit()
                    } label: {
                        Text("\(pill)′")
                            .font(.system(size: 11, weight: minutes == pill ? .bold : .medium, design: .rounded))
                            .foregroundColor(minutes == pill ? AppTheme.accent : AppTheme.secondaryText(for: colorScheme))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(minutes == pill
                                          ? AppTheme.accent.opacity(colorScheme == .light ? 0.14 : 0.22)
                                          : (colorScheme == .light ? Color.black.opacity(0.04) : Color.white.opacity(0.06)))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Stepper with digital display
            HStack(spacing: 6) {
                Text("\(minutes) 分钟")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    .frame(minWidth: 48, alignment: .trailing)

                Stepper("", value: $minutes, in: range, step: step)
                    .labelsHidden()
                    .controlSize(.small)
                    .onChange(of: minutes) { _ in onCommit() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

enum AppWindowMetrics {
    static let minimum = WindowLayoutMetrics.minimum
    static let defaultSize = WindowLayoutMetrics.defaultSize
}

enum AppVersion {
    static var short: String {
        if let fromBundle = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !fromBundle.isEmpty, fromBundle != "1.0" {
            return fromBundle
        }
        return versionFileLines()?.first ?? "dev"
    }
    static var build: String {
        if let fromBundle = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           !fromBundle.isEmpty {
            return fromBundle
        }
        return versionFileLines()?.dropFirst().first ?? "0"
    }

    private static func versionFileLines() -> [String]? {
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<6 {
            let candidate = dir.appendingPathComponent("VERSION")
            if let text = try? String(contentsOf: candidate, encoding: .utf8) {
                let lines = text.split(whereSeparator: \.isNewline).map(String.init)
                if lines.count >= 2 { return lines }
            }
            dir.deleteLastPathComponent()
        }
        return nil
    }
}
