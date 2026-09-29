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

// MARK: - Accent + menu bar chrome preferences

enum AccentPreset: String, CaseIterable, Identifiable {
    case tomato
    case blue
    case green
    case purple
    case sunset
    case teal
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .tomato: return "番茄红"
        case .blue: return "静谧蓝"
        case .green: return "专注绿"
        case .purple: return "灵感紫"
        case .sunset: return "落日橙"
        case .teal: return "极光青"
        }
    }
    
    var hex: String {
        switch self {
        case .tomato: return "#E85A3C"
        case .blue: return "#3B82F6"
        case .green: return "#10B981"
        case .purple: return "#8B5CF6"
        case .sunset: return "#F97316"
        case .teal: return "#14B8A6"
        }
    }
    
    var color: Color { Color(hex: hex) }
    
    var nsColor: NSColor {
        Color.nsColor(hex: hex)
    }
}

enum MenuBarDisplayStyle: String, CaseIterable, Identifiable {
    case iconTime
    case iconProgress
    case iconOnly
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .iconOnly: return "仅图标"
        case .iconTime: return "图标 + 时间"
        case .iconProgress: return "图标 + 进度"
        }
    }
}

enum UIDensity: String, CaseIterable, Identifiable {
    case comfortable
    case compact
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .comfortable: return "舒适"
        case .compact: return "紧凑"
        }
    }
    
    /// Multiplier for paddings / fonts that opt in.
    var scale: CGFloat {
        switch self {
        case .comfortable: return 1.0
        case .compact: return 0.88
        }
    }
    
    var sectionSpacing: CGFloat {
        switch self {
        case .comfortable: return 16
        case .compact: return 10
        }
    }
    
    var cardPadding: CGFloat {
        switch self {
        case .comfortable: return 16
        case .compact: return 12
        }
    }
    
    var rowVerticalPadding: CGFloat {
        switch self {
        case .comfortable: return 12
        case .compact: return 8
        }
    }
    
    var titleFontSize: CGFloat {
        switch self {
        case .comfortable: return 28
        case .compact: return 24
        }
    }
}

// MARK: - Theme
enum AppTheme {
    private static let accentDefaultsKey = "accentPreset"
    
    /// Live accent — reads preference so existing `AppTheme.accent` call sites pick it up.
    static var accent: Color {
        let raw = UserDefaults.standard.string(forKey: accentDefaultsKey) ?? AccentPreset.tomato.rawValue
        return (AccentPreset(rawValue: raw) ?? .tomato).color
    }
    
    static var accentNSColor: NSColor {
        let raw = UserDefaults.standard.string(forKey: accentDefaultsKey) ?? AccentPreset.tomato.rawValue
        return (AccentPreset(rawValue: raw) ?? .tomato).nsColor
    }
    
    // Quiet-tool spacing / radius tokens (prefer these over one-off values).
    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let spaceXL: CGFloat = 24
    
    // Standardized Continuous Squircle Corner Radii
    static let radiusXS: CGFloat = 6
    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 12
    static let radiusCard: CGFloat = 16
    static let radiusXL: CGFloat = 20
    static let radiusPill: CGFloat = 999

    /// Shared card radius — analytics / settings / profile / list stats all use this.
    static let cornerRadiusCard: CGFloat = radiusCard
    static let cornerRadiusControl: CGFloat = 10
    static let cornerRadiusRow: CGFloat = radiusM

    /// Concentric nested corner radius helper: R_inner = max(R_outer - padding, radiusXS)
    static func nestedRadius(outer: CGFloat, padding: CGFloat) -> CGFloat {
        max(outer - padding, radiusXS)
    }
    
