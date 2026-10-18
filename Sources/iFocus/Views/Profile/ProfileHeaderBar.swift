import SwiftUI

struct ProfileHeaderBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            PageTitle(
                title: "个人资料",
                systemImage: "person.crop.circle"
            )

            Spacer(minLength: 12)

            Button(action: onEdit) {
                HStack(spacing: 5) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                    Text("编辑资料")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(AppTheme.cardBackground(for: colorScheme))
                        .overlay(
                            Capsule()
                                .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 0.75)
                        )
                        .multiLayerShadow(elevation: .row, colorScheme: colorScheme)
                )
            }
            .buttonStyle(SpringScaleButtonStyle(pressedScale: 0.94))
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
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.20))
                    .frame(width: 100, height: 100)
                    .blur(radius: 10)

                UnifiedAvatarView(
                    path: avatarPath,
                    colorIndex: avatarColorIndex,
                    username: username,
                    size: 88
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(colorScheme == .light ? 0.6 : 0.15), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.3), radius: 8, x: 0, y: 4)
            }

            Text(username)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.primaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }
}
