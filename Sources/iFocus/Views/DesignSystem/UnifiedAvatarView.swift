import SwiftUI
import AppKit

struct UnifiedAvatarView: View {
    static let palette: [Color] = AccentPreset.allCases.map(\.color)

    let path: String?
    let colorIndex: Int
    let username: String
    let size: CGFloat

    private var initialCharacter: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "小" }
        return String(first).uppercased()
    }
    
    var body: some View {
        ZStack {
            if let path = path, let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else if colorIndex > 0 {
                let tint = Self.palette[colorIndex % Self.palette.count]
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(initialCharacter)
                    .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            } else {
                // Default tomato avatar using the macOS high-res App Icon!
                if let appIcon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.05) // Subtle padding to ensure it fits beautifully in the circle
                } else {
                    // Fallback circle if app icon is somehow unavailable
                    Circle()
                        .fill(Color.red)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(.white.opacity(0.25), lineWidth: 1.2)
        )
    }
}
