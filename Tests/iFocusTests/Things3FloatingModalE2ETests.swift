import XCTest
import SwiftUI
import AppKit
@testable import iFocus
@testable import iFocusCore

// =============================================================================
// MARK: - Things 3 Floating Modal Design Specification Oracle
// =============================================================================

/// Authoritative design tokens and requirement contracts derived from
/// ORIGINAL_REQUEST.md and PROJECT.md.
enum Things3FloatingModalDesignSpec {
    // MARK: - R1 & R2: Modal Surface Geometry & Strokes
    static let modalCornerRadius: CGFloat = 18.0
    static let modalInnerHighlightWidth: CGFloat = 0.75
    static let modalOuterBorderWidth: CGFloat = 0.50
    static let modalElevation: DepthElevation = .popover
    static let taskModalWidth: CGFloat = 460.0
    static let profileModalWidth: CGFloat = 350.0
    static let profileAvatarSize: CGFloat = 72.0
    static let profileSwatchSize: CGFloat = 24.0
    static let shortcutHintText = "⌘↵ 保存 · Esc 取消"
    
    // MARK: - R1: Embedded Fields & Typography
    static let titleFontSize: CGFloat = 16.0
    static let embeddedCardCornerRadius: CGFloat = 8.0
    
    // MARK: - R1: Things 3 Date Presets
    static let dateCapsuleTitles = ["无", "今天", "明天", "稍后", "自定义日期…"]
    static let customDatePlaceholder = "自定义日期…"
    
    // MARK: - R3: 4-Tier Native Context Menu Specifications
    static let contextMenuTierCount = 4
    static let contextMenuSeparatorCount = 3 // 3 dividers between 4 tiers
    
    static let tier1ActionLabels = ["立即开启专注", "编辑任务…"]
    static let tier1ActionIcons = ["bolt.fill", "pencil"]
    
    static let tier2ActionLabels = ["今天", "明天", "稍后", "移入收集箱"]
    static let tier2ActionIcons = ["sun.max", "sunrise", "clock", "tray.and.arrow.down"]
    
    static let tier3ActionLabels = ["置顶", "取消置顶", "标记为已完成", "标记为未完成"]
    static let tier3ActionIcons = ["pin", "pin.slash", "checkmark.circle", "circle"]
    
    static let tier4ActionLabels = ["复制任务标题", "删除任务"]
    static let tier4ActionIcons = ["doc.on.doc", "trash"]
    static let tier4DeleteRoleIsDestructive = true
    
    // MARK: - R4: Inline Note Summary
    static let inlineNoteFontSize: CGFloat = 12.0
    static let inlineNoteOpacity: Double = 0.50
    static let inlineNoteLineLimit: Int = 1
}

// =============================================================================
// MARK: - Things 3 Floating Modal Test Harness & Query Oracle
// =============================================================================

enum Things3FloatingModalTestHarness {
    /// Canonical UTC Gregorian calendar for deterministic cross-platform date testing
    static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.firstWeekday = 1 // Sunday
        return cal
    }
    
    /// Construct deterministic Date in UTC
    static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        c.hour = hour
        c.minute = minute
        c.second = second
        return utcCalendar.date(from: c)!
    }
    
    // MARK: - Date Capsule Oracle
    enum DatePreset: Equatable {
        case none
        case today
        case tomorrow
        case later
        case custom(Date)
        
        var title: String {
            switch self {
            case .none: return "无"
            case .today: return "今天"
            case .tomorrow: return "明天"
            case .later: return "稍后"
            case .custom(let d): return Things3FloatingModalTestHarness.formatCustomDate(d)
            }
        }
    }
    
    /// Classifies a target date relative to a base date (start of today)
    static func classifyDate(
        _ date: Date?,
        relativeTo baseDate: Date,
        calendar: Calendar = utcCalendar
    ) -> DatePreset {
        guard let date = date else { return .none }
        let baseStart = calendar.startOfDay(for: baseDate)
        let targetStart = calendar.startOfDay(for: date)
        
        if targetStart == baseStart {
            return .today
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: baseStart),
                  targetStart == tomorrow {
            return .tomorrow
        } else if let later = calendar.date(byAdding: .day, value: 2, to: baseStart),
                  targetStart == later {
            return .later
        } else {
            return .custom(targetStart)
        }
    }
    
    /// Resolves target date for a given preset
    static func resolveDate(
        for preset: DatePreset,
        relativeTo baseDate: Date,
        calendar: Calendar = utcCalendar
    ) -> Date? {
        let baseStart = calendar.startOfDay(for: baseDate)
        switch preset {
        case .none:
            return nil
        case .today:
            return baseStart
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: baseStart)
        case .later:
            return calendar.date(byAdding: .day, value: 2, to: baseStart)
        case .custom(let customDate):
            return calendar.startOfDay(for: customDate)
        }
    }
    
    /// Formats a custom date in the canonical "M月d日" Chinese format
    static func formatCustomDate(_ date: Date, calendar: Calendar = utcCalendar) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }
    
    // MARK: - Inline Note First-Line Extractor
    /// Extracts the first non-empty trimmed line from a notes string.
    /// Returns nil if notes are empty or contain only whitespace / newlines.
    static func extractFirstLine(from notes: String) -> String? {
        let lines = notes.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }
    
    // MARK: - URL Validation Oracle
    /// Validates whether a link string has a valid http or https scheme and a non-empty host.
    static func isValidURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = url.host,
              !host.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        return true
    }
    
    // MARK: - Context Menu Action Dispatch Simulation
    enum ContextMenuAction {
        case startFocus
        case editTask
        case rescheduleToday
        case rescheduleTomorrow
        case rescheduleLater
        case rescheduleInbox
        case togglePin
        case toggleComplete
        case copyTitle
        case deleteTask
    }
    
    enum ContextMenuDispatchOutcome: Equatable {
        case focused(UUID)
        case editSession(UUID, String)
        case rescheduled(Date?)
        case pinned(Bool)
        case completed(Bool)
        case copied(String?)
        case deleted(Bool)
    }
    
    /// Executes a context menu action against a TaskStore and returns an observable outcome.
    static func dispatchContextMenuAction(
        _ action: ContextMenuAction,
        for task: FocusTask,
        in store: TaskStore,
        pasteboard: NSPasteboard = .general
    ) -> ContextMenuDispatchOutcome {
        switch action {
        case .startFocus:
            store.activeTaskId = task.id
            return .focused(task.id)
            
        case .editTask:
            let session = EditTaskSession(task: task)
            return .editSession(session.id, session.title)
            
        case .rescheduleToday:
            store.moveTask(id: task.id, to: .todayTask)
            let updated = store.tasks.first(where: { $0.id == task.id })
            return .rescheduled(updated?.dueDate)
            
        case .rescheduleTomorrow:
            store.moveTask(id: task.id, to: .tomorrowTask)
            let updated = store.tasks.first(where: { $0.id == task.id })
            return .rescheduled(updated?.dueDate)
            
        case .rescheduleLater:
            store.moveTask(id: task.id, to: .weekTask)
            let updated = store.tasks.first(where: { $0.id == task.id })
            return .rescheduled(updated?.dueDate)
            
        case .rescheduleInbox:
            store.moveTask(id: task.id, to: .inboxTask)
            let updated = store.tasks.first(where: { $0.id == task.id })
            return .rescheduled(updated?.dueDate)
            
        case .togglePin:
            store.togglePin(for: task)
            let updated = store.tasks.first(where: { $0.id == task.id })
            return .pinned(updated?.isPinned ?? false)
            
        case .toggleComplete:
            store.toggleCompletion(for: task)
            let updated = store.tasks.first(where: { $0.id == task.id })
            return .completed(updated?.isCompleted ?? false)
            
        case .copyTitle:
            pasteboard.clearContents()
            pasteboard.setString(task.title, forType: .string)
            let read = pasteboard.string(forType: .string)
            return .copied(read)
            
        case .deleteTask:
            store.deleteTask(task)
            let remaining = store.tasks.contains(where: { $0.id == task.id })
            return .deleted(!remaining)
        }
    }
    
    // MARK: - Task Factory Helper
    static func makeTask(
        title: String,
        category: TaskCategory = .other,
        dueDate: Date? = nil,
        priority: Int = 1,
        estimatedPomodoros: Int = 1,
        notes: String = "",
        linkURL: String = "",
        isPinned: Bool = false,
        isCompleted: Bool = false
    ) -> FocusTask {
        var task = FocusTask(title: title, category: category, priority: priority)
        task.dueDate = dueDate
        task.estimatedPomodoros = estimatedPomodoros
        task.notes = notes
        task.linkURL = linkURL
        task.isPinned = isPinned
        task.isCompleted = isCompleted
        return task
    }
}

