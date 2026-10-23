import SwiftUI
import AppKit
import iFocusCore

private enum SettingsWindowPanel: String, CaseIterable, Identifiable {
    case general = "通用"
    case timer = "专注与计时"
    case appearance = "外观与声音"
    case data = "数据与备份"
    case status = "状态中心"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .timer: return "timer"
        case .appearance: return "paintpalette"
        case .data: return "externaldrive"
        case .status: return "checkmark.shield"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "开机启动与快捷键操作"
        case .timer: return "番茄时长、自动流转与每日目标"
        case .appearance: return "界面外观、菜单栏与提示音"
        case .data: return "本地数据存储与安全备份"
        case .status: return "权限、系统与数据健康"
        }
    }

    /// Extra search keywords for the row titles inside the pane; keeps search useful
    /// without building a full settings index.
    var searchTerms: String {
        switch self {
        case .general:
            return "登录 开机 自动打开 智能 今日 清单 快捷键 空格 暂停 新手 引导 欢迎 帮助 教程 分类 标签 自定义 颜色 图标 管理"
        case .timer:
            return "正计时 专注时长 短休息 长休息 长休 自动休息 自动专注 严格自律 每日目标 暂停提醒 系统专注模式"
        case .appearance:
            return "外观 浅色 深色 跟随系统 强调色 菜单栏 图标 动态光晕 动效 界面密度 舒适 紧凑 提示音 声音 触觉 程序坞 Dock"
        case .data:
            return "数据 本地 离线 任务 专注历史 导出 备份 恢复 快照 自动保护 访达 Finder 文件夹 存储"
        case .status:
            return "状态 健康 权限 通知 登录项 系统专注 数据 文件 备份 版本 检查"
        }
    }

    func matches(_ query: String) -> Bool {
        let tokens = query.split(whereSeparator: \.isWhitespace)
        guard !tokens.isEmpty else { return true }
        let haystack = "\(rawValue) \(subtitle) \(searchTerms)"
        return tokens.allSatisfy { haystack.localizedCaseInsensitiveContains(String($0)) }
    }
}

