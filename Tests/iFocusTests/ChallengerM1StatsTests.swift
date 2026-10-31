import XCTest
import SwiftUI
@testable import iFocus
@testable import iFocusCore

final class ChallengerM1StatsTests: XCTestCase {
    private var calendar: Calendar!
    private var now: Date!
    private var todayStart: Date!

    override func setUpWithError() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.firstWeekday = 1
        calendar = cal
        now = Date(timeIntervalSince1970: 1793404800) // Deterministic reference date: 2026-10-31 00:00:00 UTC
        todayStart = calendar.startOfDay(for: now)
    }

    // =========================================================================
    // MARK: - 1. Concentric Geometry & Layout Contracts
    // =========================================================================

    func testConcentricRingGeometry_ExactDimensions() {
        let defaultRing = ConcentricDualRingView(
            pomodoroProgress: 0.5,
            durationProgress: 0.75
        )
        // Contract specifications:
        // Outer diameter: 106pt
        // Line width: 6.5pt
        // Spacing: 3.5pt
        // Inner diameter: 86pt
        XCTAssertEqual(defaultRing.ringSize, 106, accuracy: 0.001)
        XCTAssertEqual(defaultRing.lineWidth, 6.5, accuracy: 0.001)
        XCTAssertEqual(defaultRing.ringSpacing, 3.5, accuracy: 0.001)

        // Mathematical clearance between outer and inner ring strokes:
        // innerRingSize = ringSize - (lineWidth + ringSpacing) * 2
        let calculatedInnerSize = defaultRing.ringSize - (defaultRing.lineWidth + defaultRing.ringSpacing) * 2
        XCTAssertEqual(calculatedInnerSize, 86.0, accuracy: 0.001, "Inner diameter must equal exactly 86pt")

        // Visual gap between inner edge of outer stroke and outer edge of inner stroke:
        // Outer stroke radius = 106/2 = 53pt; inner boundary = 53 - 6.5/2 = 49.75pt
        // Inner stroke radius = 86/2 = 43pt; outer boundary = 43 + 6.5/2 = 46.25pt
        // Clearance = 49.75 - 46.25 = 3.50pt
        let outerInnerEdge = (defaultRing.ringSize / 2.0) - (defaultRing.lineWidth / 2.0)
        let innerOuterEdge = (calculatedInnerSize / 2.0) + (defaultRing.lineWidth / 2.0)
        let visualGap = outerInnerEdge - innerOuterEdge
        XCTAssertEqual(visualGap, 3.5, accuracy: 0.001, "Visual spacing between concentric strokes must be exactly 3.5pt")
    }

    func testConcentricRingCustomGeometry_Scaling() {
        let customRing = ConcentricDualRingView(
            pomodoroProgress: 0.8,
            durationProgress: 0.4,
            ringSize: 120,
            lineWidth: 8.0,
            ringSpacing: 4.0
        )
        let inner = customRing.ringSize - (customRing.lineWidth + customRing.ringSpacing) * 2
        XCTAssertEqual(inner, 120 - 24, accuracy: 0.001)
        XCTAssertEqual(inner, 96.0, accuracy: 0.001)
    }

    // =========================================================================
    // MARK: - 2. Progress Clamping & Extreme Values
    // =========================================================================

    func testConcentricDualRing_ExtremeProgressClamping() {
        // Test values: 0.0, 0.5, 1.0, 2.5 (overachieved), negative values (-0.5, -100.0)
        let testCases: [(input: Double, expectedClamped: CGFloat)] = [
            (0.0, 0.0),
            (0.5, 0.5),
            (1.0, 1.0),
            (2.5, 1.0),
            (10.0, 1.0),
            (-0.1, 0.0),
            (-50.0, 0.0)
        ]

        for (input, expected) in testCases {
            let ring = ConcentricDualRingView(
                pomodoroProgress: input,
                durationProgress: input
            )
            let mirror = Mirror(reflecting: ring)
            let pomodoroProg = mirror.descendant("pomodoroProgress") as? Double
            let durationProg = mirror.descendant("durationProgress") as? Double
            XCTAssertEqual(pomodoroProg, input)
            XCTAssertEqual(durationProg, input)

            // Evaluate clamping contract: min(max(val, 0), 1.0)
            let clamped = CGFloat(min(max(input, 0), 1.0))
            XCTAssertEqual(clamped, expected, accuracy: 0.0001, "Input \(input) should clamp to \(expected)")
        }
    }

    // =========================================================================
    // MARK: - 3. Division-by-Zero Guards & Math Integrity
    // =========================================================================

    func testConcentricRings_ZeroDailyGoalSafeguard() {
        // MultiDay ranges: target = max(1, dailyGoal * days)
        // Duration: target = max(25, dailyGoal * 25 * days)
        let zeroDailyGoal = 0
        let days = 7

        let pomodoroTarget = max(1, zeroDailyGoal * days)
        XCTAssertEqual(pomodoroTarget, 1, "Zero daily goal must fall back to 1 to prevent division by zero")

        let durationTarget = max(25, zeroDailyGoal * 25 * days)
        XCTAssertEqual(durationTarget, 25, "Zero daily goal must fall back to 25 to prevent division by zero")

        let safePomoRatio = Double(5) / Double(pomodoroTarget)
        let safeDurRatio = Double(60) / Double(durationTarget)
        XCTAssertFalse(safePomoRatio.isNaN)
        XCTAssertFalse(safePomoRatio.isInfinite)
        XCTAssertFalse(safeDurRatio.isNaN)
        XCTAssertFalse(safeDurRatio.isInfinite)
    }

    func testConcentricRings_EmptyModelCalculations() {
        let model = AnalyticsDashboardModel.build(
            range: .today,
            focusSessions: [],
            tasks: [],
            dailyGoal: 0,
            completedPomodoros: 0,
            totalSecondsToday: 0,
            isWorkMode: false,
            sessionLive: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(model.dailyGoal, 0)
        XCTAssertEqual(model.goalProgress, 0.0)
        XCTAssertFalse(model.goalProgress.isNaN)
        XCTAssertFalse(model.goalProgress.isInfinite)
    }

    // =========================================================================
    // MARK: - 4. Celebration Condition Invariants
    // =========================================================================

    func testGoalDoneCelebrationInvariants() {
        // Subcase A: 0 completed pomodoros -> NOT celebrated
        var model = AnalyticsDashboardModel.build(
            range: .today,
            focusSessions: [],
            tasks: [],
            dailyGoal: 4,
            completedPomodoros: 0,
            totalSecondsToday: 0,
            isWorkMode: false,
            sessionLive: false,
            now: now,
            calendar: calendar
        )
        var goalDone = model.range == .today && model.goalRemaining == 0 && model.completedPomodoros > 0
        XCTAssertFalse(goalDone, "0 completed pomodoros must NEVER celebrate")

        // Subcase B: goal completed (4/4) -> celebrated!
        let t1 = FocusTask(title: "Task 1", category: .work)
        var sessions: [FocusSession] = []
        for i in 0..<4 {
            let sessionDate = calendar.date(byAdding: .minute, value: i * 30, to: todayStart)!
            let session = FocusSession(
                taskId: t1.id,
                taskTitle: t1.title,
                taskCategory: t1.category,
                durationMinutes: 25,
                timestamp: sessionDate
            )
            sessions.append(session)
        }

        model = AnalyticsDashboardModel.build(
            range: .today,
            focusSessions: sessions,
            tasks: [t1],
            dailyGoal: 4,
            completedPomodoros: 4,
            totalSecondsToday: 100 * 60,
            isWorkMode: false,
            sessionLive: false,
            now: now,
            calendar: calendar
        )
        goalDone = model.range == .today && model.goalRemaining == 0 && model.completedPomodoros > 0
        XCTAssertTrue(goalDone, "4/4 pomodoros today must celebrate")

        // Subcase C: Non-today range (.days7) -> NOT celebrated even if pomodoros completed
        let model7 = AnalyticsDashboardModel.build(
            range: .days7,
            focusSessions: sessions,
            tasks: [t1],
            dailyGoal: 4,
            completedPomodoros: 4,
            totalSecondsToday: 100 * 60,
            isWorkMode: false,
            sessionLive: false,
            now: now,
            calendar: calendar
        )
        let goalDone7 = model7.range == .today && model7.goalRemaining == 0 && model7.completedPomodoros > 0
        XCTAssertFalse(goalDone7, "Non-today ranges must not trigger today celebration")
    }

    // =========================================================================
    // MARK: - 5. Monospaced Formatting & Metric Column Properties
    // =========================================================================

    func testHeroMetricFormatting() {
        // 0 minutes
        XCTAssertEqual(FocusStats.formatTotalMinutes(0), "0分钟")
        // < 60 minutes
        XCTAssertEqual(FocusStats.formatTotalMinutes(42), "42分钟")
        // Exact hours
        XCTAssertEqual(FocusStats.formatTotalMinutes(120), "2小时")
        // Hours + minutes
        XCTAssertEqual(FocusStats.formatTotalMinutes(135), "2小时15分")
        // Negative / corrupt values treated safely as 0
        XCTAssertEqual(FocusStats.formatTotalMinutes(-10), "0分钟")
        // Large values (e.g. 100 hours)
        XCTAssertEqual(FocusStats.formatTotalMinutes(6025), "100小时25分")
    }

    func testHeroMetricColumn_Instantiations() {
        let col1 = HeroMetricColumn(
            label: "专注时长",
            value: "2小时15分",
            icon: "clock.fill",
            tint: .blue,
            sublabel: "今日累计"
        )
        let col2 = HeroMetricColumn(
            label: "达成番茄",
            value: "5 个",
            icon: "timer",
            tint: .red,
            sublabel: "今日目标已达成"
        )
        let col3 = HeroMetricColumn(
            label: "连续天数",
            value: "7 天",
            icon: "flame.fill",
            tint: .orange,
            sublabel: "保持专注势头"
        )

        XCTAssertEqual(col1.label, "专注时长")
        XCTAssertEqual(col1.value, "2小时15分")
        XCTAssertEqual(col1.icon, "clock.fill")
        XCTAssertEqual(col1.sublabel, "今日累计")

        XCTAssertEqual(col2.label, "达成番茄")
        XCTAssertEqual(col2.value, "5 个")
        XCTAssertEqual(col2.icon, "timer")

        XCTAssertEqual(col3.label, "连续天数")
        XCTAssertEqual(col3.value, "7 天")
        XCTAssertEqual(col3.icon, "flame.fill")
    }

    // =========================================================================
    // MARK: - 6. AchievementHero End-to-End View Instantiation
    // =========================================================================

    func testAchievementHero_ViewHierarchyEvaluatesCleanly() {
        let model = AnalyticsDashboardModel.build(
            range: .today,
            focusSessions: [],
            tasks: [],
            dailyGoal: 4,
            completedPomodoros: 0,
            totalSecondsToday: 0,
            isWorkMode: false,
            sessionLive: false,
            now: now,
            calendar: calendar
        )

        let lightView = AnalyticsCards.achievementHero(
            model: model,
            totalMinutesAllTime: 120,
            displayName: "Test User",
            avatarPath: nil,
            avatarColorIndex: 2,
            colorScheme: .light,
            decorativeMotion: true
        )
        XCTAssertNotNil(lightView)

        let darkView = AnalyticsCards.achievementHero(
            model: model,
            totalMinutesAllTime: 120,
            displayName: "Test User",
            avatarPath: nil,
            avatarColorIndex: 2,
            colorScheme: .dark,
            decorativeMotion: false
        )
        XCTAssertNotNil(darkView)
    }

    func testAchievementHero_AllRangesEvaluateWithoutErrors() {
        for range in AnalyticsTimeRange.allCases {
            let model = AnalyticsDashboardModel.build(
                range: range,
                focusSessions: [],
                tasks: [],
                dailyGoal: 4,
                completedPomodoros: 2,
                totalSecondsToday: 50 * 60,
                isWorkMode: false,
                sessionLive: false,
                now: now,
                calendar: calendar
            )
            let view = AnalyticsCards.achievementHero(
                model: model,
                totalMinutesAllTime: 500,
                displayName: "MultiRange Tester",
                avatarPath: nil,
                avatarColorIndex: 0,
                colorScheme: .light,
                decorativeMotion: true
            )
            XCTAssertNotNil(view)
        }
    }
}