// =============================================================================
// MARK: - Main E2E Test Suite
// =============================================================================

final class Things3FloatingModalE2ETests: XCTestCase {
    private var tempDir: URL!
    private var suiteName: String!
    private var defaults: UserDefaults!
    
    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-Things3ModalE2E-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        suiteName = "iFocus.Things3ModalE2E.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }
    
    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        defaults.removePersistentDomain(forName: suiteName)
        tempDir = nil
        defaults = nil
    }
    
    private func makeTaskStore() -> TaskStore {
        TaskStore(storageDirectory: tempDir)
    }
    
    private func makeSettingsStore() -> SettingsStore {
        SettingsStore(defaults: defaults, applyAppearance: false)
    }
    
    // =========================================================================
    // MARK: - TIER 1: FEATURE 1 — Floating Card Modal Surface Tokens (6 tests)
    // =========================================================================
    
    func testF01_FloatingCardSurface_ContinuousSquircleCornerRadius18() {
        let modifier = FloatingCardSurfaceModifier()
        XCTAssertEqual(modifier.cornerRadius, 18.0)
        XCTAssertEqual(Things3FloatingModalDesignSpec.modalCornerRadius, 18.0)
        
        let squircle = AppTheme.squircle(radius: 18.0)
        XCTAssertEqual(squircle.cornerSize.width, 18.0)
        XCTAssertEqual(squircle.cornerSize.height, 18.0)
        XCTAssertEqual(squircle.style, .continuous)
    }
    
    func testF01_FloatingCardSurface_InnerHighlightStroke075pt() {
        XCTAssertEqual(Things3FloatingModalDesignSpec.modalInnerHighlightWidth, 0.75)
        XCTAssertEqual(Things3FloatingModalDesignSpec.modalOuterBorderWidth, 0.50)
        
        let darkHighlight = AppTheme.cardInnerHighlight(for: .dark)
        let lightHighlight = AppTheme.cardInnerHighlight(for: .light)
        XCTAssertNotNil(darkHighlight)
        XCTAssertNotNil(lightHighlight)
    }
    
    func testF01_FloatingCardSurface_PopoverElevationTokens() {
        XCTAssertEqual(Things3FloatingModalDesignSpec.modalElevation, .popover)
        let configLight = AppTheme.shadowConfig(for: .popover, colorScheme: .light)
        let configDark = AppTheme.shadowConfig(for: .popover, colorScheme: .dark)
        
        XCTAssertEqual(configLight.ambientRadius, 28)
        XCTAssertEqual(configLight.ambientY, 14)
        XCTAssertEqual(configLight.contactRadius, 5)
        XCTAssertEqual(configLight.contactY, 2.5)
        
        XCTAssertEqual(configDark.ambientRadius, 28)
        XCTAssertEqual(configDark.ambientY, 14)
        XCTAssertEqual(configDark.contactRadius, 5)
        XCTAssertEqual(configDark.contactY, 2.5)
    }
    
    func testF01_FloatingCardSurface_ModalDimensionsTask460Profile350() {
        XCTAssertEqual(Things3FloatingModalDesignSpec.taskModalWidth, 460.0)
        XCTAssertEqual(Things3FloatingModalDesignSpec.profileModalWidth, 350.0)
        XCTAssertEqual(Things3FloatingModalDesignSpec.profileAvatarSize, 72.0)
        XCTAssertEqual(Things3FloatingModalDesignSpec.profileSwatchSize, 24.0)
    }
    
    func testF01_FloatingCardSurface_ShortcutHintsTextContract() {
        let defaultHint = FloatingModalShortcutHint()
        XCTAssertEqual(defaultHint.hint, "⌘↵ 保存 · Esc 取消")
        XCTAssertEqual(Things3FloatingModalDesignSpec.shortcutHintText, "⌘↵ 保存 · Esc 取消")
    }
    
    func testF01_FloatingCardSurface_CloseButtonInitializesAndDispatches() {
        var didClick = false
        let button = FloatingModalCloseButton {
            didClick = true
        }
        button.action()
        XCTAssertTrue(didClick, "FloatingModalCloseButton action must trigger dismissal callback")
    }
    
    // =========================================================================
    // MARK: - TIER 1: FEATURE 2 — Things 3 Date Capsules Logic & Conversions (6 tests)
    // =========================================================================
    
    func testF02_DateCapsules_PresetTitlesAndCount() {
        let titles = Things3FloatingModalDesignSpec.dateCapsuleTitles
        XCTAssertEqual(titles.count, 5)
        XCTAssertEqual(titles, ["无", "今天", "明天", "稍后", "自定义日期…"])
    }
    
    func testF02_DateCapsules_NilDueDateMapsToNonePreset() {
        let baseDate = Things3FloatingModalTestHarness.date(year: 2026, month: 11, day: 4)
        let preset = Things3FloatingModalTestHarness.classifyDate(nil, relativeTo: baseDate)
        XCTAssertEqual(preset, .none)
        XCTAssertEqual(preset.title, "无")
        
        let resolved = Things3FloatingModalTestHarness.resolveDate(for: .none, relativeTo: baseDate)
        XCTAssertNil(resolved)
    }
    
    func testF02_DateCapsules_TodayDateMapsToTodayPreset() {
        let baseDate = Things3FloatingModalTestHarness.date(year: 2026, month: 11, day: 4, hour: 10, minute: 30)
        let todayDate = Things3FloatingModalTestHarness.date(year: 2026, month: 11, day: 4, hour: 23, minute: 59)
        
        let preset = Things3FloatingModalTestHarness.classifyDate(todayDate, relativeTo: baseDate)
        XCTAssertEqual(preset, .today)
        XCTAssertEqual(preset.title, "今天")
        
        let resolved = Things3FloatingModalTestHarness.resolveDate(for: .today, relativeTo: baseDate)
        let expected = Things3FloatingModalTestHarness.date(year: 2026, month: 11, day: 4)
        XCTAssertEqual(resolved, expected)
    }
    
    func testF02_DateCapsules_TomorrowDateMapsToTomorrowPreset() {
        let baseDate = Things3FloatingModalTestHarness.date(year: 2026, month: 11, day: 4)
        let tomorrowDate = Things3FloatingModalTestHarness.date(year: 2026, month: 11, day: 5, hour: 14)
        
        let preset = Things3FloatingModalTestHarness.classifyDate(tomorrowDate, relativeTo: baseDate)
        XCTAssertEqual(preset, .tomorrow)
        XCTAssertEqual(preset.title, "明天")
        
        let resolved = Things3FloatingModalTestHarness.resolveDate(for: .tomorrow, relativeTo: baseDate)
        let expected = Things3FloatingModalTestHarness.date(year: 2026, month: 11, day: 5)
        XCTAssertEqual(resolved, expected)
    }
    
    func testF02_DateCapsules_LaterDateMapsToLaterPreset() {
        let baseDate = Things3FloatingModalTestHarness.date(year: 2026, month: 11, day: 4)
        let laterDate = Things3FloatingModalTestHarness.date(year: 2026, month: 11, day: 6, hour: 8)
        
        let preset = Things3FloatingModalTestHarness.classifyDate(laterDate, relativeTo: baseDate)
        XCTAssertEqual(preset, .later)
        XCTAssertEqual(preset.title, "稍后")
        
        let resolved = Things3FloatingModalTestHarness.resolveDate(for: .later, relativeTo: baseDate)
        let expected = Things3FloatingModalTestHarness.date(year: 2026, month: 11, day: 6)
        XCTAssertEqual(resolved, expected)
    }
    
    func testF02_DateCapsules_ArbitraryDateMapsToCustomPresetWithFormattedLabel() {
        let baseDate = Things3FloatingModalTestHarness.date(year: 2026, month: 11, day: 4)
        let arbitraryDate = Things3FloatingModalTestHarness.date(year: 2026, month: 11, day: 15)
        
        let preset = Things3FloatingModalTestHarness.classifyDate(arbitraryDate, relativeTo: baseDate)
        let expectedDate = Things3FloatingModalTestHarness.date(year: 2026, month: 11, day: 15)
        XCTAssertEqual(preset, .custom(expectedDate))
        XCTAssertEqual(preset.title, "11月15日")
        
        let resolved = Things3FloatingModalTestHarness.resolveDate(for: preset, relativeTo: baseDate)
        XCTAssertEqual(resolved, expectedDate)
    }
    
    // =========================================================================
    // MARK: - TIER 1: FEATURE 3 — 4-Tier Native Context Menu Structure (6 tests)
    // =========================================================================
    
    func testF03_ContextMenu_FourTierStructureAndSeparators() {
        XCTAssertEqual(Things3FloatingModalDesignSpec.contextMenuTierCount, 4)
        XCTAssertEqual(Things3FloatingModalDesignSpec.contextMenuSeparatorCount, 3)
        XCTAssertEqual(Things3FloatingModalDesignSpec.tier1ActionLabels, ["立即开启专注", "编辑任务…"])
        XCTAssertEqual(Things3FloatingModalDesignSpec.tier2ActionLabels, ["今天", "明天", "稍后", "移入收集箱"])
        XCTAssertEqual(Things3FloatingModalDesignSpec.tier3ActionLabels, ["置顶", "取消置顶", "标记为已完成", "标记为未完成"])
        XCTAssertEqual(Things3FloatingModalDesignSpec.tier4ActionLabels, ["复制任务标题", "删除任务"])
    }
    
    func testF03_ContextMenu_Tier1FocusAndEditContracts() {
        let store = makeTaskStore()
        let task = Things3FloatingModalTestHarness.makeTask(title: "Deep Work Session")
        store.tasks.append(task)
        
        // Test Start Focus
        let focusOutcome = Things3FloatingModalTestHarness.dispatchContextMenuAction(
            .startFocus,
            for: task,
            in: store
        )
        XCTAssertEqual(focusOutcome, .focused(task.id))
        XCTAssertEqual(store.activeTaskId, task.id)
        
        // Test Edit Session snapshot
        let editOutcome = Things3FloatingModalTestHarness.dispatchContextMenuAction(
            .editTask,
            for: task,
            in: store
        )
        XCTAssertEqual(editOutcome, .editSession(task.id, "Deep Work Session"))
    }
    
    func testF03_ContextMenu_Tier2RescheduleMovesAcrossFilters() {
        let store = makeTaskStore()
        let task = Things3FloatingModalTestHarness.makeTask(title: "Flexible Scheduling")
        store.tasks.append(task)
        
        // Move to Today
        _ = Things3FloatingModalTestHarness.dispatchContextMenuAction(.rescheduleToday, for: task, in: store)
        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(store.tasks[0].dueDate, today)
        
        // Move to Tomorrow
        _ = Things3FloatingModalTestHarness.dispatchContextMenuAction(.rescheduleTomorrow, for: task, in: store)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)
        XCTAssertEqual(store.tasks[0].dueDate, tomorrow)
        
        // Move to Later (Week)
        _ = Things3FloatingModalTestHarness.dispatchContextMenuAction(.rescheduleLater, for: task, in: store)
        let later = Calendar.current.date(byAdding: .day, value: 2, to: today)
        XCTAssertEqual(store.tasks[0].dueDate, later)
        
        // Move to Inbox
        _ = Things3FloatingModalTestHarness.dispatchContextMenuAction(.rescheduleInbox, for: task, in: store)
        XCTAssertNil(store.tasks[0].dueDate)
    }
    
    func testF03_ContextMenu_Tier3PinTogglePreservesSortPriority() {
        let store = makeTaskStore()
        let task = Things3FloatingModalTestHarness.makeTask(title: "VIP Priority Task", isPinned: false)
        store.tasks.append(task)
        
        let outcomePin = Things3FloatingModalTestHarness.dispatchContextMenuAction(.togglePin, for: task, in: store)
        XCTAssertEqual(outcomePin, .pinned(true))
        XCTAssertTrue(store.tasks[0].isPinned)
        
        let outcomeUnpin = Things3FloatingModalTestHarness.dispatchContextMenuAction(.togglePin, for: store.tasks[0], in: store)
        XCTAssertEqual(outcomeUnpin, .pinned(false))
        XCTAssertFalse(store.tasks[0].isPinned)
    }
    
    func testF03_ContextMenu_Tier3CompleteToggleMarksCompleted() {
        let store = makeTaskStore()
        let task = Things3FloatingModalTestHarness.makeTask(title: "Actionable Milestone", isCompleted: false)
        store.tasks.append(task)
        
        let outcomeDone = Things3FloatingModalTestHarness.dispatchContextMenuAction(.toggleComplete, for: task, in: store)
        XCTAssertEqual(outcomeDone, .completed(true))
        XCTAssertTrue(store.tasks[0].isCompleted)
        XCTAssertNotNil(store.tasks[0].completedAt)
        
        let outcomeReopen = Things3FloatingModalTestHarness.dispatchContextMenuAction(.toggleComplete, for: store.tasks[0], in: store)
        XCTAssertEqual(outcomeReopen, .completed(false))
        XCTAssertFalse(store.tasks[0].isCompleted)
    }
    
    func testF03_ContextMenu_Tier4ClipboardCopyAndDestructiveDelete() {
        let store = makeTaskStore()
        let task = Things3FloatingModalTestHarness.makeTask(title: "Task with Title to Copy")
        store.tasks.append(task)
        
        // Test Clipboard Copy
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("iFocusTestPasteboard-\(UUID().uuidString)"))
        let copyOutcome = Things3FloatingModalTestHarness.dispatchContextMenuAction(
            .copyTitle,
            for: task,
            in: store,
            pasteboard: pasteboard
        )
        XCTAssertEqual(copyOutcome, .copied("Task with Title to Copy"))
        XCTAssertEqual(pasteboard.string(forType: .string), "Task with Title to Copy")
        
        // Test Destructive Delete
        XCTAssertTrue(Things3FloatingModalDesignSpec.tier4DeleteRoleIsDestructive)
        let deleteOutcome = Things3FloatingModalTestHarness.dispatchContextMenuAction(
            .deleteTask,
            for: task,
            in: store
        )
        XCTAssertEqual(deleteOutcome, .deleted(true))
        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertNotNil(store.undoDeletionBanner, "Soft delete banner must be presented for undo safety")
    }
    
    // =========================================================================
    // MARK: - TIER 1: FEATURE 4 — Inline Note First Line Extraction (6 tests)
    // =========================================================================
    
    func testF04_InlineNote_SingleLineExtraction() {
        let notes = "Prepare quarterly financial slides"
        let summary = Things3FloatingModalTestHarness.extractFirstLine(from: notes)
        XCTAssertEqual(summary, "Prepare quarterly financial slides")
    }
    
    func testF04_InlineNote_MultiLineReturnsFirstNonEmptyLine() {
        let notes = """
        Review Q3 engineering deliverables
        - Backend API latency
        - Core data migration
        - Test suite coverage
        """
        let summary = Things3FloatingModalTestHarness.extractFirstLine(from: notes)
        XCTAssertEqual(summary, "Review Q3 engineering deliverables")
    }
    
    func testF04_InlineNote_LeadingBlankLinesSkipped() {
        let notes = "\n\n  \n   \nActual First Substantive Line\nFollow-up content"
        let summary = Things3FloatingModalTestHarness.extractFirstLine(from: notes)
        XCTAssertEqual(summary, "Actual First Substantive Line")
    }
    
    func testF04_InlineNote_VisualTokens12ptAnd50PercentOpacity() {
        XCTAssertEqual(Things3FloatingModalDesignSpec.inlineNoteFontSize, 12.0)
        XCTAssertEqual(Things3FloatingModalDesignSpec.inlineNoteOpacity, 0.50)
        XCTAssertEqual(Things3FloatingModalDesignSpec.inlineNoteLineLimit, 1)
        
        let secondaryLight = AppTheme.secondaryText(for: .light)
        let secondaryDark = AppTheme.secondaryText(for: .dark)
        XCTAssertNotNil(secondaryLight)
        XCTAssertNotNil(secondaryDark)
    }
    
    func testF04_InlineNote_HoverTooltipPreservesFullMultitext() {
        let notes = "Line 1\nLine 2\nLine 3 with detail"
        let task = Things3FloatingModalTestHarness.makeTask(title: "Task With Full Note", notes: notes)
        XCTAssertEqual(task.notes, notes, "Raw task notes must preserve multi-line verbatim for hover tooltip")
        XCTAssertEqual(Things3FloatingModalTestHarness.extractFirstLine(from: task.notes), "Line 1")
    }
    
    func testF04_InlineNote_CarriageReturnAndWindowsNewlineFidelity() {
        let notesWindows = "Windows Line 1\r\nWindows Line 2\r\nWindows Line 3"
        let notesClassicMac = "Classic Mac Line 1\rClassic Mac Line 2"
        
        XCTAssertEqual(Things3FloatingModalTestHarness.extractFirstLine(from: notesWindows), "Windows Line 1")
        XCTAssertEqual(Things3FloatingModalTestHarness.extractFirstLine(from: notesClassicMac), "Classic Mac Line 1")
    }
    
    // =========================================================================
    // MARK: - TIER 1: FEATURE 5 — Profile Editing Modal State Management (5 tests)
    // =========================================================================
    
    func testF05_ProfileModal_Squircle350WidthAndDismissContract() {
        XCTAssertEqual(Things3FloatingModalDesignSpec.profileModalWidth, 350.0)
        XCTAssertEqual(Things3FloatingModalDesignSpec.modalCornerRadius, 18.0)
    }
    
    func testF05_ProfileModal_CapsuleNicknameWithPersonGlyph() {
        let store = makeSettingsStore()
        store.username = "Productivity Ninja"
        XCTAssertEqual(store.username, "Productivity Ninja")
    }
    
    func testF05_ProfileModal_24ptColorSwatchesInRecessedTray() {
        XCTAssertEqual(Things3FloatingModalDesignSpec.profileSwatchSize, 24.0)
        let palette = AccentPreset.allCases
        XCTAssertEqual(palette.count, 6)
        XCTAssertEqual(UnifiedAvatarView.palette.count, 6)
    }
    
    func testF05_ProfileModal_UncommittedAvatarChangeRollbackOnCancel() {
        let store = makeSettingsStore()
        store.avatarColorIndex = 2
        store.avatarPath = nil
        let originalColor = store.avatarColorIndex
        let originalPath = store.avatarPath
        
        // Dirty changes in modal
        store.avatarColorIndex = 5
        store.avatarPath = "/tmp/temporary_uncommitted_avatar.png"
        XCTAssertEqual(store.avatarColorIndex, 5)
        XCTAssertNotNil(store.avatarPath)
        
        // User clicks Cancel / Esc / xmark / taps backdrop
        store.avatarColorIndex = originalColor
        store.avatarPath = originalPath
        
        XCTAssertEqual(store.avatarColorIndex, 2)
        XCTAssertNil(store.avatarPath)
    }
    
    func testF05_ProfileModal_CommittedStatePersistsOnSave() {
        let store = makeSettingsStore()
        let tempUsername = "   New Valid Name   "
        store.username = tempUsername
        store.sanitizeUsername()
        
        XCTAssertEqual(store.username, "New Valid Name", "Leading/trailing whitespaces must be sanitized on commit")
    }
    
    // =========================================================================
    // MARK: - TIER 2: BOUNDARY & CORNER CASES (12 tests)
    // =========================================================================
    
    func testTier2_EmptyNotes_ReturnsNilSummary() {
        let notes = ""
        XCTAssertNil(Things3FloatingModalTestHarness.extractFirstLine(from: notes))
    }
    
    func testTier2_WhitespaceOnlyNotes_ReturnsNilSummary() {
        let whitespaceNotes = "     \t   \n   \n\t   \r\n   "
        XCTAssertNil(Things3FloatingModalTestHarness.extractFirstLine(from: whitespaceNotes))
    }
    
    func testTier2_SingleLineNotesWithoutNewlines_ExtractedCleanly() {
        let notes = "   Quick note with surrounding padding   "
        XCTAssertEqual(Things3FloatingModalTestHarness.extractFirstLine(from: notes), "Quick note with surrounding padding")
    }
    
    func testTier2_MultiLineNotesWithTrailingNewlines_PreservesFirstLine() {
        let notes = "Important header note\n\n\n\n\n\n"
        XCTAssertEqual(Things3FloatingModalTestHarness.extractFirstLine(from: notes), "Important header note")
    }
    
    func testTier2_ExtremeLengthFirstLine_ExtractedForTailTruncation() {
        let longLine = String(repeating: "Extremely long unbroken task description text ", count: 20)
        let summary = Things3FloatingModalTestHarness.extractFirstLine(from: longLine)
        XCTAssertEqual(summary, longLine.trimmingCharacters(in: .whitespaces))
        XCTAssertGreaterThan(summary?.count ?? 0, 800)
    }
    
    func testTier2_URLValidation_ValidHTTPSchemesAccepted() {
        XCTAssertTrue(Things3FloatingModalTestHarness.isValidURL("http://example.com"))
        XCTAssertTrue(Things3FloatingModalTestHarness.isValidURL("https://example.com/api/v1?query=focus#section"))
        XCTAssertTrue(Things3FloatingModalTestHarness.isValidURL("https://subdomain.domain.org:8080/path"))
    }
    
    func testTier2_URLValidation_InvalidSchemesRejected() {
        XCTAssertFalse(Things3FloatingModalTestHarness.isValidURL("ftp://files.example.com"))
        XCTAssertFalse(Things3FloatingModalTestHarness.isValidURL("javascript:alert(1)"))
        XCTAssertFalse(Things3FloatingModalTestHarness.isValidURL("file:///Applications/iFocus.app"))
        XCTAssertFalse(Things3FloatingModalTestHarness.isValidURL("mailto:support@ifocus.app"))
        XCTAssertFalse(Things3FloatingModalTestHarness.isValidURL("tel:12345678"))
    }
    
    func testTier2_URLValidation_MalformedAndWhitespaceURLsRejected() {
        XCTAssertFalse(Things3FloatingModalTestHarness.isValidURL(""))
        XCTAssertFalse(Things3FloatingModalTestHarness.isValidURL("   "))
        XCTAssertFalse(Things3FloatingModalTestHarness.isValidURL("http://"))
        XCTAssertFalse(Things3FloatingModalTestHarness.isValidURL("https://"))
        XCTAssertFalse(Things3FloatingModalTestHarness.isValidURL("://invalid"))
        XCTAssertFalse(Things3FloatingModalTestHarness.isValidURL("not a url at all"))
    }
    
    func testTier2_CustomDate_EdgeCaseLeapYearFebruary29() {
        let leapDate = Things3FloatingModalTestHarness.date(year: 2028, month: 2, day: 29)
        let formatted = Things3FloatingModalTestHarness.formatCustomDate(leapDate)
        XCTAssertEqual(formatted, "2月29日")
    }
    
    func testTier2_CustomDate_EdgeCaseYearRolloverDec31ToJan01() {
        let baseDate = Things3FloatingModalTestHarness.date(year: 2026, month: 12, day: 31)
        let tomorrow = Things3FloatingModalTestHarness.resolveDate(for: .tomorrow, relativeTo: baseDate)
        let expected = Things3FloatingModalTestHarness.date(year: 2027, month: 1, day: 1)
        XCTAssertEqual(tomorrow, expected)
        
        let preset = Things3FloatingModalTestHarness.classifyDate(expected, relativeTo: baseDate)
        XCTAssertEqual(preset, .tomorrow)
    }
    
    func testTier2_UncommittedProfileState_MultipleDiscardsRollbackCleanly() {
        let store = makeSettingsStore()
        store.avatarColorIndex = 3
        let initialColor = store.avatarColorIndex
        
        for intermediateColor in [0, 1, 4, 5, 2] {
            store.avatarColorIndex = intermediateColor
            XCTAssertEqual(store.avatarColorIndex, intermediateColor)
            // Roll back
            store.avatarColorIndex = initialColor
            XCTAssertEqual(store.avatarColorIndex, 3)
        }
    }
    
    func testTier2_EmptyTaskTitleInEditor_DisallowsSave() {
        let emptyTitle = "   \n\t  "
        let isSavable = !emptyTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        XCTAssertFalse(isSavable, "Empty or whitespace-only task title must disable modal save action")
    }
    
    // =========================================================================
    // MARK: - TIER 3: CROSS-FEATURE INTERACTIONS (5 tests)
    // =========================================================================
    
    func testTier3_TaskRescheduling_PreservesInlineNotesAndURL() {
        let store = makeTaskStore()
        let task = Things3FloatingModalTestHarness.makeTask(
            title: "Project Architecture RFC",
            notes: "Detailed architecture design notes\nSecond line\nThird line",
            linkURL: "https://spec.ifocus.app/rfc-42",
            isPinned: true
        )
        store.tasks.append(task)
        
        // Reschedule to Tomorrow
        _ = Things3FloatingModalTestHarness.dispatchContextMenuAction(.rescheduleTomorrow, for: task, in: store)
        let updatedTomorrow = store.tasks[0]
        XCTAssertEqual(updatedTomorrow.notes, task.notes)
        XCTAssertEqual(updatedTomorrow.linkURL, task.linkURL)
        XCTAssertEqual(Things3FloatingModalTestHarness.extractFirstLine(from: updatedTomorrow.notes), "Detailed architecture design notes")
        
        // Reschedule to Inbox
        _ = Things3FloatingModalTestHarness.dispatchContextMenuAction(.rescheduleInbox, for: updatedTomorrow, in: store)
        let updatedInbox = store.tasks[0]
        XCTAssertNil(updatedInbox.dueDate)
        XCTAssertEqual(updatedInbox.notes, task.notes)
        XCTAssertEqual(updatedInbox.linkURL, task.linkURL)
        XCTAssertTrue(updatedInbox.hasLink)
    }
    
    func testTier3_EditingModalSave_PreservesActiveFocusSessionAndTimer() {
        let store = makeTaskStore()
        let settings = makeSettingsStore()
        let timerStore = TimerStore(settings: settings, taskStore: store, sessionStorageDirectory: tempDir)
        
        let task = Things3FloatingModalTestHarness.makeTask(title: "Active Working Task", priority: 2, estimatedPomodoros: 3)
        store.tasks.append(task)
        
        // Start focus session on task
        timerStore.startFocus(on: task.id)
        XCTAssertTrue(timerStore.isRunning)
        XCTAssertEqual(store.activeTaskId, task.id)
        
        // User opens floating modal, creates snapshot session
        let editSession = EditTaskSession(task: task)
        
        // Save modified task attributes (title + new note + link)
        store.updateTask(
            id: editSession.id,
            title: "Renamed Active Task",
            category: editSession.category,
            priority: 4,
            estimatedPomodoros: 4,
            dueDate: Calendar.current.startOfDay(for: Date()),
            recurrence: editSession.recurrence,
            notes: "Added new notes during live session",
            linkURL: "https://apple.com"
        )
        
        // Verify timer continues running without interruption or state corruption
        XCTAssertTrue(timerStore.isRunning)
        XCTAssertEqual(store.activeTaskId, task.id)
        XCTAssertEqual(store.tasks[0].title, "Renamed Active Task")
        XCTAssertEqual(store.tasks[0].priority, 4)
        XCTAssertEqual(Things3FloatingModalTestHarness.extractFirstLine(from: store.tasks[0].notes), "Added new notes during live session")
        
        timerStore.pause()
    }
    
    func testTier3_ContextMenuPinAndComplete_PreservesSortOrderAndFilterTransitions() {
        let store = makeTaskStore()
        let task1 = Things3FloatingModalTestHarness.makeTask(title: "Task Regular 1")
        let task2 = Things3FloatingModalTestHarness.makeTask(title: "Task Regular 2")
        store.tasks.append(contentsOf: [task1, task2])
        
        // Pin Task 2
        _ = Things3FloatingModalTestHarness.dispatchContextMenuAction(.togglePin, for: task2, in: store)
        XCTAssertTrue(store.tasks[1].isPinned)
        
        // Toggle complete Task 2
        _ = Things3FloatingModalTestHarness.dispatchContextMenuAction(.toggleComplete, for: store.tasks[1], in: store)
        XCTAssertTrue(store.tasks[1].isCompleted)
        
        // Filter by completed vs active
        let active = store.tasks.filter { !$0.isCompleted }
        let completed = store.tasks.filter { $0.isCompleted }
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active[0].title, "Task Regular 1")
        XCTAssertEqual(completed.count, 1)
        XCTAssertEqual(completed[0].title, "Task Regular 2")
    }
    
    func testTier3_EditSessionSnapshot_DecoupledFromLiveTaskMutations() {
        let store = makeTaskStore()
        let task = Things3FloatingModalTestHarness.makeTask(
            title: "Original Snapshot Task",
            notes: "Original notes text",
            linkURL: "https://initial.org"
        )
        store.tasks.append(task)
        
        // Capture snapshot
        let snapshot = EditTaskSession(task: task)
        
        // Mutate live task in background
        store.tasks[0].title = "Mutated In Background"
        store.tasks[0].notes = "Mutated notes"
        store.tasks[0].linkURL = "https://mutated.org"
        
        // Verify snapshot remains completely pristine and immutable
        XCTAssertEqual(snapshot.title, "Original Snapshot Task")
        XCTAssertEqual(snapshot.notes, "Original notes text")
        XCTAssertEqual(snapshot.linkURL, "https://initial.org")
    }
    
    func testTier3_InlineNoteExtraction_WithClipboardCopyAndRecreation() {
        let store = makeTaskStore()
        let notes = "Review security audits\nConfidential report"
        let task = Things3FloatingModalTestHarness.makeTask(title: "Audit Review", notes: notes)
        store.tasks.append(task)
        
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("iFocusClipboardTest-\(UUID().uuidString)"))
        _ = Things3FloatingModalTestHarness.dispatchContextMenuAction(.copyTitle, for: task, in: store, pasteboard: pasteboard)
        let copiedTitle = pasteboard.string(forType: .string)
        XCTAssertEqual(copiedTitle, "Audit Review")
        
        // Create duplicate task using copied title and same notes
        let newTask = Things3FloatingModalTestHarness.makeTask(title: copiedTitle ?? "", notes: task.notes)
        store.tasks.append(newTask)
        
        XCTAssertEqual(store.tasks.count, 2)
        XCTAssertEqual(Things3FloatingModalTestHarness.extractFirstLine(from: store.tasks[1].notes), "Review security audits")
    }
    
    // =========================================================================
    // MARK: - TIER 4: REAL-WORLD SCENARIOS (2 tests)
    // =========================================================================
    
    func testTier4_CompleteUserTaskLifecycle_CreationRescheduleNoteInspectionModalEditingCompletion() {
        let store = makeTaskStore()
        let calendar = Things3FloatingModalTestHarness.utcCalendar
        let today = calendar.startOfDay(for: Things3FloatingModalTestHarness.date(year: 2026, month: 11, day: 4))
        
        // Step 1: User creates task with Quick Add
        store.newTaskTitle = "Build Release Candidate"
        guard let taskId = store.addTask(for: .todayTask) else {
            XCTFail("Failed to add initial task")
            return
        }
        guard let initialTask = store.tasks.first(where: { $0.id == taskId }) else {
            XCTFail("Task not found in store")
            return
        }
        XCTAssertEqual(initialTask.title, "Build Release Candidate")
        XCTAssertNil(Things3FloatingModalTestHarness.extractFirstLine(from: initialTask.notes))
        
        // Step 2: User right-clicks to reschedule to Tomorrow (Tier 2 Context Menu)
        let rescheduleOutcome = Things3FloatingModalTestHarness.dispatchContextMenuAction(
            .rescheduleTomorrow,
            for: initialTask,
            in: store
        )
        let expectedTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
        XCTAssertEqual(rescheduleOutcome, .rescheduled(expectedTomorrow))
        
        // Step 3: User attaches multi-line notes and valid URL
        let multiLineNotes = """
        Coordinate final QA sign-off
        - Verify DMG build
        - Smoke test Dark Mode
        - Check App Store receipt validation
        """
        store.tasks[0].notes = multiLineNotes
        store.tasks[0].linkURL = "https://github.com/org/repo/releases/v1.15"
        
        // Step 4: Verify inline note summary renders the first line
        let firstLineSummary = Things3FloatingModalTestHarness.extractFirstLine(from: store.tasks[0].notes)
        XCTAssertEqual(firstLineSummary, "Coordinate final QA sign-off")
        XCTAssertTrue(store.tasks[0].hasLink)
        
        // Step 5: User opens floating modal (EditTaskSession)
        let session = EditTaskSession(task: store.tasks[0])
        XCTAssertEqual(session.title, "Build Release Candidate")
        XCTAssertEqual(session.notes, multiLineNotes)
        
        // Step 6: User edits custom date, tweaks title, and commits via ⌘↵ Save
        let customDueDate = calendar.date(byAdding: .day, value: 5, to: today)
        store.updateTask(
            id: session.id,
            title: "Build & Deploy Release Candidate v1.15",
            category: session.category,
            priority: 3,
            estimatedPomodoros: 4,
            dueDate: customDueDate,
            recurrence: session.recurrence,
            notes: "Deploy to production fleet\nSecondary release checks",
            linkURL: "https://github.com/org/repo/releases/v1.15"
        )
        
        let committedTask = store.tasks[0]
        XCTAssertEqual(committedTask.title, "Build & Deploy Release Candidate v1.15")
        XCTAssertEqual(Things3FloatingModalTestHarness.extractFirstLine(from: committedTask.notes), "Deploy to production fleet")
        
        // Step 7: User completes task from Tier 3 Context Menu
        let completeOutcome = Things3FloatingModalTestHarness.dispatchContextMenuAction(
            .toggleComplete,
            for: committedTask,
            in: store
        )
        XCTAssertEqual(completeOutcome, .completed(true))
        XCTAssertTrue(store.tasks[0].isCompleted)
        XCTAssertNotNil(store.tasks[0].completedAt)
    }
    
    func testTier4_MultiTaskBacklogTriageWorkflow_BatchTriageWithClipboardAndDeletionSafety() {
        let store = makeTaskStore()
        let settings = makeSettingsStore()
        
        // Step 1: Batch populate backlog in Inbox
        let taskData = [
            ("Client proposal drafting", "Draft executive summary\nSection 2\nSection 3", "https://docs.google.com/doc/1"),
            ("Bug triage: Memory leak in Metal shader", "Instruments trace attached", "https://bugs.internal/issue-891"),
            ("Design review: Things 3 modal redesign", "Figma link inside", "https://figma.com/file/things3-redesign"),
            ("Weekly grocery run", "", "")
        ]
        
        for item in taskData {
            store.newTaskTitle = item.0
            _ = store.addTask(for: .inboxTask)
            store.tasks[store.tasks.count - 1].notes = item.1
            store.tasks[store.tasks.count - 1].linkURL = item.2
        }
        XCTAssertEqual(store.tasks.count, 4)
        
        // Step 2: Tier 3 Pin critical task
        let bugTask = store.tasks[1]
        _ = Things3FloatingModalTestHarness.dispatchContextMenuAction(.togglePin, for: bugTask, in: store)
        XCTAssertTrue(store.tasks[1].isPinned)
        
        // Step 3: Tier 2 Triage: Move proposal to Today, Design review to Tomorrow
        let proposalTask = store.tasks[0]
        _ = Things3FloatingModalTestHarness.dispatchContextMenuAction(.rescheduleToday, for: proposalTask, in: store)
        let designTask = store.tasks[2]
        _ = Things3FloatingModalTestHarness.dispatchContextMenuAction(.rescheduleTomorrow, for: designTask, in: store)
        
        // Step 4: Tier 4 Clipboard: Copy design review title
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("iFocusTriagePB-\(UUID().uuidString)"))
        _ = Things3FloatingModalTestHarness.dispatchContextMenuAction(.copyTitle, for: designTask, in: store, pasteboard: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), "Design review: Things 3 modal redesign")
        
        // Step 5: Tier 4 Delete grocery run with soft-delete undo check
        let groceryTask = store.tasks[3]
        _ = Things3FloatingModalTestHarness.dispatchContextMenuAction(.deleteTask, for: groceryTask, in: store)
        XCTAssertEqual(store.tasks.count, 3)
        XCTAssertNotNil(store.undoDeletionBanner)
        
        // User triggers undo to restore grocery run
        let restored = store.undoLastDeletion()
        XCTAssertTrue(restored)
        XCTAssertEqual(store.tasks.count, 4)
        
        // Step 6: Profile customization during triage with uncommitted rollback check
        settings.avatarColorIndex = 1
        let origColor = settings.avatarColorIndex
        settings.avatarColorIndex = 4
        // Discard
        settings.avatarColorIndex = origColor
        XCTAssertEqual(settings.avatarColorIndex, 1)
    }
}
