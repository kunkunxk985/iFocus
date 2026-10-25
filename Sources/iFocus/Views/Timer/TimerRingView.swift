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
    var isPaused: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @State private var animatedProgress: CGFloat = 1.0
    @State private var lastModeTitle: String = ""
    @State private var lastProgress: CGFloat = 1.0
    @State private var isInitialized: Bool = false

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0.001), 1.0))
    }

    private var modeIcon: String {
        if isPaused { return "pause.fill" }
        if isWorkMode {
            return "flame.fill"
        } else if modeTitle.contains("长") {
            return "leaf.fill"
        } else {
            return "cup.and.saucer.fill"
        }
    }

    var body: some View {
        let line = max(11, size * 0.055)
        let isBreathing = decorativeMotion && isRunning && isWorkMode && ringBreath

        return ZStack {
            // MARK: - 1. Organic Breathing Ambient (Quiet single layer in focus mode)
            if decorativeMotion && isRunning && isWorkMode {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                modeColor.opacity((colorScheme == .light ? 0.07 : 0.12) * (ringBreath ? 1.0 : 0.6)),
                                .clear
                            ],
                            center: .center,
                            startRadius: size * 0.20,
                            endRadius: size * 0.56
                        )
                    )
                    .frame(width: size * 1.15, height: size * 1.15)
                    .scaleEffect(isBreathing ? 1.025 : 1.0)
            }

            // MARK: - 2. Minimalist Base Track (Quiet, hairline-precise Apple craftsmanship)
            Circle()
                .stroke(
                    colorScheme == .light
                    ? Color.black.opacity(0.065)
                    : Color.white.opacity(0.08),
                    style: StrokeStyle(lineWidth: line, lineCap: .round)
                )
                .frame(width: size, height: size)

            // MARK: - 3. Clean Vibrant Progress Arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    modeColor,
                    style: StrokeStyle(lineWidth: line, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: modeColor.opacity(isRunning && decorativeMotion ? 0.22 : 0.0),
                    radius: 8,
                    y: 0
                )

            // Radiant leading cap node (Apple Watch luxury sweep feel)
            if isRunning && decorativeMotion && animatedProgress > 0.015 && animatedProgress < 0.995 {
                let angle = -90.0 + Double(animatedProgress) * 360.0
                let radius = size / 2.0
                let rad = angle * .pi / 180.0
                Circle()
                    .fill(Color.white)
                    .frame(width: line * 0.70, height: line * 0.70)
                    .shadow(color: modeColor.opacity(0.9), radius: 5, x: 0, y: 0)
                    .offset(x: radius * cos(rad), y: radius * sin(rad))
            }

            // MARK: - 4. Center Typography & Session Badge (The Single Primary Focus)
            VStack(spacing: 8) {
                Text(displayTime)
                    .font(.system(size: max(54, size * 0.29), weight: .medium, design: .rounded))
                    .tracking(-0.5)
                    .monospacedDigit()
                    // Count-up past an hour reads h:mm:ss; shrink rather than clip.
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundColor(AppTheme.primaryText(for: colorScheme))

                EyebrowTag(
                    text: modeTitle,
                    icon: modeIcon,
                    color: isPaused ? AppTheme.paused : modeColor,
                    isPill: true
                )
            }
        }
        .frame(width: size, height: size)
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
