import SwiftUI

struct ProfileHeaderBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let onShare: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("个人资料")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
            
            Spacer(minLength: 16)
            
            Button(action: onShare) {
                Label("发送日报", systemImage: "paperplane")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .help("通过系统邮件客户端分享今日专注日报")
            
            Button(action: onEdit) {
                Label("编辑", systemImage: "pencil")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(.bottom, 4)
    }
}

struct ProfileIdentityBlock: View {
    @Environment(\.colorScheme) private var colorScheme
    let avatarPath: String?
    let avatarColorIndex: Int
    let username: String
    
    var body: some View {
        VStack(spacing: 14) {
            UnifiedAvatarView(
                path: avatarPath,
                colorIndex: avatarColorIndex,
                username: username,
                size: 104
            )
            
            Text(username)
                .font(.title.bold())
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}
