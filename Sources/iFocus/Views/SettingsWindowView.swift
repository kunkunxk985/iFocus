import SwiftUI
import AppKit

private enum SettingsWindowPanel: String, CaseIterable, Identifiable {
    case general = "常规"
    case data = "数据"
    case appearance = "外观"
    case analytics = "统计"
    case timer = "计时"
    case notifications = "声音与通知"
    case shortcuts = "快捷键"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .data: return "externaldrive.fill"
        case .appearance: return "paintpalette.fill"
        case .analytics: return "chart.bar.fill"
        case .timer: return "timer"
        case .notifications: return "bell.fill"
        case .shortcuts: return "keyboard"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "版本信息与窗口说明"
        case .data: return "本地备份与恢复"
        case .appearance: return "主题与界面外观"
        case .analytics: return "数据页展示哪些卡片"
        case .timer: return "番茄节奏与每日目标"
        case .notifications: return "声音、通知与自动化"
        case .shortcuts: return "键盘与菜单栏操作"
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

            // Content
            VStack(alignment: .leading, spacing: 0) {
                panelHeader
                    .padding(.horizontal, 32)
                    .padding(.top, AppTheme.detailTopInset)
                    .padding(.bottom, 20)

                ScrollView {
                    Group {
                        switch selectedPanel {
                        case .general: generalPanel
                        case .data: dataPanel
                        case .appearance: appearancePanel
                        case .analytics: analyticsPanel
                        case .timer: timerPanel
                        case .notifications: notificationsPanel
                        case .shortcuts: shortcutsPanel
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
                .softScroll()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.contentBackground(for: colorScheme).ignoresSafeArea())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
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
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
            AppTheme.sidebarTint(for: colorScheme)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 48)

                Text("设置")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                VStack(spacing: 4) {
                    ForEach(SettingsWindowPanel.allCases) { panel in
                        settingsSidebarRow(panel)
                    }
                }
                .padding(.horizontal, 12)

                Spacer()

                Text("iFocus \(AppVersion.short)")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.7))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppTheme.separator(for: colorScheme))
                .frame(width: 1)
                .opacity(0.6)
        }
    }

    private func settingsSidebarRow(_ panel: SettingsWindowPanel) -> some View {
        let isSelected = selectedPanel == panel
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedPanel = panel
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: panel.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.secondaryText(for: colorScheme))
                    .frame(width: 20)
                Text(panel.rawValue)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected
                                     ? AppTheme.primaryText(for: colorScheme)
                                     : AppTheme.primaryText(for: colorScheme).opacity(0.78))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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
                        .padding(.leading, 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var panelHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: selectedPanel.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.accent)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.elevatedBackground(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(selectedPanel.rawValue)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                Text(selectedPanel.subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
            Spacer()
        }
    }

    // MARK: - Panels

    private var generalPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsCard("常用", icon: "star.fill") {
                SettingsLine(title: "版本", value: "\(AppVersion.short) (\(AppVersion.build))")
                Text("关闭主窗口会隐藏到菜单栏，计时继续运行。数据仅保存在本机。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                HStack(spacing: 10) {
                    Button("显示数据文件夹") {
                        settings.openDataFolderInFinder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button("重新显示引导") {
                        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.top, 4)
            }
            
            settingsCard("登录时启动", icon: "power") {
                Toggle(isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        settings.applyLaunchAtLoginPreference()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("登录 Mac 时打开 iFocus")
                            .font(.subheadline.weight(.medium))
                        Text("默认关闭。仅在你手动打开时才会注册登录项，不会在安装或更新后自动开启。")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    }
                }
                .toggleStyle(.switch)
                
                Text("建议把 App 放在「应用程序」文件夹。若系统要求批准，请到「登录项」中允许。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                
                HStack(spacing: 10) {
                    Button("打开系统登录项…") {
                        LaunchAtLogin.openLoginItemsSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    if let feedback = settings.launchAtLoginFeedback {
                        Text(feedback)
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                            .lineLimit(2)
                    }
                }
            }

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 14) {
                    settingsCard("窗口", icon: "macwindow") {
                        SettingsLine(title: "最小尺寸", value: "\(Int(AppWindowMetrics.minimum.width)) × \(Int(AppWindowMetrics.minimum.height))")
                        SettingsLine(title: "默认尺寸", value: "\(Int(AppWindowMetrics.defaultSize.width)) × \(Int(AppWindowMetrics.defaultSize.height))")
                        SettingsLine(title: "布局", value: "随窗口连续缩放（非固定紧凑）")
                        SettingsLine(title: "平台", value: "macOS 13+")
                    }
                    settingsCard("数据路径", icon: "internaldrive.fill") {
                        SettingsLine(title: "位置", value: "Application Support/iFocus")
                        Text("任务、专注记录与头像都在这里。不会上传。")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    }
                }
                .padding(.top, 10)
            } label: {
                Label("高级信息", systemImage: "chevron.down.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
        }
    }
    
    private var dataPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsCard("说明", icon: "info.circle") {
                Text("数据只在本机。导出为普通文件夹，可拷到 U 盘、云盘或另一台 Mac。导入会先自动备份当前数据，再覆盖。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            settingsCard("备份", icon: "square.and.arrow.up") {
                Text("包含任务、专注记录、应用状态、偏好设置、头像与未完成计时。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                Button {
                    switch DataBackupService.exportBackup(
                        taskStore: taskStore,
                        settings: settings,
                        appVersion: AppVersion.short
                    ) {
                    case .success(let url):
                        settings.backupFeedback = "已导出到 \(url.lastPathComponent)"
                    case .failure(let error):
                        if error is DataBackupService.CancelError {
                            settings.backupFeedback = nil
                        } else {
                            settings.backupFeedback = error.localizedDescription
                        }
                    }
                } label: {
                    Text("导出备份…")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }

            settingsCard("恢复", icon: "square.and.arrow.down") {
                Text("选择此前导出的备份文件夹。导入前会自动把当前数据拷到数据目录的 pre-import 子文件夹。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    switch DataBackupService.selectBackup() {
                    case .success(let preview):
                        settings.backupFeedback = nil
                        pendingRestorePreview = preview
                    case .failure(let error):
                        if error is DataBackupService.CancelError {
                            settings.backupFeedback = nil
                        } else {
                            settings.backupFeedback = error.localizedDescription
                        }
                    }
                } label: {
                    Text("从备份恢复…")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            settingsCard("本机位置", icon: "folder") {
                Button("在 Finder 中显示数据文件夹") {
                    settings.openDataFolderInFinder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let feedback = settings.backupFeedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func restorePreviewMessage(_ preview: DataBackupService.RestorePreview) -> String {
        let summary = preview.summary
        var lines = [
            "备份：\(preview.package.directory.lastPathComponent)",
            "任务：\(summary.taskCount.map(String.init) ?? "未包含")",
            "专注记录：\(summary.sessionCount.map(String.init) ?? "未包含")"
        ]
        if let manifest = preview.package.manifest {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            lines.append("导出版本：\(manifest.appVersion) · \(formatter.string(from: manifest.exportedAt))")
        }
        var extras: [String] = []
        if summary.hasSettings { extras.append("偏好设置") }
        if summary.hasAvatar { extras.append("头像") }
        if summary.hasTimerSession { extras.append("未完成计时") }
        if !extras.isEmpty {
            lines.append("附加内容：\(extras.joined(separator: "、"))")
        }
        if timerStore.isSessionInProgress {
            lines.append("当前计时会停止；恢复失败时会保留为可恢复会话。")
        }
        lines.append("当前数据会先保存到 pre-import 文件夹，恢复失败将自动回滚。")
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
            settings.backupFeedback = "已恢复（\(tasks) · \(sessions)）；原数据：\(outcome.safetySnapshotDirectory.lastPathComponent)"
            timerStore.updateStatsFromHistory(taskStore: taskStore)
        case .failure(let error):
            settings.backupFeedback = "恢复未完成：\(error.localizedDescription)；当前数据已保留。"
        }
    }

    private var shortcutsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsCard("开始 / 暂停（可自定义）", icon: "keyboard") {
                Picker("组合键", selection: $settings.toggleShortcut) {
                    ForEach(ToggleShortcutPreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
                Text("在 App 前台时生效（菜单「专注」）。专注页仍可用单独空格。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
            settingsCard("固定快捷键", icon: "timer") {
                ShortcutRow(keys: "空格", action: "开始 / 暂停（仅专注页）")
                ShortcutRow(keys: settings.toggleShortcut.label, action: "开始 / 暂停（菜单，当前选择）")
                ShortcutRow(keys: "⌘R", action: "重置当前计时")
                ShortcutRow(keys: "⌘→", action: "跳过当前段")
            }
            settingsCard("前往", icon: "sidebar.left") {
                ShortcutRow(keys: "⌘1", action: "专注钟")
                ShortcutRow(keys: "⌘2", action: "数据统计")
                ShortcutRow(keys: "⌘3–6", action: "今天 / 明天 / 本周 / 收集箱")
                ShortcutRow(keys: "⌘7", action: "个人资料")
                ShortcutRow(keys: "⌘,", action: "设置")
            }
            settingsCard("菜单栏", icon: "menubar.rectangle") {
                Text("显示样式请到「外观」面板调整。菜单内可快速选今日任务、自由专注、开始/暂停。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
            
            settingsCard("URL 自动化（Shortcuts / Alfred）", icon: "link") {
                Text("安装应用版后可用 `ifocus://` 控制计时与导航。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                
                VStack(alignment: .leading, spacing: 8) {
                    deepLinkRow("ifocus://start", "开始计时")
                    deepLinkRow("ifocus://toggle", "开始 / 暂停")
                    deepLinkRow("ifocus://pause", "暂停")
                    deepLinkRow("ifocus://skip", "跳过当前段")
                    deepLinkRow("ifocus://reset", "重置")
                    deepLinkRow("ifocus://freefocus", "自由专注并开始")
                    deepLinkRow("ifocus://today", "打开今天清单")
                    deepLinkRow("ifocus://open?screen=analytics", "打开数据统计")
                }
                
                Text("也可在终端试：open 'ifocus://toggle'")
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.85))
            }
        }
    }
    
    private func deepLinkRow(_ scheme: String, _ action: String) -> some View {
        HStack(spacing: 10) {
            Text(scheme)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTheme.elevatedBackground(for: colorScheme))
                )
                .textSelection(.enabled)
            Text(action)
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            Spacer(minLength: 4)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(scheme, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
            .buttonStyle(.plain)
            .help("复制")
        }
    }

    private var analyticsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsCard("展示说明", icon: "info.circle") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("选择「数据统计」页展示哪些卡片。默认安静布局；也可在统计页右上角「自定义」即时调整。")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("不做拖拽排序：卡片顺序固定，读起来更省心。")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.85))
                }
            }

            settingsCard("卡片开关", icon: "square.grid.2x2") {
                AnalyticsCardVisibilityEditor(settings: settings, style: .full)
            }
        }
    }
    
    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsCard("产品气质", icon: "leaf") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("安静工具")
                        .font(.subheadline.weight(.semibold))
                    Text("默认少动效、少打扰。完成时用轻提示，不抢注意力。")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }
            }
            
            settingsCard("主题", icon: "paintpalette.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("界面外观")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    Picker("", selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }
            
            settingsCard("动效与启动", icon: "sparkles") {
                Toggle(isOn: $settings.decorativeMotionEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("装饰动效")
                            .font(.subheadline.weight(.medium))
                        Text("圆环呼吸、播放邀请光环、完成轻弹。默认关闭。")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    }
                }
                .toggleStyle(.switch)
                
                Toggle(isOn: $settings.smartLaunchLanding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("智能启动页")
                            .font(.subheadline.weight(.medium))
                        Text("今天有待办时打开「今天」，否则打开专注钟。")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    }
                }
                .toggleStyle(.switch)
            }
            
            settingsCard("强调色", icon: "paintbrush.pointed.fill") {
                HStack(spacing: 12) {
                    ForEach(AccentPreset.allCases) { preset in
                        let selected = settings.accentPreset == preset
                        Button {
                            settings.accentPreset = preset
                        } label: {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.9), lineWidth: selected ? 2 : 0)
                                    )
                                    .shadow(color: preset.color.opacity(0.35), radius: selected ? 6 : 0)
                                Text(preset.label)
                                    .font(.caption2.weight(selected ? .bold : .medium))
                                    .foregroundColor(selected ? preset.color : AppTheme.secondaryText(for: colorScheme))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selected ? preset.color.opacity(0.10) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(selected ? preset.color.opacity(0.45) : AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(SoftScaleButtonStyle())
                    }
                }
            }
            
            settingsCard("菜单栏显示", icon: "menubar.rectangle") {
                Picker("", selection: $settings.menuBarDisplayStyle) {
                    ForEach(MenuBarDisplayStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
                Text("左键开始/暂停，右键打开菜单。仅图标最省空间；进度适合盯每日目标。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
            
            settingsCard("显示密度", icon: "rectangle.compress.vertical") {
                Picker("", selection: $settings.uiDensity) {
                    ForEach(UIDensity.allCases) { d in
                        Text(d.label).tag(d)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                Text("紧凑模式缩小间距与标题，小窗可看更多内容。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }

            settingsCard("界面预览", icon: "eye.fill") {
                AppearanceLivePreview(
                    appearance: settings.appearance,
                    accent: settings.accentPreset.color,
                    sidebarCollapsed: false
                )
                .frame(height: 132)
                
                Text("主题与强调色会立即反映到主界面与菜单栏着色。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .padding(.top, 4)
            }
        }
    }

    private func previewFill(for mode: AppearanceMode) -> LinearGradient {
        switch mode {
        case .light:
            return LinearGradient(colors: [Color(hex: "#F4F4F6"), Color.white], startPoint: .top, endPoint: .bottom)
        case .dark:
            return LinearGradient(colors: [Color(hex: "#1A1A1E"), Color(hex: "#2A2A30")], startPoint: .top, endPoint: .bottom)
        case .system:
            return LinearGradient(colors: [Color(hex: "#F4F4F6"), Color(hex: "#2A2A30")], startPoint: .leading, endPoint: .trailing)
        }
    }

    private var timerPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsCard("番茄钟节奏", icon: "timer") {
                StepperRow(title: "专注时长", value: $settings.workMinutes, suffix: "分钟", range: 1...90, step: 5) {
                    // Never reset a running/paused segment — that discarded work without logging.
                    if timerStore.mode == .work { timerStore.syncDurationFromSettingsIfIdle() }
                }
                StepperRow(title: "短休息", value: $settings.shortBreakMinutes, suffix: "分钟", range: 1...30, step: 1) {
                    if timerStore.mode == .shortBreak { timerStore.syncDurationFromSettingsIfIdle() }
                }
                StepperRow(title: "长休息", value: $settings.longBreakMinutes, suffix: "分钟", range: 5...60, step: 5) {
                    if timerStore.mode == .longBreak { timerStore.syncDurationFromSettingsIfIdle() }
                }
            }
            
            settingsCard("专注提示", icon: "moon.fill") {
                Toggle(isOn: $settings.showFocusModeHintOnStart) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("开始专注前提示系统专注模式")
                            .font(.subheadline.weight(.medium))
                        Text("无法代替系统一键开启勿扰，但会提醒你减少打扰。")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    }
                }
                .toggleStyle(.switch)
                
                Toggle(isOn: $settings.pauseReminderEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("暂停过久提醒")
                            .font(.subheadline.weight(.medium))
                        Text("会话暂停超过设定时间后，菜单栏与界面会轻提示。")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    }
                }
                .toggleStyle(.switch)
                
                if settings.pauseReminderEnabled {
                    StepperRow(
                        title: "提醒阈值",
                        value: $settings.pauseReminderMinutes,
                        suffix: "分钟",
                        range: 1...60,
                        step: 1
                    )
                }
            }

            settingsCard("每日目标", icon: "target") {
                StepperRow(title: "目标番茄数", value: $settings.dailyGoal, suffix: "个", range: 1...20, step: 1)
                Text("完成 \(settings.dailyGoal) 个番茄即达成今日目标。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
        }
    }

    private var notificationsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsCard("自动化", icon: "bolt.fill") {
                Toggle(isOn: $settings.autoStartBreaks) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自动进入下一段")
                            .font(.subheadline.weight(.medium))
                        Text("休息或专注结束后自动开始下一段计时")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    }
                }
                .toggleStyle(.switch)
            }

            settingsCard("声音与通知", icon: "speaker.wave.2.fill") {
                Toggle(isOn: $settings.soundEnabled) {
                    Text("启用提示音")
                        .font(.subheadline.weight(.medium))
                }
                .toggleStyle(.switch)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("通知权限")
                            .font(.subheadline.weight(.medium))
                        Text(timerStore.notificationStatus)
                            .font(.caption)
                            .foregroundColor(timerStore.notificationStatus == "已拒绝" ? .red : AppTheme.secondaryText(for: colorScheme))
                    }
                    Spacer()
                    Button(timerStore.notificationActionTitle) {
                        timerStore.handleNotificationPermissionAction()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if timerStore.notificationStatus == "已拒绝" {
                    Text("macOS 拒绝后不会再次弹出授权框，请在系统设置中为 iFocus 开启通知。")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }

                if timerStore.notificationStatus == "已授权" {
                    HStack(spacing: 10) {
                        Button("发送测试通知") {
                            timerStore.notificationFeedback = nil
                            timerStore.sendTestNotification()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if let feedback = timerStore.notificationFeedback {
                            Text(feedback)
                                .font(.caption)
                                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                                .lineLimit(2)
                        }
                    }
                }

                if settings.soundEnabled {
                    HStack {
                        Text("提示音")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Picker("", selection: $settings.soundName) {
                            ForEach(SettingsStore.availableSounds, id: \.self) { name in
                                Text(name as String).tag(name)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                        .onChange(of: settings.soundName) { newValue in
                            NSSound(named: newValue)?.play()
                        }
                    }
                }
                
                Toggle(isOn: $settings.dockBounceOnComplete) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("完成时 Dock 弹跳")
                            .font(.subheadline.weight(.medium))
                        Text("番茄结束时 Dock 图标轻跳一次，可与提示音同时关闭。")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    }
                }
                .toggleStyle(.switch)
            }
        }
    }

    private func settingsCard<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(SoftCardBackground(cornerRadius: AppTheme.cornerRadiusCard))
    }
}

