import SwiftUI

struct ProfileHeaderBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let onShare: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PageTitle(
                title: "个人资料",
                subtitle: "本地账号 · 专注足迹",
                systemImage: "person.crop.circle"
            )

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button(action: onShare) {
                    Label("发送日报", systemImage: "paperplane")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("通过系统邮件客户端分享今日专注日报")

                Button(action: onEdit) {
                    Label("编辑", systemImage: "pencil")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, 8)
        }
    }
}

struct ProfileIdentityBlock: View {
    @Environment(\.colorScheme) private var colorScheme
    let avatarPath: String?
    let avatarColorIndex: Int
    let username: String

    var body: some View {
        VStack(spacing: 12) {
            UnifiedAvatarView(
                path: avatarPath,
                colorIndex: avatarColorIndex,
                username: username,
                size: 88
            )

            Text(username)
                .font(.title2.weight(.bold))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }
}