struct SettingsWindowView: View {
    @State private var selectedPanel: SettingsWindowPanel = .general
    @State private var pendingRestorePreview: DataBackupService.RestorePreview?
    @State private var showCategoryManager = false
    @ObservedObject private var search = SettingsSearchModel.shared
    @FocusState private var focusedPanel: SettingsWindowPanel?
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var timerStore: TimerStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.colorScheme) private var colorScheme

    private let sidebarWidth: CGFloat = 200

    private var visiblePanels: [SettingsWindowPanel] {
        SettingsWindowPanel.allCases.filter { $0.matches(search.query) }
    }

    private var isSearching: Bool {
        !search.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Keeps the detail pane and the sidebar on a pane that survived the filter.
    private var activePanel: SettingsWindowPanel {
        visiblePanels.contains(selectedPanel) ? selectedPanel : (visiblePanels.first ?? selectedPanel)
    }

    /// Plain on/off confirmations are visible from the switch itself; only surface
    /// messages that need the user to do something (approval, failure, system removal).
    private var loginItemFeedback: String? {
        guard let feedback = settings.launchAtLoginFeedback else { return nil }
        if feedback.hasPrefix("已开启") || feedback.hasPrefix("已关闭") { return nil }
        return feedback
    }

    private var healthIssueCount: Int {
        var count = 0
        if taskStore.dataLoadErrorMessage != nil { count += 1 }
        if timerStore.notificationStatus == "已拒绝" { count += 1 }
        if LaunchAtLogin.needsAttention(userWantsEnabled: settings.launchAtLogin) { count += 1 }
        if let feedback = settings.backupFeedback,
           feedback.contains("失败") || feedback.contains("未完成") {
            count += 1
        }
        return count
    }

    private var statusPanel: some View {
        SettingsStatusPanel(onOpenData: { selectedPanel = .data })
    }

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar
                .frame(width: sidebarWidth)

            // Content pane
            VStack(alignment: .leading, spacing: 0) {
                if visiblePanels.isEmpty {
                    searchEmptyState
                } else {
                    panelHeader

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            switch activePanel {
                            case .general: generalPanel
                            case .timer: timerPanel
                            case .appearance: appearancePanel
                            case .data: dataPanel
                            case .status: statusPanel
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 32)
                    }
                    .softScroll()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.contentBackground(for: colorScheme).ignoresSafeArea())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Same canvas as the main window behind the sidebar material; with a clear root the
        // margin around the sidebar and the gap before the content pane showed the desktop.
        .background(AppTheme.contentBackground(for: colorScheme).ignoresSafeArea())
        // Like the main window: the sidebar runs full-bleed under the transparent titlebar
        // so the traffic lights sit on it. Otherwise they float over the clear window
        // background, look misplaced, and clicks on them can fall through the window.
        .ignoresSafeArea(.container, edges: .top)
        // The app's accent is a preference, not the system accent, so controls must
        // inherit it explicitly or prominent buttons fall back to system blue.
        .tint(AppTheme.accent)
        .onAppear {
            timerStore.updateNotificationStatus()
            settings.refreshLaunchAtLoginFromSystem()
            if let window = NSApplication.shared.windows.first(where: { $0.title == "设置" }) {
                SettingsWindowToolbar.shared.install(on: window)
            }
            reconcileSelectionWithSearch()
        }
        .onChange(of: search.query) { _ in
            reconcileSelectionWithSearch()
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
        .sheet(isPresented: $showCategoryManager) {
            CategoryManagementView()
                .environmentObject(taskStore)
        }
    }

    // MARK: - Sidebar

    private var settingsSidebar: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Clear the 52pt titlebar band, then a little breathing room.
                Color.clear
                    .frame(height: AppTheme.detailTopInset + 4)

                Text(isSearching ? "搜索结果" : "设置")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                VStack(spacing: 3) {
                    ForEach(visiblePanels) { panel in
                        settingsSidebarRow(panel)
                    }
                }
                .padding(.horizontal, 10)

                Spacer()

                // Footer version mark
                VStack(alignment: .leading, spacing: 3) {
                    Rectangle()
                        .fill(AppTheme.separator(for: colorScheme).opacity(0.6))
                        .frame(height: 0.5)
                    HStack {
                        Text("iFocus \(AppVersion.short) (\(AppVersion.build))")
                            .font(.system(size: 11, design: .rounded).monospacedDigit())
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.75))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                }
            }
        }
        // Full-bleed, like the main window: the material runs under the titlebar so
        // the window buttons sit on it, and the window's own shape clips the corners.
        .adaptiveGlass(cornerRadius: 0, fallbackMaterial: .sidebar)
        .padding(.trailing, 4)
    }

    private func settingsSidebarRow(_ panel: SettingsWindowPanel) -> some View {
        let isSelected = activePanel == panel
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedPanel = panel
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: panel.icon)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText(for: colorScheme))
                    .frame(width: 20, height: 20)
                    .overlay(alignment: .topTrailing) {
                        if panel == .status, healthIssueCount > 0 {
                            Circle()
                                .fill(AppTheme.warning)
                                .frame(width: 6, height: 6)
                        }
                    }

                Text(panel.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected
                                     ? AppTheme.primaryText(for: colorScheme)
                                     : AppTheme.primaryText(for: colorScheme).opacity(0.86))

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(SettingsSidebarRowButtonStyle(isSelected: isSelected))
        .focused($focusedPanel, equals: panel)
        .onMoveCommand { direction in
            switch direction {
            case .up: movePanelSelection(by: -1)
            case .down: movePanelSelection(by: 1)
            default: break
            }
        }
        .overlay {
            if focusedPanel == panel {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(AppTheme.accent.opacity(0.9), lineWidth: 2)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func movePanelSelection(by offset: Int) {
        let panels = visiblePanels
        guard !panels.isEmpty else { return }
        let currentIndex = panels.firstIndex(of: activePanel) ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), panels.count - 1)
        guard nextIndex != currentIndex else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            selectedPanel = panels[nextIndex]
        }
        focusedPanel = panels[nextIndex]
    }

    private func reconcileSelectionWithSearch() {
        if !visiblePanels.contains(selectedPanel), let first = visiblePanels.first {
            selectedPanel = first
        }
        if let focusedPanel, !visiblePanels.contains(focusedPanel) {
            self.focusedPanel = visiblePanels.first
        }
    }

    private var panelHeader: some View {
        HStack(spacing: 12) {
            Text(activePanel.rawValue)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
            Spacer()
            if isSearching {
                Button("清除搜索") {
                    SettingsWindowToolbar.shared.clearSearchField()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.accent)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, AppTheme.detailTopInset)
        .padding(.bottom, 16)
    }

    private var searchEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .light))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.7))
            Text("没有找到相关设置")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            Button("清除搜索") {
                SettingsWindowToolbar.shared.clearSearchField()
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AppTheme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Panels

    // 1. General Panel (通用)
    private var generalPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsGroup(title: "启动") {
                SettingsRow(
                    title: "登录时自动打开",
                    subtitle: "开机后在后台打开",
                    keywords: "登录 开机 启动 登录项"
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
                    .accessibilityLabel("登录时自动打开 iFocus")
                }

                if let feedback = loginItemFeedback {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text(feedback)
                            .font(.system(size: 11.5))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button("打开系统设置…") {
                            LaunchAtLogin.openLoginItemsSettings()
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }

                SettingsDivider()

                SettingsRow(
                    title: "有今天的任务时，先打开今天",
                    keywords: "智能 今日 清单 启动"
                ) {
                    Toggle("", isOn: $settings.smartLaunchLanding)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel("智能进入今日清单")
                }
            }

            SettingsGroup(title: "快捷键") {
                SettingsRow(
                    title: "开始 / 暂停",
                    keywords: "快捷键 空格 暂停 开始"
                ) {
                    Picker("", selection: $settings.toggleShortcut) {
                        ForEach(ToggleShortcutPreset.allCases) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                    .accessibilityLabel("开始 / 暂停快捷键")
                }
            }

            SettingsGroup(title: "其他") {
                SettingsRow(
                    title: "任务分类",
                    keywords: "分类 标签 自定义 颜色 图标 管理"
                ) {
                    Button("管理…") {
                        showCategoryManager = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                SettingsDivider()

                SettingsRow(
                    title: "新手引导",
                    keywords: "新手 引导 欢迎 帮助 教程"
                ) {
                    Button("重新播放") {
                        UserDefaults.standard.set(true, forKey: AppNavigation.pendingOnboardingReplayKey)
                        NotificationCenter.default.post(name: AppNavigation.showOnboarding, object: nil)
                        WindowChromeController.shared.showMainWindow()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    // 2. Timer Panel (专注与计时)
    private var timerPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsGroup(title: "番茄时钟节奏") {
                SettingsRow(
                    title: "专注用正计时",
                    subtitle: "从 00:00 往上数，满 \(TimerStore.countUpCapMinutes / 60) 小时自动结束",
                    keywords: "正计时 番茄"
                ) {
                    Toggle("", isOn: $settings.countUpWork)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel("专注用正计时")
                }
                .onChange(of: settings.countUpWork) { _ in
                    if timerStore.mode == .work { timerStore.syncDurationFromSettingsIfIdle() }
                }

                SettingsDivider()

                DurationSettingRow(
                    title: "专注时长",
                    keywords: "专注时长 番茄 分钟",
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
                    keywords: "短休息 休息 分钟",
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
                    keywords: "长休息 长休 休息 分钟",
                    minutes: $settings.longBreakMinutes,
                    range: 5...60,
                    step: 5,
                    quickPills: [15, 20, 30]
                ) {
                    if timerStore.mode == .longBreak { timerStore.syncDurationFromSettingsIfIdle() }
                }

                SettingsDivider()

                SettingsRow(
                    title: "长休间隔",
                    keywords: "长休 间隔 番茄"
                ) {
                    HStack(spacing: 6) {
                        Text("每 \(settings.longBreakEvery) 个番茄")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primaryText(for: colorScheme))
                        Stepper("", value: $settings.longBreakEvery, in: 2...8, step: 1)
                            .labelsHidden()
                            .controlSize(.small)
                            .accessibilityLabel("长休触发间隔")
                    }
                }
            }

            SettingsGroup(title: "自动开始") {
                SettingsRow(
                    title: "专注结束后自动休息",
                    keywords: "自动休息 自动流转"
                ) {
                    Toggle("", isOn: $settings.autoStartBreaks)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel("专注结束后自动休息")
                }

                SettingsDivider()

                SettingsRow(
                    title: "休息结束后自动专注",
                    keywords: "自动专注 自动流转"
                ) {
                    Toggle("", isOn: $settings.autoStartWork)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel("休息结束后自动专注")
                }

                SettingsDivider()

                SettingsRow(
                    title: "进行中不能跳过",
                    subtitle: "打开后，专注时不能提前结束这一段",
                    keywords: "严格自律 跳过"
                ) {
                    Toggle("", isOn: $settings.strictMode)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel("严格自律模式")
                }

                SettingsDivider()

                SettingsRow(
                    title: "开始前提示系统专注",
                    subtitle: "提醒去系统设置里减少通知",
                    keywords: "系统专注模式 勿扰"
                ) {
                    Toggle("", isOn: $settings.showFocusModeHintOnStart)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel("开始专注时提示系统专注模式")
                }
            }

            SettingsGroup(title: "目标与提醒") {
                SettingsRow(
                    title: "每天的目标",
                    keywords: "每日目标 番茄"
                ) {
                    HStack(spacing: 6) {
                        Text("\(settings.dailyGoal) 个番茄")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primaryText(for: colorScheme))
                        Stepper("", value: $settings.dailyGoal, in: 1...20, step: 1)
                            .labelsHidden()
                            .controlSize(.small)
                            .accessibilityLabel("每日目标番茄数")
                    }
                }

                SettingsDivider()

                SettingsRow(
                    title: "暂停太久时提醒",
                    subtitle: "超过设定时间还没继续，就提示一下",
                    keywords: "暂停提醒"
                ) {
                    HStack(spacing: 8) {
                        if settings.pauseReminderEnabled {
                            HStack(spacing: 4) {
                                Text("\(settings.pauseReminderMinutes) 分钟")
                                    .font(.system(size: 12, weight: .semibold))
                                Stepper("", value: $settings.pauseReminderMinutes, in: 1...60, step: 1)
                                    .labelsHidden()
                                    .controlSize(.small)
                                    .accessibilityLabel("暂停提醒分钟数")
                            }
                        }
                        Toggle("", isOn: $settings.pauseReminderEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .accessibilityLabel("暂停过久提醒")
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
                    title: "外观",
                    keywords: "浅色 深色 跟随系统 主题"
                ) {
                    Picker("", selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                    .accessibilityLabel("外观模式")
                }

                SettingsDivider()

                SettingsRow(
                    title: "间距",
                    keywords: "界面密度 舒适 紧凑"
                ) {
                    Picker("", selection: $settings.uiDensity) {
                        ForEach(UIDensity.allCases) { density in
                            Text(density.label).tag(density)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                    .accessibilityLabel("界面密度")
                }

                SettingsDivider()

                SettingsRow(
                    title: "强调色",
                    keywords: "颜色 主题色"
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
                            .accessibilityLabel(preset.label)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                }

                SettingsDivider()

                SettingsRow(
                    title: "菜单栏",
                    keywords: "图标 菜单栏"
                ) {
                    Picker("", selection: $settings.menuBarDisplayStyle) {
                        ForEach(MenuBarDisplayStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                    .accessibilityLabel("菜单栏图标样式")
                }

                SettingsDivider()

                SettingsRow(
                    title: "圆环呼吸",
                    subtitle: "专注时圆环轻轻缩放",
                    keywords: "动态光晕 动效 动画"
                ) {
                    Toggle("", isOn: $settings.decorativeMotionEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel("动态光晕与微动效")
                }
            }

            SettingsGroup(title: "声音与反馈") {
                SettingsRow(
                    title: "结束时播放提示音",
                    keywords: "提示音 声音"
                ) {
                    Toggle("", isOn: $settings.soundEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel("结束提示音")
                }

                if settings.soundEnabled {
                    SettingsDivider()

                    SettingsRow(
                        title: "提示音",
                        keywords: "声音 音效 试听"
                    ) {
                        HStack(spacing: 8) {
                            Picker("", selection: $settings.soundName) {
                                ForEach(SettingsStore.availableSounds, id: \.self) { name in
                                    Text(name as String).tag(name)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                            .accessibilityLabel("提示音效")

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
                            .accessibilityLabel("试听提示音")
                        }
                    }
                }

                SettingsDivider()

                SettingsRow(
                    title: "按键触感",
                    keywords: "触觉 震动 反馈"
                ) {
                    Toggle("", isOn: $settings.hapticsEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel("触觉反馈")
                }

                SettingsDivider()

                SettingsRow(
                    title: "结束时程序坞图标跳一下",
                    keywords: "程序坞 Dock"
                ) {
                    Toggle("", isOn: $settings.dockBounceOnComplete)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .accessibilityLabel("程序坞图标轻弹")
                }
            }
        }
    }

    // 4. Data & Backup Panel (数据与备份)
    private var dataPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsGroup(title: "备份") {
                SettingsRow(
                    title: "导出完整数据备份",
                    subtitle: "包含所有任务、专注记录与设置",
                    keywords: "导出 备份"
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
                    title: "从备份恢复",
                    subtitle: "会先留下现在的数据，再覆盖",
                    keywords: "恢复 备份 快照"
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
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.accent)
                    Text(feedback)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.elevatedBackground(for: colorScheme))
                )
            }

            SettingsGroup(title: "文件") {
                SettingsRow(
                    title: "本机记录",
                    subtitle: "\(taskStore.tasks.count) 个任务 · \(taskStore.focusSessions.count) 次专注。每天自动留一份最近 5 天的快照。",
                    keywords: "数据 本地 离线 任务 专注历史 快照 自动保护 访达 Finder 文件夹 存储"
                ) {
                    Button("打开数据文件夹") {
                        settings.openDataFolderInFinder()
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

/// A source-list row: neutral selection, hover fill, no accent bar. The icon tile
/// keeps its colour, which is the convention Settings panes use.
private struct SettingsSidebarRowButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(backgroundFill(isPressed: configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.16), value: isSelected)
            .onHover { isHovering = $0 }
    }

    private func backgroundFill(isPressed: Bool) -> Color {
        if isSelected {
            return colorScheme == .light
                ? Color.black.opacity(isPressed ? 0.10 : 0.075)
                : Color.white.opacity(isPressed ? 0.17 : 0.13)
        }
        if isPressed {
            return colorScheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.10)
        }
        if isHovering {
            return colorScheme == .light ? Color.black.opacity(0.035) : Color.white.opacity(0.06)
        }
        return Color.clear
    }
}

struct SettingsGroup<Content: View>: View {
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
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous)
                    .fill(AppTheme.cardBackground(for: colorScheme))
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusCard, style: .continuous)
                    .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
            )
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var keywords: String = ""
    var alignment: VerticalAlignment = .center
    @ViewBuilder let content: () -> Content
    @ObservedObject private var search = SettingsSearchModel.shared
    @Environment(\.colorScheme) private var colorScheme

    private var isSearchMatch: Bool {
        search.matchesRow(title: title, subtitle: subtitle, keywords: keywords)
    }

    var body: some View {
        HStack(alignment: alignment, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: isSearchMatch ? .semibold : .medium))
                    .foregroundColor(isSearchMatch ? AppTheme.accent : AppTheme.primaryText(for: colorScheme))
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
        .background(
            isSearchMatch
                ? AppTheme.accent.opacity(colorScheme == .light ? 0.08 : 0.14)
                : Color.clear
        )
    }
}

struct SettingsDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Divider()
            .padding(.leading, 14)
            .opacity(colorScheme == .light ? 0.6 : 0.4)
    }
}

private struct DurationSettingRow: View {
    let title: String
    var subtitle: String? = nil
    var keywords: String = ""
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    let step: Int
    let quickPills: [Int]
    var onCommit: () -> Void = {}
    @ObservedObject private var search = SettingsSearchModel.shared
    @Environment(\.colorScheme) private var colorScheme

    private var isSearchMatch: Bool {
        search.matchesRow(title: title, subtitle: subtitle, keywords: keywords)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: isSearchMatch ? .semibold : .medium))
                    .foregroundColor(isSearchMatch ? AppTheme.accent : AppTheme.primaryText(for: colorScheme))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }
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
                    .accessibilityLabel("\(title)：\(pill) 分钟")
                    .accessibilityAddTraits(minutes == pill ? .isSelected : [])
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
                    .accessibilityLabel("\(title)：\(minutes) 分钟")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            isSearchMatch
                ? AppTheme.accent.opacity(colorScheme == .light ? 0.08 : 0.14)
                : Color.clear
        )
    }
}