// Shared with main window metrics (keep settings text in sync).
enum AppWindowMetrics {
    /// Keep in sync with `WindowLayoutMetrics.minimum` / `defaultSize`.
    static let minimum = WindowLayoutMetrics.minimum
    static let defaultSize = WindowLayoutMetrics.defaultSize
}

enum AppVersion {
    /// Prefer Info.plist (written by `package_app.sh` from root `VERSION` file).
    /// Unpackaged `swift run` falls back to reading `VERSION` next to the package, else "dev".
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
        // Walk up from executable / cwd to find repo VERSION (dev only).
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

// MARK: - Live appearance preview chip

private struct AppearanceLivePreview: View {
    let appearance: AppearanceMode
    let accent: Color
    let sidebarCollapsed: Bool
    
    private var scheme: ColorScheme {
        switch appearance {
        case .light: return .light
        case .dark: return .dark
        case .system: return .light
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Mini sidebar
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(accent.opacity(0.85))
                    .frame(width: sidebarCollapsed ? 14 : 36, height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppTheme.secondaryText(for: scheme).opacity(0.25))
                    .frame(width: sidebarCollapsed ? 14 : 28, height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppTheme.secondaryText(for: scheme).opacity(0.18))
                    .frame(width: sidebarCollapsed ? 14 : 32, height: 6)
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(width: sidebarCollapsed ? 36 : 72)
            .background(AppTheme.sidebarBackground(for: scheme))
            
            // Mini stage
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .stroke(accent.opacity(0.2), lineWidth: 6)
                        .frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: 0.62)
                        .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90))
                    Text("18:24")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.primaryText(for: scheme))
                }
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.cardBackground(for: scheme))
                    .frame(height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppTheme.separator(for: scheme), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.contentBackground(for: scheme))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.separator(for: colorSchemeForPreview), lineWidth: 1)
        )
    }
    
    private var colorSchemeForPreview: ColorScheme { scheme }
}

private struct ShortcutRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let keys: String
    let action: String
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(keys)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTheme.elevatedBackground(for: colorScheme))
                )
            Spacer(minLength: 12)
            Text(action)
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct SettingsLine: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct StepperRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    @Binding var value: Int
    let suffix: String
    let range: ClosedRange<Int>
    let step: Int
    var onChange: () -> Void = {}

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            Spacer()
            Stepper("\(value) \(suffix)", value: $value, in: range, step: step)
                .font(.subheadline.weight(.semibold))
                .onChange(of: value) { _ in onChange() }
        }
    }
}
