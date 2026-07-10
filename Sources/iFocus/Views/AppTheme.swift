import SwiftUI
import AppKit

// MARK: - Color hex convenience
extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6,
              let int = UInt64(trimmed, radix: 16) else {
            self = .clear
            return
        }
        let r = Double((int & 0xFF0000) >> 16) / 255.0
        let g = Double((int & 0x00FF00) >> 8) / 255.0
        let b = Double(int & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Theme
enum AppTheme {
    /// Warm coral — focus product accent
    static var accent: Color { Color(hex: "#E85A3C") }
    
    static let cornerRadiusCard: CGFloat = 16
    static let cornerRadiusControl: CGFloat = 12
    static let cornerRadiusRow: CGFloat = 14
    
    // Backgrounds
    static func appBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#F3F3F5") : Color(hex: "#141416")
    }
    static func sidebarBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#EAEAEF") : Color(hex: "#1C1C1F")
    }
    static func sidebarTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.white.opacity(0.10) : Color.black.opacity(0.14)
    }
    static func sidebarRowBackground(for colorScheme: ColorScheme) -> Color {
        Color.white.opacity(0.001)
    }
    static func glassControlBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.white.opacity(0.65) : Color.white.opacity(0.08)
    }
    static func menuBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.white.opacity(0.94) : Color(hex: "#252528").opacity(0.97)
    }
    static func contentBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#F3F3F5") : Color(hex: "#141416")
    }
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.white : Color(hex: "#222226")
    }
    static func elevatedBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#F7F7F9") : Color(hex: "#2C2C31")
    }
    
    // Text
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "1A1A1C") : Color.white.opacity(0.94)
    }
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "6B6B70") : Color(hex: "9A9A9F")
    }
    
    // Separators / overlays
    static func separator(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.07) : Color.white.opacity(0.10)
    }
    static func separatorLow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.04) : Color.white.opacity(0.06)
    }
    static func overlayThin(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.05) : Color.black.opacity(0.15)
    }
    static func overlayLow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.03) : Color.black.opacity(0.08)
    }
    
    // Shared card chrome
    static func cardFill(for colorScheme: ColorScheme) -> some View {
        RoundedRectangle(cornerRadius: cornerRadiusCard, style: .continuous)
            .fill(cardBackground(for: colorScheme))
    }
    
    static func cardStroke(for colorScheme: ColorScheme) -> some View {
        RoundedRectangle(cornerRadius: cornerRadiusCard, style: .continuous)
            .stroke(separatorLow(for: colorScheme), lineWidth: 1)
    }
    
    static func softShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.05) : Color.black.opacity(0.28)
    }
    
    static var windowBackgroundColor: NSColor {
        NSColor(name: nil) { appearance in
            let isLight = appearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
            return isLight ? NSColor(white: 0.953, alpha: 1.0) : NSColor(white: 0.08, alpha: 1.0)
        }
    }
}

// MARK: - Layout chrome
extension AppTheme {
    /// Clears the transparent titlebar / traffic-light band so detail content
    /// doesn’t sit flush against the top of the window.
    /// Tuned to sit under a Gemini / Electron `hiddenInset` traffic-light row.
    static let detailTopInset: CGFloat = 68
    
    /// Traffic-light inset matching Gemini / Electron `titleBarStyle: hiddenInset`
    /// (comfortably clear of the rounded window corner).
    static let trafficLightLeading: CGFloat = 20
    static let trafficLightTop: CGFloat = 18
    static let trafficLightSpacing: CGFloat = 8
}

// MARK: - Reusable chrome
struct SoftCardBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = AppTheme.cornerRadiusCard
    var elevated: Bool = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppTheme.cardBackground(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
            )
            .shadow(
                color: elevated ? AppTheme.softShadow(for: colorScheme) : .clear,
                radius: elevated ? 12 : 0,
                y: elevated ? 4 : 0
            )
    }
}

struct PageTitle: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var tint: Color = AppTheme.accent
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint.opacity(0.12))
                    )
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                }
            }
            Spacer(minLength: 0)
        }
    }
}
