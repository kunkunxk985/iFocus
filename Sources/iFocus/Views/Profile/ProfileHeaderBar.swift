import SwiftUI

struct ProfileHeaderBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let onEdit: () -> Void

    var body: some View {
        PageTitle(
            title: "个人资料",
            systemImage: "person.crop.circle"
        )
        .overlay(alignment: .trailing) {
            Button("编辑资料", action: onEdit)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.secondaryText(for: colorScheme))
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
            .overlay(
                Circle()
                    .strokeBorder(AppTheme.separator(for: colorScheme), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(colorScheme == .light ? 0.06 : 0.22), radius: 8, x: 0, y: 3)

            Text(username)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }
}