    /// Continuous squircle RoundedRectangle shape helper
    static func squircle(radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    // MARK: - Spring Physics Animations
    static let springInteractive = Animation.spring(response: 0.22, dampingFraction: 0.72)
    static let springSnappy = Animation.spring(response: 0.18, dampingFraction: 0.78)
    static let springGentle = Animation.spring(response: 0.32, dampingFraction: 0.82)

    // Backgrounds — warm ivory/creamy light canvas & rich graphite dark canvas
    static func appBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#F6F7F9") : Color(hex: "#131316")
    }
    static func sidebarBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#ECEEF1") : Color(hex: "#161619")
    }
    static func sidebarTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.white.opacity(0.12) : Color.black.opacity(0.15)
    }
    static func sidebarRowBackground(for colorScheme: ColorScheme) -> Color {
        Color.white.opacity(0.001)
    }
    static func glassControlBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.white.opacity(0.78) : Color.white.opacity(0.08)
    }
    static func menuBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.white.opacity(0.96) : Color(hex: "#222226").opacity(0.97)
    }
    static func contentBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#F6F7F9") : Color(hex: "#131316")
    }
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        // Dark cards slightly lifted from canvas for quiet depth
        colorScheme == .light ? Color.white : Color(hex: "#1C1C20")
    }
    static func elevatedBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#EEF0F3") : Color(hex: "#26262B")
    }
    
    // Text — calm contrast; dark mode secondary slightly brighter for readability
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#1A1A1E") : Color.white.opacity(0.94)
    }
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color(hex: "#6E6E77") : Color(hex: "#A2A2AB")
    }
    
    // Separators / overlays
    static func separator(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.065) : Color.white.opacity(0.09)
    }
    static func separatorLow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.04) : Color.white.opacity(0.06)
    }
    static func overlayThin(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.05) : Color.black.opacity(0.14)
    }
    static func overlayLow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light ? Color.black.opacity(0.035) : Color.black.opacity(0.08)
    }
    
    // Shared card chrome
    static func cardFill(for colorScheme: ColorScheme) -> some View {
        squircle(radius: cornerRadiusCard)
            .fill(cardBackground(for: colorScheme))
    }
    
    static func cardStroke(for colorScheme: ColorScheme) -> some View {
        squircle(radius: cornerRadiusCard)
            .stroke(separatorLow(for: colorScheme), lineWidth: 1)
    }
    
    // Micro-highlight inner strokes: specular top-edge linear gradient
    static let microHighlightGradient = LinearGradient(
        colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
        startPoint: .top,
        endPoint: .bottom
    )

    static func cardInnerHighlight(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [Color.white.opacity(0.75), Color.white.opacity(0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    static func softShadow(for colorScheme: ColorScheme) -> Color {
        // Barely-there elevation — polish without “floating dashboard”
        colorScheme == .light ? Color.black.opacity(0.035) : Color.black.opacity(0.30)
    }
    
    static var windowBackgroundColor: NSColor {
        NSColor(name: nil) { appearance in
            let isLight = appearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
            return isLight ? NSColor(calibratedWhite: 0.965, alpha: 0.88) : NSColor(calibratedWhite: 0.08, alpha: 0.88)
        }
    }
}

extension Color {
    static func nsColor(hex: String) -> NSColor {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6, let int = UInt64(trimmed, radix: 16) else {
            return .systemOrange
        }
        let r = CGFloat((int & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((int & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(int & 0x0000FF) / 255.0
        return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Layout chrome
extension AppTheme {
    /// Standard unified top header height (traffic lights + toolbar controls).
    static let topHeaderHeight: CGFloat = 48

    /// Clears the transparent titlebar / traffic-light band so detail content
    /// doesn’t sit flush against the top of the window.
    static let detailTopInset: CGFloat = 52

    /// Clearance under traffic lights and the sidebar toggle before the first row.
    static let sidebarTopInset: CGFloat = 48
    
    /// Narrow rail still needs room under the three window buttons (~14×3 + gaps).
    static let collapsedSidebarTopInset: CGFloat = 48
    
    /// Must fit close + miniaturize + zoom with padding (was 64 → green sat past divider).
    static let collapsedSidebarWidth: CGFloat = 80
    
    /// Traffic-light inset matching Gemini / Electron `titleBarStyle: hiddenInset`
    /// (comfortably clear of the rounded window corner) when the sidebar is expanded.
    static let trafficLightLeading: CGFloat = 18
    static let trafficLightTop: CGFloat = 18
    static let trafficLightSpacing: CGFloat = 8
    static let titlebarControlOffset: CGFloat = 13
}

// MARK: - Depth & Multi-Layer Shadow System

enum DepthElevation {
    case flat       // Inset or zero-elevation
    case row        // List rows, interactive tiles
    case card       // Standard dashboard / settings cards
    case elevated   // Hovered / focused / KPI cards
    case floating   // Floating pills, HUD bars
    case popover    // Modals, popovers, dialogs
}

struct MultiLayerShadowConfig {
    let ambientColor: Color
    let ambientRadius: CGFloat
    let ambientY: CGFloat
    let contactColor: Color
    let contactRadius: CGFloat
    let contactY: CGFloat
}

extension AppTheme {
    static func shadowConfig(for elevation: DepthElevation, colorScheme: ColorScheme) -> MultiLayerShadowConfig {
        let isLight = colorScheme == .light
        switch elevation {
        case .flat:
            return MultiLayerShadowConfig(
                ambientColor: .clear, ambientRadius: 0, ambientY: 0,
                contactColor: .clear, contactRadius: 0, contactY: 0
            )
        case .row:
            return MultiLayerShadowConfig(
                ambientColor: isLight ? Color.black.opacity(0.02) : Color.black.opacity(0.18),
                ambientRadius: 3,
                ambientY: 1.5,
                contactColor: isLight ? Color.black.opacity(0.025) : Color.black.opacity(0.20),
                contactRadius: 1,
                contactY: 0.5
            )
        case .card:
            return MultiLayerShadowConfig(
                ambientColor: isLight ? Color.black.opacity(0.035) : Color.black.opacity(0.35),
                ambientRadius: 10,
                ambientY: 4,
                contactColor: isLight ? Color.black.opacity(0.045) : Color.black.opacity(0.30),
                contactRadius: 2,
                contactY: 1
            )
        case .elevated:
            return MultiLayerShadowConfig(
                ambientColor: isLight ? Color.black.opacity(0.06) : Color.black.opacity(0.48),
                ambientRadius: 16,
                ambientY: 8,
                contactColor: isLight ? Color.black.opacity(0.06) : Color.black.opacity(0.38),
                contactRadius: 3.5,
                contactY: 2
            )
        case .floating:
            return MultiLayerShadowConfig(
                ambientColor: isLight ? Color.black.opacity(0.08) : Color.black.opacity(0.55),
                ambientRadius: 20,
                ambientY: 10,
                contactColor: isLight ? Color.black.opacity(0.07) : Color.black.opacity(0.42),
                contactRadius: 4,
                contactY: 2
            )
        case .popover:
            return MultiLayerShadowConfig(
                ambientColor: isLight ? Color.black.opacity(0.10) : Color.black.opacity(0.65),
                ambientRadius: 28,
                ambientY: 14,
                contactColor: isLight ? Color.black.opacity(0.08) : Color.black.opacity(0.48),
                contactRadius: 5,
                contactY: 2.5
            )
        }
    }
}

struct MultiLayerShadowModifier: ViewModifier {
    let elevation: DepthElevation
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        if elevation == .flat {
            content
        } else {
            let config = AppTheme.shadowConfig(for: elevation, colorScheme: colorScheme)
            content
                .shadow(
                    color: config.ambientColor,
                    radius: config.ambientRadius,
                    x: 0,
                    y: config.ambientY
                )
                .shadow(
                    color: config.contactColor,
                    radius: config.contactRadius,
                    x: 0,
                    y: config.contactY
                )
        }
    }
}

struct DepthSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var elevation: DepthElevation = .card
    var cornerRadius: CGFloat = AppTheme.radiusCard
    var fill: Color? = nil

    func body(content: Content) -> some View {
        let shape = AppTheme.squircle(radius: cornerRadius)
        let surfaceFill = fill ?? AppTheme.cardBackground(for: colorScheme)

        content
            .background(shape.fill(surfaceFill))
            .overlay(
                shape.strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
            )
            .overlay(
                shape.strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 1)
            )
            .modifier(MultiLayerShadowModifier(elevation: elevation, colorScheme: colorScheme))
    }
}

extension View {
    /// Multi-layer ambient and contact shadow system.
    func multiLayerShadow(
        elevation: DepthElevation = .card,
        colorScheme: ColorScheme
    ) -> some View {
        modifier(MultiLayerShadowModifier(elevation: elevation, colorScheme: colorScheme))
    }

    /// Depth surface modifier with elevation level, micro-highlight, and continuous squircle curvature.
    func depthSurface(
        elevation: DepthElevation = .card,
        cornerRadius: CGFloat = AppTheme.radiusCard,
        fill: Color? = nil
    ) -> some View {
        modifier(DepthSurfaceModifier(elevation: elevation, cornerRadius: cornerRadius, fill: fill))
    }

    /// Depth surface modifier matching `PROJECT.md` contract.
    func depthSurface(
        elevated: Bool,
        cornerRadius: CGFloat = AppTheme.radiusCard
    ) -> some View {
        modifier(DepthSurfaceModifier(elevation: elevated ? .elevated : .card, cornerRadius: cornerRadius))
    }

    /// Clip view with Apple-standard continuous curvature squircle
    func squircle(radius: CGFloat) -> some View {
        clipShape(AppTheme.squircle(radius: radius))
    }
}

// MARK: - Reusable chrome
struct SoftCardBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = AppTheme.cornerRadiusCard
    var elevated: Bool = false
    
    var body: some View {
        let shape = AppTheme.squircle(radius: cornerRadius)
        shape
            .fill(AppTheme.cardBackground(for: colorScheme))
            .overlay(
                shape.strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 1)
            )
            .overlay(
                shape.strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 1)
            )
            .multiLayerShadow(elevation: elevated ? .elevated : .card, colorScheme: colorScheme)
    }
}

// MARK: - Shared interaction + empty states

/// Soft hover / press for list rows and sidebar-like buttons.
/// Hover wash only — no scale-on-hover (quiet tool).
struct SoftHoverButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        SoftHoverButtonBody(
            configuration: configuration,
            cornerRadius: cornerRadius,
            colorScheme: colorScheme
        )
    }
}

