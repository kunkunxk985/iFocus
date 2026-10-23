import SwiftUI

/// A single place to check permissions, data health and recovery actions.
/// Errors remain visible here instead of living only in transient alerts.
struct SettingsStatusPanel: View {
    let onOpenData: () -> Void

    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var timerStore: TimerStore
    @EnvironmentObject private var taskStore: TaskStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var loginStatus: LaunchAtLogin.Status = .disabled

    private var backupFailed: Bool {
        guard let feedback = settings.backupFeedback else { return false }
        return feedback.contains("失败") || feedback.contains("未完成")
    }

    private var issueCount: Int {
        var count = 0
        if taskStore.dataLoadErrorMessage != nil { count += 1 }
        if timerStore.notificationStatus == "已拒绝" { count += 1 }
        if LaunchAtLogin.needsAttention(userWantsEnabled: settings.launchAtLogin) { count += 1 }
        if backupFailed { count += 1 }
        return count
    }

    private var notificationColor: Color {
        switch timerStore.notificationStatus {
        case "已授权": return AppTheme.success
        case "已拒绝": return AppTheme.danger
        default: return AppTheme.secondaryText(for: colorScheme)
        }
    }

    private var loginLabel: String {
        guard settings.launchAtLogin else { return "未开启" }
        switch loginStatus {
        case .enabled: return "已开启"
        case .requiresApproval: return "等待批准"
        case .notFound: return "未找到应用"
        case .unsupported: return "不支持"
        case .disabled: return "未开启"
        }
    }

    private var loginColor: Color {
        guard settings.launchAtLogin else {
            return AppTheme.secondaryText(for: colorScheme)
        }
        switch loginStatus {
        case .enabled: return AppTheme.success
        case .requiresApproval, .notFound: return AppTheme.warning
        default: return AppTheme.secondaryText(for: colorScheme)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            healthSummary
            permissionsGroup
            dataHealthGroup
        }
        .onAppear { refresh() }
    }

    private var healthSummary: some View {
        let healthy = issueCount == 0
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((healthy ? AppTheme.success : AppTheme.warning).opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: healthy ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(healthy ? AppTheme.success : AppTheme.warning)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(healthy ? "运行正常" : "有 \(issueCount) 项需要处理")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                Text(healthy
                     ? "权限与本地数据没有发现需要处理的问题。"
                     : "检查下方权限或数据状态，按提示处理即可。")
                    .font(TypeScale.meta)
                    .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            }

            Spacer(minLength: 8)

            Button {
                refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("重新检查")
            .accessibilityLabel("重新检查系统状态")
        }
        .padding(14)
        .background(
            AppTheme.squircle(radius: AppTheme.cornerRadiusCard)
                .fill(AppTheme.cardBackground(for: colorScheme))
        )
        .overlay(
            AppTheme.squircle(radius: AppTheme.cornerRadiusCard)
                .strokeBorder(
                    (healthy ? AppTheme.separatorLow(for: colorScheme) : AppTheme.warning.opacity(0.25)),
                    lineWidth: 1
                )
        )
    }

    private var permissionsGroup: some View {
        SettingsGroup(title: "权限与系统") {
            SettingsRow(
                title: "系统通知",
                subtitle: "专注结束时的横幅与提示音",
                keywords: "权限 通知 检查"
            ) {
                HStack(spacing: 8) {
                    Text(timerStore.notificationStatus)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(notificationColor)

                    if timerStore.notificationStatus == "已授权" {
                        Button("发送测试") {
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

            if let feedback = timerStore.notificationFeedback {
                statusCaption(feedback, isError: feedback.contains("失败") || feedback.contains("请先"))
                SettingsDivider()
            }

            SettingsRow(
                title: "登录时自动打开",
                subtitle: "由「系统设置 → 通用 → 登录项」管理",
                keywords: "登录项 权限 开机 启动"
            ) {
                HStack(spacing: 8) {
                    Text(loginLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(loginColor)
                    Button("打开设置…") {
                        SystemSettingsLinks.openLoginItems()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            SettingsDivider()

            if settings.launchAtLogin, loginStatus == .notFound {
                statusCaption("请先把 iFocus 放到「应用程序」文件夹，再重新打开登录项设置。", isError: true)
                SettingsDivider()
            }

            SettingsRow(
                title: "系统专注模式",
                subtitle: "由 macOS 管理，iFocus 无法直接开关",
                keywords: "系统专注 权限 勿扰"
            ) {
                Button("打开设置…") {
                    SystemSettingsLinks.openFocus()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var dataHealthGroup: some View {
        SettingsGroup(title: "数据健康") {
            SettingsRow(
                title: "本地数据文件",
                subtitle: "\(taskStore.tasks.count) 个任务 · \(taskStore.focusSessions.count) 次专注记录",
                keywords: "状态 健康 数据 文件 检查"
            ) {
                HStack(spacing: 8) {
                    Text(taskStore.dataLoadErrorMessage == nil ? "正常" : "需要注意")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(taskStore.dataLoadErrorMessage == nil ? AppTheme.success : AppTheme.danger)
                    Button("打开文件夹") {
                        settings.openDataFolderInFinder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if let error = taskStore.dataLoadErrorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.danger)
                    Text(error)
                        .font(TypeScale.meta)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button("重新加载") {
                        _ = taskStore.reloadFromDisk()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }

            SettingsDivider()

            SettingsRow(
                title: "备份与恢复",
                subtitle: settings.backupFeedback ?? "导出或恢复都在「数据与备份」中完成",
                keywords: "备份 恢复 状态 健康"
            ) {
                Button("前往") {
                    onOpenData()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func statusCaption(_ text: String, isError: Bool) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(isError ? AppTheme.warning : AppTheme.accent)
            Text(text)
                .font(TypeScale.meta)
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private func refresh() {
        timerStore.updateNotificationStatus()
        settings.refreshLaunchAtLoginFromSystem()
        loginStatus = LaunchAtLogin.status
    }
}
