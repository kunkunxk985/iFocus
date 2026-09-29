import SwiftUI

/// Main Timer Ring View — Things 3 / Apple Notes refined craftsmanship.
/// Renders multi-layer depth tracks with continuous rounded caps, rich gradient progress arc,
/// delicate specular inner bevel, radiant leading cap node, organic breathing glow,
/// and optically tracked center typography with an EyebrowTag badge and cycle indicator.
struct TimerRingView: View {
    let size: CGFloat
    let progress: Double
    let displayTime: String
    let modeTitle: String
    let modeColor: Color
    let isRunning: Bool
    let decorativeMotion: Bool
    let ringBreath: Bool
    var isWorkMode: Bool = true
    var sessionIndex: Int = 1
    var completedInCycle: Int = 0
    var cycleLength: Int = 4

    @Environment(\.colorScheme) private var colorScheme
    @State private var animatedProgress: CGFloat = 1.0
    @State private var lastModeTitle: String = ""
    @State private var lastProgress: CGFloat = 1.0
    @State private var isInitialized: Bool = false

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0.001), 1.0))
    }

    private var modeIcon: String {
        if isWorkMode {
            return "flame.fill"
        } else if modeTitle.contains("长") {
            return "leaf.fill"
        } else {
            return "cup.and.saucer.fill"
        }
    }

    var body: some View {
        let line = max(13, size * 0.062)
        let glowBoost = isRunning ? (decorativeMotion ? 1.0 : 0.72) : 0.38
        let isBreathing = decorativeMotion && isRunning && isWorkMode && ringBreath

        return ZStack {
            // MARK: - 1. Organic Multi-Layer Radial Glow (Breathing in focus mode)
            // Wide diffuse ambient bloom
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            modeColor.opacity((colorScheme == .light ? 0.12 : 0.18) * glowBoost),
                            modeColor.opacity((colorScheme == .light ? 0.03 : 0.06) * glowBoost),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.16,
                        endRadius: size * 0.62
                    )
                )
                .frame(width: size * 1.28, height: size * 1.28)
                .scaleEffect(isBreathing ? 1.045 : 1.0)
                .opacity(isBreathing ? 1.0 : (isRunning && isWorkMode ? 0.88 : 0.65))

            // Radiant core glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            modeColor.opacity((colorScheme == .light ? 0.16 : 0.24) * glowBoost),
                            modeColor.opacity((colorScheme == .light ? 0.05 : 0.09) * glowBoost),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.06,
                        endRadius: size * 0.40
                    )
                )
                .frame(width: size * 1.06, height: size * 1.06)
                .scaleEffect(isBreathing ? 1.03 : 1.0)

            // MARK: - 2. Multi-Layer Depth Tracks (Recessed Machined Channel)
            // Outer subtle hairline guide
            Circle()
                .stroke(
                    colorScheme == .light
                    ? Color.black.opacity(0.04)
                    : Color.white.opacity(0.05),
                    lineWidth: 1
                )
                .frame(width: size + line + 8, height: size + line + 8)

            // Recessed groove track outer contact bevel
            Circle()
                .stroke(
                    colorScheme == .light
                    ? Color.black.opacity(0.06)
                    : Color.black.opacity(0.35),
                    style: StrokeStyle(lineWidth: line + 1.5, lineCap: .round)
                )
                .frame(width: size, height: size)

            // Recessed groove track base plate
            Circle()
                .stroke(
                    colorScheme == .light
                    ? Color(hex: "#E8EAEF").opacity(0.85)
                    : Color(hex: "#1F1F24").opacity(0.90),
                    style: StrokeStyle(lineWidth: line, lineCap: .round)
                )
                .frame(width: size, height: size)

            // Subtle mode ambient tint in groove
            Circle()
                .stroke(
                    modeColor.opacity(colorScheme == .light ? 0.14 : 0.18),
                    style: StrokeStyle(lineWidth: line, lineCap: .round)
                )
                .frame(width: size, height: size)

            // Inner groove specular highlight bevel
            Circle()
                .stroke(
                    colorScheme == .light
                    ? Color.white.opacity(0.65)
                    : Color.white.opacity(0.06),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round)
                )
                .frame(width: max(0, size - line + 1), height: max(0, size - line + 1))

            // Center subtle inner plate
            Circle()
                .fill(
                    colorScheme == .light
                    ? Color.white.opacity(0.40)
                    : Color.white.opacity(0.02)
                )
                .frame(width: max(0, size - line * 1.8), height: max(0, size - line * 1.8))

            // MARK: - 3. Rich Gradient Progress Arc & Specular Bevel
            // Main progress arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    decorativeMotion
                    ? AnyShapeStyle(AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: modeColor.opacity(0.68), location: 0.0),
                            .init(color: modeColor, location: 0.52),
                            .init(color: modeColor.opacity(0.96), location: 1.0)
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ))
                    : AnyShapeStyle(modeColor),
                    style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: modeColor.opacity(isRunning ? (decorativeMotion ? 0.32 : 0.16) : 0.08),
                    radius: isRunning ? (decorativeMotion ? 12 : 6) : 3,
                    y: 0
                )

            // Delicate specular inner stroke / bevel along the arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .light ? 0.45 : 0.30),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: max(1.5, line * 0.18), lineCap: .round)
                )
                .frame(width: max(0, size - line * 0.38), height: max(0, size - line * 0.38))
                .rotationEffect(.degrees(-90))

            // Radiant leading cap dot for high-end optical precision
            if animatedProgress > 0.012 {
                let radius = size / 2
                let angle = Angle.degrees(Double(animatedProgress) * 360.0 - 90.0)
                let capX = radius * CGFloat(cos(angle.radians))
                let capY = radius * CGFloat(sin(angle.radians))

                ZStack {
                    Circle()
                        .fill(modeColor.opacity(0.35))
                        .frame(width: line * 1.15, height: line * 1.15)
                    Circle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: max(3.5, line * 0.38), height: max(3.5, line * 0.38))
                        .shadow(color: Color.white.opacity(0.8), radius: 2)
                }
                .offset(x: capX, y: capY)
            }

            // MARK: - 4. Center Typography & Session Badge
            VStack(spacing: 7) {
                Text(displayTime)
                    .font(.system(size: max(50, size * 0.27), weight: .semibold, design: .rounded))
                    .tracking(TypeScale.trackingDisplay)
                    .monospacedDigit()
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))

                EyebrowTag(
                    text: modeTitle,
                    icon: modeIcon,
                    color: modeColor,
                    isPill: true
                )

                if isWorkMode && cycleLength > 0 {
                    HStack(spacing: 4.5) {
                        ForEach(0..<cycleLength, id: \.self) { index in
                            Circle()
                                .fill(index < completedInCycle ? modeColor : modeColor.opacity(0.22))
                                .frame(width: 4, height: 4)
                        }
                    }
                    .padding(.top, 2)
                    .help("当前番茄周期进度: \(completedInCycle)/\(cycleLength)")
                }
            }
        }
        .frame(width: size * 1.28, height: size * 1.28)
        .onAppear {
            animatedProgress = clampedProgress
            lastModeTitle = modeTitle
            lastProgress = clampedProgress
            isInitialized = true
        }
        .onChange(of: modeTitle) { newMode in
            withAnimation(AppTheme.springInteractive) {
                animatedProgress = clampedProgress
            }
            lastModeTitle = newMode
            lastProgress = clampedProgress
        }
        .onChange(of: clampedProgress) { newProg in
            guard isInitialized else {
                animatedProgress = newProg
                lastProgress = newProg
                return
            }
            let isModeChange = (modeTitle != lastModeTitle)
            let isResetOrJump = (!isRunning && newProg >= 0.999 && lastProgress < 0.999) || abs(newProg - lastProgress) > 0.05
            if isModeChange || isResetOrJump {
                withAnimation(AppTheme.springInteractive) {
                    animatedProgress = newProg
                }
            } else {
                animatedProgress = newProg
            }
            lastProgress = newProg
            lastModeTitle = modeTitle
        }
        .onChange(of: isRunning) { running in
            if !running && clampedProgress >= 0.999 && lastProgress < 0.999 {
                withAnimation(AppTheme.springInteractive) {
                    animatedProgress = clampedProgress
                }
                lastProgress = clampedProgress
            }
        }
    }
}