struct SoftHoverButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat
    let colorScheme: ColorScheme
    @State private var hovering = false

    var body: some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillColor)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(AppTheme.springInteractive, value: configuration.isPressed)
            .animation(AppTheme.springSnappy, value: hovering)
            .onHover { hovering = $0 }
    }

    private var fillColor: Color {
        if configuration.isPressed {
            return AppTheme.accent.opacity(colorScheme == .light ? 0.10 : 0.16)
        }
        if hovering {
            return AppTheme.overlayLow(for: colorScheme)
        }
        return .clear
    }
}

struct SoftScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96
    var pressedOpacity: Double = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .opacity(configuration.isPressed ? pressedOpacity : 1.0)
            .animation(AppTheme.springInteractive, value: configuration.isPressed)
    }
}

struct SpringScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.95
    var animation: Animation = AppTheme.springInteractive

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .animation(animation, value: configuration.isPressed)
    }
}

/// Live status dot — soft radial pulse only when active **and** decorative motion is on.
struct PulseDot: View {
    let color: Color
    var isActive: Bool = true
    var size: CGFloat = 7
    /// When false, shows a calm solid/glowing dot (default for quiet tool).
    var allowsPulse: Bool = false

    @State private var pulse = false

    private var shouldPulse: Bool { isActive && allowsPulse }

