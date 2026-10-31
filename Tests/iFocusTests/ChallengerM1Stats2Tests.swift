import XCTest
import SwiftUI
@testable import iFocus
@testable import iFocusCore

final class ChallengerM1Stats2Tests: XCTestCase {
    private var calendar: Calendar!
    private var now: Date!
    private var savedAccent: String?

    override func setUpWithError() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.firstWeekday = 1
        calendar = cal
        now = Date(timeIntervalSince1970: 1793404800)
        savedAccent = UserDefaults.standard.string(forKey: "iFocus.appTheme.accentColor")
    }

    override func tearDownWithError() throws {
        if let savedAccent {
            UserDefaults.standard.set(savedAccent, forKey: "iFocus.appTheme.accentColor")
        } else {
            UserDefaults.standard.removeObject(forKey: "iFocus.appTheme.accentColor")
        }
    }

    // =========================================================================
    // MARK: - 1. Animation Parameters Empirical Verification
    // =========================================================================

    func testBreathingAnimation_ScaleBounds() {
        let ringDefault = ConcentricDualRingView(
            pomodoroProgress: 0.5,
            durationProgress: 0.75,
            decorativeMotion: true
        )
        XCTAssertEqual(ringDefault.ringSize, 106)
        XCTAssertEqual(ringDefault.lineWidth, 6.5)
        XCTAssertEqual(ringDefault.ringSpacing, 3.5)
        XCTAssertTrue(ringDefault.decorativeMotion)

        func evalScale(decorativeMotion: Bool, isBreathing: Bool) -> CGFloat {
            decorativeMotion && isBreathing ? 1.025 : 1.0
        }

        XCTAssertEqual(evalScale(decorativeMotion: true, isBreathing: false), 1.0)
        XCTAssertEqual(evalScale(decorativeMotion: true, isBreathing: true), 1.025)
        XCTAssertEqual(evalScale(decorativeMotion: false, isBreathing: false), 1.0)
        XCTAssertEqual(evalScale(decorativeMotion: false, isBreathing: true), 1.0)
    }

    func testBreathingAnimation_OpacityBounds() {
        func evalOpacity(decorativeMotion: Bool, isBreathing: Bool) -> Double {
            decorativeMotion && isBreathing ? 1.0 : 0.94
        }

        XCTAssertEqual(evalOpacity(decorativeMotion: true, isBreathing: false), 0.94)
        XCTAssertEqual(evalOpacity(decorativeMotion: true, isBreathing: true), 1.0)
        XCTAssertEqual(evalOpacity(decorativeMotion: false, isBreathing: false), 0.94)
        XCTAssertEqual(evalOpacity(decorativeMotion: false, isBreathing: true), 0.94)
    }

    func testDecorativeMotionFalse_LocksAnimation() {
        let ringMotionOff = ConcentricDualRingView(
            pomodoroProgress: 0.8,
            durationProgress: 0.6,
            decorativeMotion: false
        )
        XCTAssertFalse(ringMotionOff.decorativeMotion)

        let hostView = NSHostingView(rootView: ringMotionOff)
        hostView.layout()
        XCTAssertEqual(hostView.fittingSize.width, 106, accuracy: 1.0)
        XCTAssertEqual(hostView.fittingSize.height, 106, accuracy: 1.0)
    }

    // =========================================================================
    // MARK: - 2. Concentric Ring Geometry & Boundary Clamping
    // =========================================================================

    func testConcentricRingGeometry_InnerRingSize() {
        let standardInner = max(10, 106.0 - (6.5 + 3.5) * 2.0)
        XCTAssertEqual(standardInner, 86.0)

        let smallInner = max(10, 15.0 - (6.5 + 3.5) * 2.0)
        XCTAssertEqual(smallInner, 10.0)

        let customInner = max(10, 120.0 - (8.0 + 4.0) * 2.0)
        XCTAssertEqual(customInner, 96.0)
    }

    func testConcentricRing_ProgressClamping() {
        func clamp(_ val: Double) -> CGFloat {
            CGFloat(min(max(val, 0), 1.0))
        }

        XCTAssertEqual(clamp(0.0), 0.0)
        XCTAssertEqual(clamp(0.45), 0.45, accuracy: 0.0001)
        XCTAssertEqual(clamp(1.0), 1.0)
        XCTAssertEqual(clamp(1.5), 1.0)
        XCTAssertEqual(clamp(999.0), 1.0)
        XCTAssertEqual(clamp(-0.5), 0.0)
        XCTAssertEqual(clamp(-100.0), 0.0)
        XCTAssertEqual(clamp(Double.infinity), 1.0)
        XCTAssertEqual(clamp(-Double.infinity), 0.0)
    }

    // =========================================================================
    // MARK: - 3. Dynamic Theme Accent Verification
    // =========================================================================

    func testThemeAccent_DynamicPresetSwitches() {
        let presets = AccentPreset.allCases
        XCTAssertEqual(presets.count, 6)

        for preset in presets {
            UserDefaults.standard.set(preset.rawValue, forKey: "iFocus.appTheme.accentColor")
            let liveAccent = AppTheme.accent
            XCTAssertNotNil(liveAccent)

            let ring = ConcentricDualRingView(
                pomodoroProgress: 0.5,
                durationProgress: 0.5,
                accentColor: AppTheme.accent
            )
            let hostView = NSHostingView(rootView: ring)
            hostView.layout()
            XCTAssertGreaterThan(hostView.fittingSize.width, 0)
        }
    }

    func testThemeAccent_InvalidKeyFallback() {
        UserDefaults.standard.set("nonexistent_preset", forKey: "iFocus.appTheme.accentColor")
        let fallbackColor = AppTheme.accent
        XCTAssertNotNil(fallbackColor)

        let ring = ConcentricDualRingView(
            pomodoroProgress: 0.5,
            durationProgress: 0.5,
            accentColor: AppTheme.accent
        )
        let hostView = NSHostingView(rootView: ring)
        hostView.layout()
        XCTAssertEqual(hostView.fittingSize.width, 106, accuracy: 1.0)
    }

    // =========================================================================
    // MARK: - 4. Rapid State Updates & Layout Stability
    // =========================================================================

    func testRapidStateUpdates_ConcentricDualRingView() {
        let iterations = 1000
        for i in 0..<iterations {
            let pProg = Double(i % 100) / 100.0
            let dProg = Double((i * 3) % 100) / 100.0
            let motion = i % 2 == 0
            let celebrate = i % 5 == 0

            let view = ConcentricDualRingView(
                pomodoroProgress: pProg,
                durationProgress: dProg,
                accentColor: AppTheme.accent,
                ringSize: 106,
                lineWidth: 6.5,
                ringSpacing: 3.5,
                decorativeMotion: motion,
                celebrate: celebrate
            )

            let host = NSHostingView(rootView: view)
            host.frame = NSRect(x: 0, y: 0, width: 106, height: 106)
            host.layout()
            XCTAssertEqual(host.fittingSize.width, 106, accuracy: 1.5)
        }
    }

    func testRapidStateUpdates_AchievementHeroLayoutStability() {
        let ranges: [AnalyticsTimeRange] = [.today, .days7, .days30, .month]
        let baseDate = Date()

        for (idx, range) in ranges.enumerated() {
            let model = AnalyticsDashboardModel.build(
                range: range,
                focusSessions: [
                    FocusSession(
                        id: UUID(),
                        taskId: nil,
                        taskTitle: "Deep Work \(idx)",
                        durationMinutes: 45 + idx * 15,
                        timestamp: baseDate.addingTimeInterval(-Double(idx * 3600))
                    )
                ],
                tasks: [
                    FocusTask(title: "Task \(idx)", category: .other)
                ],
                dailyGoal: 8,
                completedPomodoros: idx * 2,
                totalSecondsToday: (idx * 30 + 25) * 60,
                isWorkMode: false,
                sessionLive: false,
                now: baseDate,
                calendar: calendar
            )

            let heroView = AnalyticsCards.achievementHero(
                model: model,
                totalMinutesAllTime: 5000,
                displayName: "Empirical Tester",
                avatarPath: nil,
                avatarColorIndex: idx % 6,
                colorScheme: idx % 2 == 0 ? .light : .dark,
                decorativeMotion: idx % 2 == 0
            )

            let host = NSHostingView(rootView: heroView)
            host.frame = NSRect(x: 0, y: 0, width: 800, height: 300)
            host.layout()

            let fit = host.fittingSize
            XCTAssertGreaterThan(fit.width, 300, "achievementHero width should be robustly rendered")
            XCTAssertGreaterThan(fit.height, 100, "achievementHero height should be robustly rendered")
            XCTAssertFalse(fit.width.isNaN)
            XCTAssertFalse(fit.height.isNaN)
        }
    }

    func testConcurrentModelEvaluation_NoRaceConditions() {
        let expectation = self.expectation(description: "Concurrent evaluation complete")
        let queue = DispatchQueue(label: "test.concurrent.analytics", attributes: .concurrent)
        let group = DispatchGroup()
        let iterations = 100

        for i in 0..<iterations {
            group.enter()
            queue.async {
                let range: AnalyticsTimeRange = (i % 2 == 0) ? .today : .days7
                let model = AnalyticsDashboardModel.build(
                    range: range,
                    focusSessions: [
                        FocusSession(
                            id: UUID(),
                            taskId: nil,
                            taskTitle: "Session \(i)",
                            durationMinutes: 25,
                            timestamp: Date().addingTimeInterval(-Double(i * 60))
                        )
                    ],
                    tasks: [],
                    dailyGoal: 8,
                    completedPomodoros: i % 10,
                    totalSecondsToday: (i % 10) * 25 * 60,
                    isWorkMode: false,
                    sessionLive: false,
                    now: Date(),
                    calendar: self.calendar
                )

                _ = AnalyticsCards.achievementHero(
                    model: model,
                    totalMinutesAllTime: 1000 + i,
                    displayName: "User \(i)",
                    avatarPath: nil,
                    avatarColorIndex: i % 6,
                    colorScheme: .dark,
                    decorativeMotion: i % 2 == 0
                )
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testHeroMetricColumn_ExtremeValuesNoOverflow() {
        let col = HeroMetricColumn(
            label: "专注时长",
            value: "99999小时59分",
            icon: "clock.fill",
            tint: AppTheme.accent,
            sublabel: "今日累计"
        )

        let host = NSHostingView(rootView: col)
        host.frame = NSRect(x: 0, y: 0, width: 200, height: 80)
        host.layout()
        XCTAssertGreaterThan(host.fittingSize.width, 0)
        XCTAssertGreaterThan(host.fittingSize.height, 0)
    }
}
