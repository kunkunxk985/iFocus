import SwiftUI
import AppKit

private enum SettingsWindowPanel: String, CaseIterable, Identifiable {
    case general = "常规"
    case appearance = "外观"
    case timer = "计时"
    case notifications = "声音与通知"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintpalette.fill"
        case .timer: return "timer"
        case .notifications: return "bell.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "版本信息与窗口说明"
        case .appearance: return "主题与界面外观"
        case .timer: return "番茄节奏与每日目标"
        case .notifications: return "声音、通知与自动化"
        }
    }
}

struct SettingsWindowView: View {
    @State private var selectedPanel: SettingsWindowPanel = .general
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var timerStore: TimerStore
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
                        case .appearance: appearancePanel
                        case .timer: timerPanel
                        case .notifications: notificationsPanel
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
        }
        .onDisappear {
            settings.sanitizeUsername()
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.accent)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.12))
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
            settingsCard("关于 iFocus", icon: "info.circle.fill") {
                SettingsLine(title: "版本", value: AppVersion.short)
                SettingsLine(title: "构建号", value: AppVersion.build)
                SettingsLine(title: "平台", value: "macOS 13+")
            }

            settingsCard("窗口", icon: "macwindow") {
                SettingsLine(title: "最小尺寸", value: "\(Int(AppWindowMetrics.minimum.width)) × \(Int(AppWindowMetrics.minimum.height))")
                SettingsLine(title: "默认尺寸", value: "\(Int(AppWindowMetrics.defaultSize.width)) × \(Int(AppWindowMetrics.defaultSize.height))")
                Text("关闭主窗口会隐藏到菜单栏，计时继续运行。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    .padding(.top, 2)
            }

            settingsCard("数据", icon: "internaldrive.fill") {
                SettingsLine(title: "存储位置", value: "本机 Application Support")
                Text("任务与专注记录仅保存在本机，不会上传。")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }
        }
    }

    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            settingsCard("预览", icon: "eye.fill") {
                HStack(spacing: 12) {
                    ForEach(AppearanceMode.allCases) { mode in
                        let selected = settings.appearance == mode
                        Button {
                            settings.appearance = mode
                        } label: {
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(previewFill(for: mode))
                                    .frame(height: 56)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(selected ? AppTheme.accent : AppTheme.separator(for: colorScheme), lineWidth: selected ? 2 : 1)
                                    )
                                Text(mode.rawValue)
                                    .font(.caption.weight(selected ? .bold : .medium))
                                    .foregroundColor(selected ? AppTheme.accent : AppTheme.secondaryText(for: colorScheme))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
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
                    if timerStore.mode == .work { timerStore.reset() }
                }
                StepperRow(title: "短休息", value: $settings.shortBreakMinutes, suffix: "分钟", range: 1...30, step: 1) {
                    if timerStore.mode == .shortBreak { timerStore.reset() }
                }
                StepperRow(title: "长休息", value: $settings.longBreakMinutes, suffix: "分钟", range: 5...60, step: 5) {
                    if timerStore.mode == .longBreak { timerStore.reset() }
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

                if settings.soundEnabled {
                    HStack {
                        Text("提示音")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Picker("", selection: $settings.soundName) {
                            ForEach(SettingsStore.availableSounds, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                        .onChange(of: settings.soundName) { newValue in
                            NSSound(named: newValue)?.play()
                        }
                    }
                }
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
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(SoftCardBackground(cornerRadius: 16))
    }
}

// Shared with main window metrics (keep settings text in sync).
enum AppWindowMetrics {
    static let minimum = CGSize(width: 1100, height: 720)
    static let defaultSize = CGSize(width: 1280, height: 820)
}

enum AppVersion {
    /// Keep fallbacks in sync with `Scripts/package_app.sh` (1.5.1 / 51).
    static var short: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.5.1"
    }
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "51"
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