    var body: some View {
        ZStack {
            if shouldPulse {
                Circle()
                    .fill(color.opacity(0.38))
                    .frame(width: size * 2.6, height: size * 2.6)
                    .scaleEffect(pulse ? 1.2 : 0.7)
                    .opacity(pulse ? 0.12 : 0.5)
            }
            Circle()
                .fill(isActive ? color : color.opacity(0.32))
                .frame(width: size, height: size)
                .shadow(color: isActive ? color.opacity(0.45) : .clear, radius: shouldPulse ? 3.5 : 2.5)
        }
        .frame(width: size * 2.6, height: size * 2.6)
        .onAppear { syncPulse() }
        .onChange(of: isActive) { _ in syncPulse() }
        .onChange(of: allowsPulse) { _ in syncPulse() }
    }

    private func syncPulse() {
        if shouldPulse {
            pulse = false
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                pulse = false
            }
        }
    }
}

// MARK: - Typography Scale & Hierarchy

enum TypeScale {
    // Hero & Display
    static let hero = Font.system(size: 40, weight: .bold, design: .rounded)
    static let timerDigit = Font.system(size: 56, weight: .light, design: .rounded)
    static let kpiValue = Font.system(size: 24, weight: .bold, design: .rounded)

    // Titles
    static let largeTitle = Font.system(size: 26, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let title3 = Font.system(size: 16, weight: .semibold, design: .rounded)

    // Body & Content
    static let headline = Font.system(size: 14, weight: .semibold, design: .default)
    static let body = Font.system(size: 13, weight: .regular, design: .default)
    static let callout = Font.system(size: 12, weight: .medium, design: .default)
    static let subheadline = Font.system(size: 11.5, weight: .regular, design: .default)
    static let footnote = Font.system(size: 11, weight: .regular, design: .default)
    static let caption = Font.system(size: 10, weight: .medium, design: .default)
    static let micro = Font.system(size: 9.5, weight: .semibold, design: .default)
    static let eyebrow = Font.system(size: 10, weight: .semibold, design: .default)

    // Optical Tracking Tokens (Points)
    static let trackingDisplay: CGFloat = -0.6
    static let trackingTitle: CGFloat = -0.3
    static let trackingHeadline: CGFloat = -0.15
    static let trackingBody: CGFloat = 0.0
    static let trackingEyebrow: CGFloat = 0.35
    static let trackingMicro: CGFloat = 0.25
}

extension View {
    func trackingTight() -> some View {
        self.tracking(TypeScale.trackingTitle)
    }

    func trackingEyebrow() -> some View {
        self.tracking(TypeScale.trackingEyebrow)
    }
}

/// Compact keyboard-key chrome for hints (Space / ⌘R).
struct KeyCap: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String
    
    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(TypeScale.trackingMicro)
            .foregroundColor(AppTheme.primaryText(for: colorScheme).opacity(0.85))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                AppTheme.squircle(radius: 5)
                    .fill(AppTheme.elevatedBackground(for: colorScheme))
            )
            .overlay(
                AppTheme.squircle(radius: 5)
                    .strokeBorder(AppTheme.separator(for: colorScheme), lineWidth: 1)
            )
            .overlay(
                AppTheme.squircle(radius: 5)
                    .strokeBorder(AppTheme.cardInnerHighlight(for: colorScheme), lineWidth: 0.5)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .light ? 0.04 : 0.20),
                radius: 1,
                y: 1
            )
    }
}

/// Standardized status pill / micro-tag.
struct EyebrowTag: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    var icon: String? = nil
    var color: Color = AppTheme.accent
    var isPill: Bool = true

    var body: some View {
        HStack(spacing: 3.5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8.5, weight: .bold))
            }
            Text(text)
                .font(TypeScale.eyebrow)
                .tracking(TypeScale.trackingEyebrow)
                .lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(
            Group {
                if isPill {
                    Capsule()
                        .fill(color.opacity(colorScheme == .light ? 0.10 : 0.18))
                } else {
                    AppTheme.squircle(radius: AppTheme.radiusXS)
                        .fill(color.opacity(colorScheme == .light ? 0.10 : 0.18))
                }
            }
        )
        .overlay(
            Group {
                if isPill {
                    Capsule()
                        .strokeBorder(color.opacity(colorScheme == .light ? 0.16 : 0.24), lineWidth: 0.75)
                } else {
                    AppTheme.squircle(radius: AppTheme.radiusXS)
                        .strokeBorder(color.opacity(colorScheme == .light ? 0.16 : 0.24), lineWidth: 0.75)
                }
            }
        )
    }
}

/// Soft card hover lift for interactive surfaces.
struct SoftHoverLift: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = AppTheme.cornerRadiusRow
    @State private var hovering = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(hovering
                          ? AppTheme.accent.opacity(colorScheme == .light ? 0.04 : 0.07)
                          : Color.clear)
                    .allowsHitTesting(false)
            )
            // Minimal hover — quiet tools don't scale rows on mouse-over.
            .animation(.easeOut(duration: 0.12), value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func softHoverLift(cornerRadius: CGFloat = AppTheme.cornerRadiusRow) -> some View {
        modifier(SoftHoverLift(cornerRadius: cornerRadius))
    }
}

/// Unified empty / zero-data surface.
struct AppEmptyState: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemImage: String
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    /// Compact for in-card voids; full for page-level empty shells.
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 10 : 14) {
            ZStack {
                if compact {
                    Circle()
                        .fill(AppTheme.elevatedBackground(for: colorScheme))
                        .frame(width: 40, height: 40)
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.75))
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.accent.opacity(0.14),
                                    AppTheme.accent.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 68, height: 68)
                    Image(systemName: systemImage)
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(AppTheme.accent)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            VStack(spacing: compact ? 4 : 6) {
                Text(title)
                    .font(compact ? .subheadline.weight(.medium) : .headline)
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(compact ? .caption : .subheadline)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(AppTheme.accent))
                }
                .buttonStyle(SoftScaleButtonStyle())
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 16 : 28)
    }
}

struct PageTitle: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.windowLayout) private var windowLayout
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var tint: Color = AppTheme.accent
    
    var body: some View {
        let density = settings.uiDensity
        // Continuous: density preference × window fluid (never stuck “compact forever”).
        let titleSize = max(20, min(30, windowLayout.pageTitleSize))
        let iconBox = 30 * density.scale + windowLayout.eased * 6
        HStack(alignment: .firstTextBaseline, spacing: 10 * density.scale + windowLayout.eased * 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: iconBox * 0.46, weight: .semibold))
                    .foregroundColor(tint.opacity(0.9))
                    .frame(width: iconBox * 0.9, height: iconBox * 0.9)
                    .alignmentGuide(.firstTextBaseline) { d in
                        // Lock icon center to title font firstTextBaseline
                        d[.bottom] * 0.82
                    }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: titleSize, weight: .bold, design: .rounded))
                    .tracking(TypeScale.trackingTitle)
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))
                    .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(TypeScale.caption)
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.9))
                }
            }
            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.16), value: windowLayout.scale)
    }
}
