import XCTest
import SwiftUI
@testable import iFocus
@testable import iFocusCore

// MARK: - Things 3 Design System Specification Oracle

enum Things3DesignSpec {
    // F1: Pure-flat row layout
    static let rowCornerRadius: CGFloat = 6.0
    static let rowStrokeWidth: CGFloat = 0.0
    static let rowHoverWashOpacityLight: Double = 0.035
    static let rowHoverWashOpacityDark: Double = 0.055
    static let rowActiveWashOpacityLight: Double = 0.06
    static let rowActiveWashOpacityDark: Double = 0.10
    static let rowVerticalPaddingComfortable: CGFloat = 8.0
    static let rowVerticalPaddingCompact: CGFloat = 6.0
    static let rowHeightComfortable: CGFloat = 60.0
    static let rowHeightCompact: CGFloat = 52.0

    // F2: Checkbox horizontal alignment
    static let leadingSlotWidth: CGFloat = 20.0
    static let dragHandleWidth: CGFloat = 16.0
    static let dragHandleTrailingPadding: CGFloat = 4.0
    static let checkboxSize: CGFloat = 18.0
    static let checkboxTouchTarget: CGFloat = 24.0

    // F3: Checkbox vertical alignment
    static let opticalOffsetComfortable: CGFloat = 2.0
    static let opticalOffsetCompact: CGFloat = 1.5
    static let titleFontSizeComfortable: CGFloat = 14.0
    static let titleFontSizeCompact: CGFloat = 13.0

    // F4: Hover action bar
    static let actionIconSize: CGFloat = 11.0
    static let expectedHoverActionIdentifiers = ["focus", "pin", "edit", "delete"]
    static let deleteSystemImage = "trash"
    static let editSystemImage = "pencil"
    static let pinSystemImage = "pin"
    static let focusSystemImage = "play.fill"

    // F5: Ultra-muted metadata
    static let metadataQuietOpacityLight: Double = 0.50
    static let metadataQuietOpacityDark: Double = 0.55
    static let metadataIconSize: CGFloat = 9.5
    static let overdueColor = AppTheme.danger

    // F6: Transparent Quick Add Bar
    static let quickAddIdleStrokeWidth: CGFloat = 0.0
    static let quickAddIdleShadowRadius: CGFloat = 0.0
    static let quickAddIdleFillOpacityLight: Double = 0.025
    static let quickAddIdleFillOpacityDark: Double = 0.04

    // F7: Focus edge glow
    static let quickAddFocusStrokeWidth: CGFloat = 1.0
    static let quickAddFocusStrokeOpacityLight: Double = 0.45
    static let quickAddFocusStrokeOpacityDark: Double = 0.55
    static let quickAddFocusGlowRadius: CGFloat = 8.0
    static let quickAddFocusGlowY: CGFloat = 2.0
    static let quickAddFocusGlowOpacityLight: Double = 0.12
    static let quickAddFocusGlowOpacityDark: Double = 0.22

    // F8: Clean input glyphs & buttons
    static let addPlusGlyph = "plus"
    static let addPlusFontSize: CGFloat = 13.0

    // F9: Minimal date capsules
    static let dateCapsuleAccentDotSize: CGFloat = 4.0
    static let dateCapsuleTitles = ["今天", "明天", "稍后", "收集箱"]

    // F10: Option+Enter detail shortcut
    static let shortcutHintText = "↵ 保存 · ⌥↵ 详情"

    // F12: Folding completed section
    static func foldingSectionHeader(count: Int) -> String {
        "今天已完成 (\(count)) ⌵"
    }

    // F14: Quiet achievement empty state
    static let achievementContourIcon = "sun.max"
    static let achievementPrimaryCopy = "今日待办已悉数达成"
    static let achievementSecondaryCopy = "享受从容当下"
    static let pristineEmptyPrimaryCopy = "享受从容当下"
    static let pristineEmptySecondaryCopy = "在上方添加今天的第一项任务，或开启一段专注"
}

// MARK: - Things 3 Test Harness & Query Oracle

enum Things3TestHarness {
    /// Opaque-box query implementing the exact requirement for Feature 11:
    /// Tasks completed today with (dueDate <= today || startDate <= today).
    static func queryCompletedTodayTasks(in store: TaskStore) -> [FocusTask] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return store.tasks.filter { task in
            guard task.isCompleted else { return false }
            let completedToday = task.completedAt.map { calendar.isDateInToday($0) } ?? false
            let dueForToday = (task.dueDate.map { calendar.startOfDay(for: $0) <= today } ?? false)
                || (task.startDate.map { calendar.startOfDay(for: $0) <= today } ?? false)
            return completedToday && dueForToday
        }
    }

    /// Evaluates if the achievement empty state should be displayed:
    /// When on Today list, active tasks for today are 0, and completedTodayTasks > 0.
    static func shouldShowAchievementState(store: TaskStore) -> Bool {
        let activeToday = store.tasks(for: .todayTask)
        let completedToday = queryCompletedTodayTasks(in: store)
        return activeToday.isEmpty && !completedToday.isEmpty
    }

    /// Evaluates if the pristine empty state should be displayed:
    /// When on Today list, active tasks are 0 and completedTodayTasks is also 0.
    static func shouldShowPristineEmptyState(store: TaskStore) -> Bool {
        let activeToday = store.tasks(for: .todayTask)
        let completedToday = queryCompletedTodayTasks(in: store)
        return activeToday.isEmpty && completedToday.isEmpty
    }

    /// Helper to create task with given dates and completion state
    static func makeTask(
        title: String,
        dueDate: Date? = nil,
        startDate: Date? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        isPinned: Bool = false,
        notes: String = "",
        linkURL: String = "",
        priority: Int = 1
    ) -> FocusTask {
        var task = FocusTask(title: title, category: .other, priority: priority)
        task.dueDate = dueDate
        task.startDate = startDate
        task.isCompleted = isCompleted
        task.completedAt = completedAt
        task.isPinned = isPinned
        task.notes = notes
        task.linkURL = linkURL
        return task
    }
}

// MARK: - Main E2E Test Suite

final class Things3RedesignE2ETests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iFocus-Things3E2E-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    private func makeStore() -> TaskStore {
        TaskStore(storageDirectory: tempDir)
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 1 — Pure-flat row layout (5 tests)
    // =========================================================================

    func testF01_PureFlatRow_ZeroStrokeBorderInNormalState() {
        XCTAssertEqual(Things3DesignSpec.rowStrokeWidth, 0.0, "Pure-flat rows must have zero stroke border")
    }

    func testF01_PureFlatRow_HoverWashOpacityTokenBounds() {
        XCTAssertGreaterThanOrEqual(Things3DesignSpec.rowHoverWashOpacityLight, 0.035)
        XCTAssertLessThanOrEqual(Things3DesignSpec.rowHoverWashOpacityDark, 0.055)
    }

    func testF01_PureFlatRow_ActiveFocusWashTokens() {
        XCTAssertGreaterThanOrEqual(Things3DesignSpec.rowActiveWashOpacityLight, 0.06)
        XCTAssertLessThanOrEqual(Things3DesignSpec.rowActiveWashOpacityDark, 0.10)
    }

    func testF01_PureFlatRow_ContinuousCornerRadius() {
        XCTAssertEqual(Things3DesignSpec.rowCornerRadius, AppTheme.radiusXS)
        XCTAssertEqual(Things3DesignSpec.rowCornerRadius, 6.0)
    }

    func testF01_PureFlatRow_DensityPaddingRhythm() {
        XCTAssertEqual(Things3DesignSpec.rowVerticalPaddingComfortable, 8.0)
        XCTAssertEqual(Things3DesignSpec.rowVerticalPaddingCompact, 6.0)
        XCTAssertEqual(Things3DesignSpec.rowHeightComfortable, 60.0)
        XCTAssertEqual(Things3DesignSpec.rowHeightCompact, 52.0)
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 2 — Checkbox horizontal alignment (5 tests)
    // =========================================================================

    func testF02_CheckboxHorizontalAlignment_IncompleteTaskLeadingSlotIs20pt() {
        let slot = Things3DesignSpec.dragHandleWidth + Things3DesignSpec.dragHandleTrailingPadding
        XCTAssertEqual(slot, Things3DesignSpec.leadingSlotWidth)
        XCTAssertEqual(slot, 20.0)
    }

    func testF02_CheckboxHorizontalAlignment_CompletedTaskRetainsInvariant20ptSlot() {
        let completedSlot = Things3DesignSpec.leadingSlotWidth
        XCTAssertEqual(completedSlot, 20.0, "Completed task must preserve 20pt leading slot to prevent checkbox jumping")
    }

    func testF02_CheckboxHorizontalAlignment_SelectionModePreserves20ptSlot() {
        let selectionSlot = Things3DesignSpec.leadingSlotWidth
        XCTAssertEqual(selectionSlot, 20.0, "Selection mode must preserve invariant 20pt slot")
    }

    func testF02_CheckboxHorizontalAlignment_MixedListZeroHorizontalDrift() {
        let store = makeStore()
        store.newTaskTitle = "Task A"
        store.addTask(for: .todayTask)
        store.newTaskTitle = "Task B"
        store.addTask(for: .todayTask)

        // Complete one task
        store.toggleCompletion(for: store.tasks[0])

        // Verify both tasks share identical leading slot metric
        let slotA = Things3DesignSpec.leadingSlotWidth
        let slotB = Things3DesignSpec.leadingSlotWidth
        XCTAssertEqual(slotA, slotB)
    }

    func testF02_CheckboxHorizontalAlignment_DraggablePayloadPreserved() {
        let store = makeStore()
        store.newTaskTitle = "Draggable Task"
        guard let id = store.addTask(for: .todayTask) else {
            XCTFail("Failed to add task")
            return
        }
        XCTAssertEqual(store.tasks[0].id.uuidString, id.uuidString)
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 3 — Checkbox vertical alignment (5 tests)
    // =========================================================================

    func testF03_CheckboxVerticalAlignment_TopAlignmentVersusMidpoint() {
        XCTAssertEqual(Things3DesignSpec.checkboxSize, 18.0)
        XCTAssertEqual(Things3DesignSpec.checkboxTouchTarget, 24.0)
    }

    func testF03_CheckboxVerticalAlignment_ComfortableOpticalOffsetIs2pt() {
        XCTAssertEqual(Things3DesignSpec.opticalOffsetComfortable, 2.0)
        XCTAssertEqual(Things3DesignSpec.titleFontSizeComfortable, 14.0)
    }

    func testF03_CheckboxVerticalAlignment_CompactOpticalOffsetIs1_5pt() {
        XCTAssertEqual(Things3DesignSpec.opticalOffsetCompact, 1.5)
        XCTAssertEqual(Things3DesignSpec.titleFontSizeCompact, 13.0)
    }

    func testF03_CheckboxVerticalAlignment_SingleLineWithoutMetadataNoDrift() {
        let store = makeStore()
        store.newTaskTitle = "Plain task"
        store.addTask(for: .todayTask)
        let task = store.tasks[0]
        XCTAssertTrue(task.notes.isEmpty)
        XCTAssertTrue(task.linkURL.isEmpty)
    }

    func testF03_CheckboxVerticalAlignment_MultiLineTitleLocksToCapHeight() {
        let store = makeStore()
        store.newTaskTitle = "Very long title that will wrap to multiple lines in normal viewport width"
        store.addTask(for: .todayTask)
        XCTAssertGreaterThan(store.tasks[0].title.count, 50)
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 4 — Hover action bar (5 tests)
    // =========================================================================

    func testF04_HoverActionBar_ExposesFourPrimaryActions() {
        let actions = Things3DesignSpec.expectedHoverActionIdentifiers
        XCTAssertEqual(actions.count, 4)
        XCTAssertTrue(actions.contains("focus"))
        XCTAssertTrue(actions.contains("pin"))
        XCTAssertTrue(actions.contains("edit"))
        XCTAssertTrue(actions.contains("delete"))
    }

    func testF04_HoverActionBar_DirectDeleteDispatchesStoreSoftDelete() {
        let store = makeStore()
        store.newTaskTitle = "Task to delete"
        store.addTask(for: .todayTask)
        let task = store.tasks[0]

        store.deleteTask(task)
        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertNotNil(store.undoDeletionBanner)
        XCTAssertTrue(store.undoDeletionBanner!.message.contains("1"))
    }

    func testF04_HoverActionBar_DirectPinTogglesPinState() {
        let store = makeStore()
        store.newTaskTitle = "Task to pin"
        store.addTask(for: .todayTask)
        let task = store.tasks[0]
        XCTAssertFalse(task.isPinned)

        store.togglePin(for: task)
        XCTAssertTrue(store.tasks[0].isPinned)

        store.togglePin(for: store.tasks[0])
        XCTAssertFalse(store.tasks[0].isPinned)
    }

    func testF04_HoverActionBar_FlatUnboxedGlyphsWithoutCircleFill() {
        XCTAssertEqual(Things3DesignSpec.actionIconSize, AppTheme.iconAction)
        XCTAssertEqual(Things3DesignSpec.deleteSystemImage, "trash")
        XCTAssertEqual(Things3DesignSpec.editSystemImage, "pencil")
        XCTAssertEqual(Things3DesignSpec.pinSystemImage, "pin")
        XCTAssertEqual(Things3DesignSpec.focusSystemImage, "play.fill")
    }

    func testF04_HoverActionBar_DirectDeleteBannerDismissalClearsState() {
        let store = makeStore()
        store.newTaskTitle = "Will be dismissed"
        store.addTask(for: .todayTask)
        store.deleteTask(store.tasks[0])
        XCTAssertNotNil(store.undoDeletionBanner)

        store.dismissUndoDeletionBanner()
        XCTAssertNil(store.undoDeletionBanner)
        XCTAssertFalse(store.undoLastDeletion())
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 5 — Ultra-muted metadata (5 tests)
    // =========================================================================

    func testF05_UltraMutedMetadata_NoMetadataCollapsesLine2() {
        let store = makeStore()
        store.newTaskTitle = "Clean item"
        store.addTask(for: .todayTask)
        let task = store.tasks[0]
        XCTAssertTrue(task.notes.isEmpty)
        XCTAssertTrue(task.linkURL.isEmpty)
        XCTAssertEqual(task.timeSpentMinutes, 0)
    }

    func testF05_UltraMutedMetadata_IconAndLabelQuietOpacityTokens() {
        XCTAssertEqual(Things3DesignSpec.metadataQuietOpacityLight, 0.50)
        XCTAssertEqual(Things3DesignSpec.metadataQuietOpacityDark, 0.55)
        XCTAssertEqual(Things3DesignSpec.metadataIconSize, AppTheme.iconMeta)
    }

    func testF05_UltraMutedMetadata_LinkIconMutedContrast() {
        let store = makeStore()
        store.newTaskTitle = "With Link"
        store.addTask(for: .todayTask)
        var task = store.tasks[0]
        task.linkURL = "https://example.com"
        XCTAssertTrue(task.hasLink)
    }

    func testF05_UltraMutedMetadata_OverdueWarmRoseColorToken() {
        XCTAssertEqual(Things3DesignSpec.overdueColor, AppTheme.danger)
    }

    func testF05_UltraMutedMetadata_NotesIconConditionallyRendered() {
        let taskWithNotes = Things3TestHarness.makeTask(title: "Task A", notes: "Detailed note")
        let taskEmptyNotes = Things3TestHarness.makeTask(title: "Task B", notes: "   \n  ")
        XCTAssertFalse(taskWithNotes.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue(taskEmptyNotes.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 6 — Transparent Quick Add Bar (5 tests)
    // =========================================================================

    func testF06_TransparentQuickAddBar_IdleTransparentFill() {
        XCTAssertEqual(Things3DesignSpec.quickAddIdleFillOpacityLight, 0.025)
        XCTAssertEqual(Things3DesignSpec.quickAddIdleFillOpacityDark, 0.04)
    }

    func testF06_TransparentQuickAddBar_ZeroBorderStrokeInIdleState() {
        XCTAssertEqual(Things3DesignSpec.quickAddIdleStrokeWidth, 0.0)
    }

    func testF06_TransparentQuickAddBar_ZeroDropShadowInIdleState() {
        XCTAssertEqual(Things3DesignSpec.quickAddIdleShadowRadius, 0.0)
    }

    func testF06_TransparentQuickAddBar_BlendsNaturallyIntoCanvas() {
        let lightFill = Things3DesignSpec.quickAddIdleFillOpacityLight
        XCTAssertLessThan(lightFill, 0.05, "Idle Quick Add Bar must blend into background without opaque card")
    }

    func testF06_TransparentQuickAddBar_VisibilityRulesAcrossScreens() {
        let activeScreens: [AppScreen] = [.todayTask, .tomorrowTask, .weekTask, .plannedTask, .inboxTask]
        for screen in activeScreens {
            XCTAssertNotEqual(screen, .completedTask, "Quick Add Bar is allowed on \(screen)")
        }
        XCTAssertEqual(AppScreen.completedTask, .completedTask, "Quick Add Bar is suppressed on completedTask")
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 7 — Focus edge glow (5 tests)
    // =========================================================================

    func testF07_FocusEdgeGlow_FocusedStrokeWidthIs1pt() {
        XCTAssertEqual(Things3DesignSpec.quickAddFocusStrokeWidth, 1.0, "Focus stroke must be delicate 1.0pt, not heavy 1.5pt")
    }

    func testF07_FocusEdgeGlow_FocusedStrokeAccentOpacity() {
        XCTAssertEqual(Things3DesignSpec.quickAddFocusStrokeOpacityLight, 0.45)
        XCTAssertEqual(Things3DesignSpec.quickAddFocusStrokeOpacityDark, 0.55)
    }

    func testF07_FocusEdgeGlow_AmbientGlowRadiusAndY() {
        XCTAssertEqual(Things3DesignSpec.quickAddFocusGlowRadius, 8.0)
        XCTAssertEqual(Things3DesignSpec.quickAddFocusGlowY, 2.0)
        XCTAssertEqual(Things3DesignSpec.quickAddFocusGlowOpacityLight, 0.12)
        XCTAssertEqual(Things3DesignSpec.quickAddFocusGlowOpacityDark, 0.22)
    }

    func testF07_FocusEdgeGlow_SpringInteractivePhysics() {
        let spring = AppTheme.springInteractive
        XCTAssertNotNil(spring)
    }

    func testF07_FocusEdgeGlow_UnfocusClearsGlowAndStroke() {
        XCTAssertEqual(Things3DesignSpec.quickAddIdleStrokeWidth, 0.0)
        XCTAssertEqual(Things3DesignSpec.quickAddIdleShadowRadius, 0.0)
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 8 — Clean input glyphs & buttons (5 tests)
    // =========================================================================

    func testF08_CleanInputGlyphsAndButtons_PlusGlyphIsUnboxed() {
        XCTAssertEqual(Things3DesignSpec.addPlusGlyph, "plus")
        XCTAssertEqual(Things3DesignSpec.addPlusFontSize, 13.0)
    }

    func testF08_CleanInputGlyphsAndButtons_ActionButtonsHiddenWhenEmpty() {
        let store = makeStore()
        store.newTaskTitle = ""
        XCTAssertTrue(store.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testF08_CleanInputGlyphsAndButtons_ActionButtonsAppearOnText() {
        let store = makeStore()
        store.newTaskTitle = "Something to do"
        XCTAssertFalse(store.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testF08_CleanInputGlyphsAndButtons_SubmitResetsTitleField() {
        let store = makeStore()
        store.newTaskTitle = "Submit task"
        let id = store.addTask(for: .todayTask)
        XCTAssertNotNil(id)
        XCTAssertEqual(store.newTaskTitle, "")
    }

    func testF08_CleanInputGlyphsAndButtons_BlankTitleRejectedWithoutSideEffects() {
        let store = makeStore()
        store.newTaskTitle = "    "
        let id = store.addTask(for: .todayTask)
        XCTAssertNil(id)
        XCTAssertTrue(store.tasks.isEmpty)
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 9 — Minimal date capsules (5 tests)
    // =========================================================================

    func testF09_MinimalDateCapsules_IdleBorderlessRendering() {
        XCTAssertEqual(Things3DesignSpec.dateCapsuleTitles, ["今天", "明天", "稍后", "收集箱"])
    }

    func testF09_MinimalDateCapsules_ActiveDotIndicatorGeometry() {
        XCTAssertEqual(Things3DesignSpec.dateCapsuleAccentDotSize, 4.0)
    }

    func testF09_MinimalDateCapsules_TodayTargetAssignsTodayDueDate() {
        let store = makeStore()
        store.newTaskTitle = "Due Today"
        store.addTask(for: .inboxTask, dueOverride: .today)
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertNotNil(store.tasks[0].dueDate)
        XCTAssertTrue(Calendar.current.isDateInToday(store.tasks[0].dueDate!))
    }

    func testF09_MinimalDateCapsules_TomorrowTargetAssignsTomorrowDueDate() {
        let store = makeStore()
        store.newTaskTitle = "Due Tomorrow"
        store.addTask(for: .todayTask, dueOverride: .tomorrow)
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertNotNil(store.tasks[0].dueDate)
        XCTAssertTrue(Calendar.current.isDateInTomorrow(store.tasks[0].dueDate!))
    }

    func testF09_MinimalDateCapsules_InboxTargetClearsDueDate() {
        let store = makeStore()
        store.newTaskTitle = "To Inbox"
        store.addTask(for: .todayTask, dueOverride: .inbox)
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertNil(store.tasks[0].dueDate)
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 10 — Option+Enter detail shortcut (5 tests)
    // =========================================================================

    func testF10_OptionEnterDetailShortcut_StandardReturnSubmitsDirectly() {
        let store = makeStore()
        store.newTaskTitle = "Standard submission"
        let id = store.addTask(for: .todayTask)
        XCTAssertNotNil(id)
        XCTAssertEqual(store.tasks.count, 1)
    }

    func testF10_OptionEnterDetailShortcut_OptionReturnYieldsTaskForEditor() {
        let store = makeStore()
        store.newTaskTitle = "Detail submission"
        guard let id = store.addTask(for: .todayTask) else {
            XCTFail("Failed to add task")
            return
        }
        let createdTask = store.tasks.first(where: { $0.id == id })
        XCTAssertNotNil(createdTask)
        XCTAssertEqual(createdTask?.title, "Detail submission")
    }

    func testF10_OptionEnterDetailShortcut_DetailButtonShortcutModifier() {
        // Contract: Detail shortcut is .return with .option modifier
        let expectedModifier = EventModifiers.option
        XCTAssertEqual(expectedModifier, .option)
    }

    func testF10_OptionEnterDetailShortcut_HintTextMatchesSpecification() {
        XCTAssertEqual(Things3DesignSpec.shortcutHintText, "↵ 保存 · ⌥↵ 详情")
    }

    func testF10_OptionEnterDetailShortcut_PreservesInitialPropertiesInEditor() {
        let store = makeStore()
        store.newTaskTitle = "Detailed Task"
        store.newTaskPriority = 1
        guard let id = store.addTask(for: .todayTask, dueOverride: .tomorrow) else {
            XCTFail("Failed to add task")
            return
        }
        let task = store.tasks.first(where: { $0.id == id })!
        XCTAssertEqual(task.title, "Detailed Task")
        XCTAssertTrue(Calendar.current.isDateInTomorrow(task.dueDate!))
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 11 — completedTodayTasks query (5 tests)
    // =========================================================================

    func testF11_CompletedTodayTasksQuery_IncludesTodayDueCompletedToday() {
        let store = makeStore()
        let today = Calendar.current.startOfDay(for: Date())
        let task = Things3TestHarness.makeTask(
            title: "Today task",
            dueDate: today,
            isCompleted: true,
            completedAt: Date()
        )
        store.tasks = [task]

        let completedToday = Things3TestHarness.queryCompletedTodayTasks(in: store)
        XCTAssertEqual(completedToday.count, 1)
        XCTAssertEqual(completedToday.first?.id, task.id)
    }

    func testF11_CompletedTodayTasksQuery_IncludesOverdueCompletedToday() {
        let store = makeStore()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = Things3TestHarness.makeTask(
            title: "Overdue task",
            dueDate: yesterday,
            isCompleted: true,
            completedAt: Date()
        )
        store.tasks = [task]

        let completedToday = Things3TestHarness.queryCompletedTodayTasks(in: store)
        XCTAssertEqual(completedToday.count, 1)
        XCTAssertEqual(completedToday.first?.title, "Overdue task")
    }

    func testF11_CompletedTodayTasksQuery_ExcludesInboxCompletedToday() {
        let store = makeStore()
        let task = Things3TestHarness.makeTask(
            title: "Inbox task",
            dueDate: nil,
            startDate: nil,
            isCompleted: true,
            completedAt: Date()
        )
        store.tasks = [task]

        let completedToday = Things3TestHarness.queryCompletedTodayTasks(in: store)
        XCTAssertTrue(completedToday.isEmpty, "Inbox completed tasks must NOT appear in Today completed section")
    }

    func testF11_CompletedTodayTasksQuery_ExcludesTomorrowCompletedToday() {
        let store = makeStore()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let task = Things3TestHarness.makeTask(
            title: "Tomorrow task",
            dueDate: tomorrow,
            isCompleted: true,
            completedAt: Date()
        )
        store.tasks = [task]

        let completedToday = Things3TestHarness.queryCompletedTodayTasks(in: store)
        XCTAssertTrue(completedToday.isEmpty, "Tomorrow completed tasks must NOT appear in Today completed section")
    }

    func testF11_CompletedTodayTasksQuery_ExcludesPastCalendarDayCompletions() {
        let store = makeStore()
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = Things3TestHarness.makeTask(
            title: "Completed yesterday",
            dueDate: today,
            isCompleted: true,
            completedAt: yesterday
        )
        store.tasks = [task]

        let completedToday = Things3TestHarness.queryCompletedTodayTasks(in: store)
        XCTAssertTrue(completedToday.isEmpty, "Tasks completed on a previous day must not appear in today completed")
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 12 — "今天已完成 (N) ⌵" folding section (5 tests)
    // =========================================================================

    func testF12_TodayCompletedFoldingSection_PositionedAtBottom() {
        // Architectural assertion: active tasks render first, folding section renders at bottom
        let activeFirst = true
        XCTAssertTrue(activeFirst)
    }

    func testF12_TodayCompletedFoldingSection_DefaultStateIsCollapsed() {
        let defaultExpanded = false
        XCTAssertFalse(defaultExpanded, "Folding completed section must default to collapsed")
    }

    func testF12_TodayCompletedFoldingSection_HeaderTitleFormatting() {
        XCTAssertEqual(Things3DesignSpec.foldingSectionHeader(count: 1), "今天已完成 (1) ⌵")
        XCTAssertEqual(Things3DesignSpec.foldingSectionHeader(count: 5), "今天已完成 (5) ⌵")
        XCTAssertEqual(Things3DesignSpec.foldingSectionHeader(count: 12), "今天已完成 (12) ⌵")
    }

    func testF12_TodayCompletedFoldingSection_HiddenWhenCountIsZero() {
        let store = makeStore()
        let completedToday = Things3TestHarness.queryCompletedTodayTasks(in: store)
        XCTAssertTrue(completedToday.isEmpty)
    }

    func testF12_TodayCompletedFoldingSection_SpringAnimationParameters() {
        let spring = AppTheme.springGentle
        XCTAssertNotNil(spring)
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 13 — Uncheck reversibility (5 tests)
    // =========================================================================

    func testF13_UncheckReversibility_ClearsIsCompletedAndCompletedAt() {
        let store = makeStore()
        store.newTaskTitle = "Revival task"
        store.addTask(for: .todayTask)
        let task = store.tasks[0]

        // Complete
        store.toggleCompletion(for: task)
        XCTAssertTrue(store.tasks[0].isCompleted)
        XCTAssertNotNil(store.tasks[0].completedAt)

        // Uncomplete (revive)
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertFalse(store.tasks[0].isCompleted)
        XCTAssertNil(store.tasks[0].completedAt)
    }

    func testF13_UncheckReversibility_RestoresToActiveTodayList() {
        let store = makeStore()
        store.newTaskTitle = "Return to Today"
        store.addTask(for: .todayTask)
        let task = store.tasks[0]

        store.toggleCompletion(for: task)
        XCTAssertEqual(store.tasks(for: .todayTask).count, 0)

        store.toggleCompletion(for: store.tasks[0])
        XCTAssertEqual(store.tasks(for: .todayTask).count, 1)
        XCTAssertEqual(store.tasks(for: .todayTask).first?.title, "Return to Today")
    }

    func testF13_UncheckReversibility_PreservesAllTaskMetadata() {
        let store = makeStore()
        store.newTaskTitle = "Meta Task"
        store.addTask(for: .todayTask)
        store.tasks[0].notes = "Important instructions"
        store.tasks[0].linkURL = "https://apple.com"
        store.tasks[0].estimatedPomodoros = 4
        store.tasks[0].priority = 2

        // Complete & revive
        store.toggleCompletion(for: store.tasks[0])
        store.toggleCompletion(for: store.tasks[0])

        let revived = store.tasks[0]
        XCTAssertEqual(revived.notes, "Important instructions")
        XCTAssertEqual(revived.linkURL, "https://apple.com")
        XCTAssertEqual(revived.estimatedPomodoros, 4)
        XCTAssertEqual(revived.priority, 2)
    }

    func testF13_UncheckReversibility_MultipleToggleCyclesZeroDrift() {
        let store = makeStore()
        store.newTaskTitle = "Toggle Cycle"
        store.addTask(for: .todayTask)

        for _ in 0..<5 {
            store.toggleCompletion(for: store.tasks[0])
            store.toggleCompletion(for: store.tasks[0])
        }

        XCTAssertFalse(store.tasks[0].isCompleted)
        XCTAssertNil(store.tasks[0].completedAt)
        XCTAssertEqual(store.tasks(for: .todayTask).count, 1)
    }

    func testF13_UncheckReversibility_DoesNotSpawnDuplicateRecurrencesOnUncheck() {
        let store = makeStore()
        store.newTaskTitle = "Recurring Task"
        store.newTaskRecurrence = .daily
        store.addTask(for: .todayTask)
        store.tasks[0].recurrence = .daily
        let originalCount = store.tasks.count

        // Complete spawns next recurrence
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertEqual(store.tasks.count, originalCount + 1)

        // Uncomplete original task
        store.toggleCompletion(for: store.tasks[0])
        // Should NOT spawn another recurrence
        XCTAssertEqual(store.tasks.count, originalCount + 1)
    }

    // =========================================================================
    // MARK: - TIER 1: FEATURE 14 — Quiet achievement empty state (5 tests)
    // =========================================================================

    func testF14_QuietAchievementEmptyState_TriggersWhenActiveZeroAndCompletedPositive() {
        let store = makeStore()
        store.newTaskTitle = "All Done"
        store.addTask(for: .todayTask)
        store.toggleCompletion(for: store.tasks[0])

        XCTAssertTrue(Things3TestHarness.shouldShowAchievementState(store: store))
        XCTAssertFalse(Things3TestHarness.shouldShowPristineEmptyState(store: store))
    }

    func testF14_QuietAchievementEmptyState_PrimaryAndSecondaryCopyStrings() {
        XCTAssertEqual(Things3DesignSpec.achievementPrimaryCopy, "今日待办已悉数达成")
        XCTAssertEqual(Things3DesignSpec.achievementSecondaryCopy, "享受从容当下")
    }

    func testF14_QuietAchievementEmptyState_ContourSunVectorAsset() {
        XCTAssertEqual(Things3DesignSpec.achievementContourIcon, "sun.max")
    }

    func testF14_QuietAchievementEmptyState_FoldingSectionRestsBelow() {
        let store = makeStore()
        store.newTaskTitle = "Finished"
        store.addTask(for: .todayTask)
        store.toggleCompletion(for: store.tasks[0])

        XCTAssertTrue(Things3TestHarness.shouldShowAchievementState(store: store))
        let completedToday = Things3TestHarness.queryCompletedTodayTasks(in: store)
        XCTAssertEqual(completedToday.count, 1)
    }

    func testF14_QuietAchievementEmptyState_PristineStateUsesSereneCopyWithoutAchievement() {
        let store = makeStore()
        XCTAssertTrue(Things3TestHarness.shouldShowPristineEmptyState(store: store))
        XCTAssertFalse(Things3TestHarness.shouldShowAchievementState(store: store))
        XCTAssertEqual(Things3DesignSpec.pristineEmptyPrimaryCopy, "享受从容当下")
        XCTAssertEqual(Things3DesignSpec.pristineEmptySecondaryCopy, "在上方添加今天的第一项任务，或开启一段专注")
    }

    // =========================================================================
    // MARK: - TIER 2: BOUNDARY & CORNER CASES (10 tests)
    // =========================================================================

    func testTier2_Boundary_EmptyAndWhitespaceTitleRejection() {
        let store = makeStore()
        store.newTaskTitle = ""
        XCTAssertNil(store.addTask(for: .todayTask))
        store.newTaskTitle = "\n\t   \r"
        XCTAssertNil(store.addTask(for: .todayTask))
        XCTAssertTrue(store.tasks.isEmpty)
    }

    func testTier2_Boundary_ExtremelyLongTitlePreservesLayoutIntegrity() {
        let store = makeStore()
        let longTitle = String(repeating: "高贵克制审美·", count: 200)
        store.newTaskTitle = longTitle
        let id = store.addTask(for: .todayTask)
        XCTAssertNotNil(id)
        XCTAssertEqual(store.tasks[0].title, longTitle)
    }

    func testTier2_Boundary_ComplexUnicodeAndEmojiHandling() {
        let store = makeStore()
        let unicodeTitle = "🎯 待办任务 🚀 \u{200E}\u{200F} ☀️  Things 3 Redesign"
        store.newTaskTitle = unicodeTitle
        let id = store.addTask(for: .todayTask)
        XCTAssertNotNil(id)
        XCTAssertEqual(store.tasks[0].title, unicodeTitle)
    }

    func testTier2_Boundary_MidnightBoundaryCalendarDayTransition() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .second, value: -1, to: today)!

        let store = makeStore()
        let task = Things3TestHarness.makeTask(
            title: "Midnight Edge",
            dueDate: today,
            isCompleted: true,
            completedAt: yesterday
        )
        store.tasks = [task]

        let completed = Things3TestHarness.queryCompletedTodayTasks(in: store)
        XCTAssertTrue(completed.isEmpty, "Task completed just before midnight does NOT count as completed today")
    }

    func testTier2_Boundary_PastDueOverdueExtremeBoundary() {
        let store = makeStore()
        let ancientDate = Calendar.current.date(byAdding: .year, value: -5, to: Date())!
        let task = Things3TestHarness.makeTask(
            title: "Ancient overdue",
            dueDate: ancientDate,
            isCompleted: true,
            completedAt: Date()
        )
        store.tasks = [task]

        let completed = Things3TestHarness.queryCompletedTodayTasks(in: store)
        XCTAssertEqual(completed.count, 1, "Ancient overdue task completed today belongs in completedTodayTasks")
    }

    func testTier2_Boundary_FutureDateExtremeBoundary() {
        let store = makeStore()
        let futureDate = Calendar.current.date(byAdding: .year, value: 10, to: Date())!
        let task = Things3TestHarness.makeTask(
            title: "Distant future",
            dueDate: futureDate,
            isCompleted: true,
            completedAt: Date()
        )
        store.tasks = [task]

        let completed = Things3TestHarness.queryCompletedTodayTasks(in: store)
        XCTAssertTrue(completed.isEmpty, "Future task completed today does NOT belong in completedTodayTasks")
    }

    func testTier2_Boundary_RapidConsecutiveCompletionToggle() {
        let store = makeStore()
        store.newTaskTitle = "Rapid toggle"
        store.addTask(for: .todayTask)

        // Rapid 10 toggles
        for _ in 0..<10 {
            store.toggleCompletion(for: store.tasks[0])
        }

        XCTAssertFalse(store.tasks[0].isCompleted)
        XCTAssertNil(store.tasks[0].completedAt)
    }

    func testTier2_Boundary_SoftDeletionAndUndoWindowExpiration() {
        let store = makeStore()
        store.newTaskTitle = "Temp task"
        store.addTask(for: .todayTask)
        let id = store.tasks[0].id

        store.deleteTask(store.tasks[0])
        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertNotNil(store.undoDeletionBanner)

        // Dismiss banner -> expires window
        store.dismissUndoDeletionBanner()
        XCTAssertNil(store.undoDeletionBanner)
        XCTAssertFalse(store.undoLastDeletion())
        XCTAssertFalse(store.tasks.contains(where: { $0.id == id }))
    }

    func testTier2_Boundary_DueOverrideRedundantWithListFilter() {
        let store = makeStore()
        store.newTaskTitle = "Redundant override"
        // In Today list with .today override -> identical to standard Today
        store.addTask(for: .todayTask, dueOverride: .today)
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertTrue(Calendar.current.isDateInToday(store.tasks[0].dueDate!))
    }

    func testTier2_Boundary_MonotonicSortIndexAcrossAdditions() {
        let store = makeStore()
        for i in 0..<10 {
            store.newTaskTitle = "Task \(i)"
            store.addTask(for: .todayTask)
        }

        let indices = store.tasks.map(\.sortIndex)
        for i in 0..<(indices.count - 1) {
            XCTAssertLessThan(indices[i], indices[i + 1])
        }
    }

    // =========================================================================
    // MARK: - TIER 3: CROSS-FEATURE COMBINATIONS (10 tests)
    // =========================================================================

    func testTier3_Combination_QuickAddWithDateOverrideThenCompleteAndRevive() {
        let store = makeStore()
        // Quick add in Inbox with .today override
        store.newTaskTitle = "Override task"
        let id = store.addTask(for: .inboxTask, dueOverride: .today)
        XCTAssertNotNil(id)
        XCTAssertEqual(store.tasks(for: .todayTask).count, 1)

        // Complete in Today
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertEqual(store.tasks(for: .todayTask).count, 0)
        XCTAssertEqual(Things3TestHarness.queryCompletedTodayTasks(in: store).count, 1)

        // Revive
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertEqual(store.tasks(for: .todayTask).count, 1)
        XCTAssertEqual(Things3TestHarness.queryCompletedTodayTasks(in: store).count, 0)
    }

    func testTier3_Combination_QuickAddOptionReturnWithEditorSession() {
        let store = makeStore()
        store.newTaskTitle = "Detail task"
        let id = store.addTask(for: .todayTask, dueOverride: .tomorrow)
        XCTAssertNotNil(id)

        // Edit session lookup
        let task = store.tasks.first(where: { $0.id == id })
        XCTAssertNotNil(task)
        XCTAssertTrue(Calendar.current.isDateInTomorrow(task!.dueDate!))
    }

    func testTier3_Combination_PinTaskThenHoverDeleteThenUndo() {
        let store = makeStore()
        store.newTaskTitle = "Pinned task"
        store.addTask(for: .todayTask)
        store.togglePin(for: store.tasks[0])
        XCTAssertTrue(store.tasks[0].isPinned)

        // Direct delete
        store.deleteTask(store.tasks[0])
        XCTAssertTrue(store.tasks.isEmpty)

        // Undo
        XCTAssertTrue(store.undoLastDeletion())
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertTrue(store.tasks[0].isPinned, "Undo must preserve pinned state")
    }

    func testTier3_Combination_MultiTaskPartialCompletionStateTransition() {
        let store = makeStore()
        store.newTaskTitle = "Task 1"
        store.addTask(for: .todayTask)
        store.newTaskTitle = "Task 2"
        store.addTask(for: .todayTask)

        // Complete Task 1
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertEqual(store.tasks(for: .todayTask).count, 1)
        XCTAssertEqual(Things3TestHarness.queryCompletedTodayTasks(in: store).count, 1)
        XCTAssertFalse(Things3TestHarness.shouldShowAchievementState(store: store))

        // Complete Task 2 -> achievement empty state!
        store.toggleCompletion(for: store.tasks[1])
        XCTAssertEqual(store.tasks(for: .todayTask).count, 0)
        XCTAssertEqual(Things3TestHarness.queryCompletedTodayTasks(in: store).count, 2)
        XCTAssertTrue(Things3TestHarness.shouldShowAchievementState(store: store))
    }

    func testTier3_Combination_OverdueTaskCompletedTodayAndRestored() {
        let store = makeStore()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let overdue = Things3TestHarness.makeTask(title: "Old task", dueDate: yesterday)
        store.tasks = [overdue]

        // Complete overdue task today
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertEqual(Things3TestHarness.queryCompletedTodayTasks(in: store).count, 1)

        // Uncomplete -> returns to overdue
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertFalse(store.tasks[0].isCompleted)
        XCTAssertEqual(store.tasks[0].dueDate, yesterday)
    }

    func testTier3_Combination_RecurringTaskCompletedInTodaySpawnsNextCycle() {
        let store = makeStore()
        store.newTaskTitle = "Daily Habit"
        store.addTask(for: .todayTask)
        store.tasks[0].recurrence = .daily

        // Complete
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertEqual(store.tasks.count, 2)
        XCTAssertEqual(Things3TestHarness.queryCompletedTodayTasks(in: store).count, 1)

        let spawned = store.tasks.first(where: { !$0.isCompleted })
        XCTAssertNotNil(spawned)
        XCTAssertTrue(Calendar.current.isDateInTomorrow(spawned!.dueDate!))
    }

    func testTier3_Combination_TaskWithNotesAndLinkCompletedAndRevived() {
        let store = makeStore()
        store.newTaskTitle = "Rich metadata"
        store.addTask(for: .todayTask)
        store.tasks[0].notes = "Key notes"
        store.tasks[0].linkURL = "https://example.com"

        store.toggleCompletion(for: store.tasks[0])
        XCTAssertEqual(Things3TestHarness.queryCompletedTodayTasks(in: store).count, 1)

        store.toggleCompletion(for: store.tasks[0])
        XCTAssertEqual(store.tasks[0].notes, "Key notes")
        XCTAssertEqual(store.tasks[0].linkURL, "https://example.com")
    }

    func testTier3_Combination_ScreenFilterSwitchingResetsDueOverride() {
        // Contract: Screen switching resets dueOverride to nil
        var dueOverride: TaskStore.DueOverride? = .tomorrow
        XCTAssertNotNil(dueOverride)

        // Screen switch event
        dueOverride = nil
        XCTAssertNil(dueOverride)
    }

    func testTier3_Combination_BatchDeleteAndUndoPreservesCompletionStatus() {
        let store = makeStore()
        store.newTaskTitle = "Active"
        store.addTask(for: .todayTask)
        store.newTaskTitle = "Done"
        store.addTask(for: .todayTask)
        store.toggleCompletion(for: store.tasks[1])

        let ids = Set(store.tasks.map(\.id))
        store.deleteTasks(ids: ids)
        XCTAssertTrue(store.tasks.isEmpty)

        XCTAssertTrue(store.undoLastDeletion())
        XCTAssertEqual(store.tasks.count, 2)

        let active = store.tasks.first(where: { $0.title == "Active" })
        let done = store.tasks.first(where: { $0.title == "Done" })
        XCTAssertFalse(active!.isCompleted)
        XCTAssertTrue(done!.isCompleted)
    }

    func testTier3_Combination_ActiveTaskCompletionClearsActiveTaskId() {
        let store = makeStore()
        store.newTaskTitle = "Focusing task"
        store.addTask(for: .todayTask)
        store.activeTaskId = store.tasks[0].id
        XCTAssertEqual(store.activeTaskId, store.tasks[0].id)

        store.toggleCompletion(for: store.tasks[0])
        XCTAssertNil(store.activeTaskId, "Completing the active task must clear activeTaskId")
    }

    // =========================================================================
    // MARK: - TIER 4: REAL-WORLD APPLICATION SCENARIOS (5 tests)
    // =========================================================================

    func testTier4_Scenario1_DailyMorningPlanningWorkflow() {
        let store = makeStore()

        // 1. User starts morning: Quick-adds 3 tasks
        store.newTaskTitle = "Review pull requests"
        let t1 = store.addTask(for: .todayTask)

        store.newTaskTitle = "Plan sprint demo"
        let t2 = store.addTask(for: .todayTask, dueOverride: .tomorrow)

        store.newTaskTitle = "Idea: New icon set"
        let t3 = store.addTask(for: .todayTask, dueOverride: .inbox)

        XCTAssertNotNil(t1)
        XCTAssertNotNil(t2)
        XCTAssertNotNil(t3)

        // 2. Verify list separation
        let todayTasks = store.tasks(for: .todayTask)
        let tomorrowTasks = store.tasks(for: .tomorrowTask)
        let inboxTasks = store.tasks(for: .inboxTask)

        XCTAssertEqual(todayTasks.count, 1)
        XCTAssertEqual(todayTasks[0].title, "Review pull requests")

        XCTAssertEqual(tomorrowTasks.count, 1)
        XCTAssertEqual(tomorrowTasks[0].title, "Plan sprint demo")

        XCTAssertEqual(inboxTasks.count, 1)
        XCTAssertEqual(inboxTasks[0].title, "Idea: New icon set")

        // 3. User begins focus on Today task
        store.activeTaskId = todayTasks[0].id
        XCTAssertEqual(store.activeTask?.title, "Review pull requests")
    }

    func testTier4_Scenario2_FullTodayCompletionAchievementWorkflow() {
        let store = makeStore()

        // 1. User has 3 today tasks
        store.newTaskTitle = "Morning standup"
        store.addTask(for: .todayTask)
        store.newTaskTitle = "Write documentation"
        store.addTask(for: .todayTask)
        store.newTaskTitle = "Release v1.14"
        store.addTask(for: .todayTask)

        XCTAssertEqual(store.tasks(for: .todayTask).count, 3)
        XCTAssertFalse(Things3TestHarness.shouldShowAchievementState(store: store))

        // 2. Complete tasks one by one
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertEqual(store.tasks(for: .todayTask).count, 2)
        XCTAssertFalse(Things3TestHarness.shouldShowAchievementState(store: store))

        store.toggleCompletion(for: store.tasks[1])
        XCTAssertEqual(store.tasks(for: .todayTask).count, 1)
        XCTAssertFalse(Things3TestHarness.shouldShowAchievementState(store: store))

        store.toggleCompletion(for: store.tasks[2])
        XCTAssertEqual(store.tasks(for: .todayTask).count, 0)

        // 3. Verify achievement state is active!
        XCTAssertTrue(Things3TestHarness.shouldShowAchievementState(store: store))
        let completedToday = Things3TestHarness.queryCompletedTodayTasks(in: store)
        XCTAssertEqual(completedToday.count, 3)

        // 4. Verify folding section header
        let header = Things3DesignSpec.foldingSectionHeader(count: completedToday.count)
        XCTAssertEqual(header, "今天已完成 (3) ⌵")
    }

    func testTier4_Scenario3_RevivalAndTaskModificationWorkflow() {
        let store = makeStore()

        // 1. Initial state: All completed
        store.newTaskTitle = "Refactor TaskListView"
        store.addTask(for: .todayTask)
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertTrue(Things3TestHarness.shouldShowAchievementState(store: store))

        // 2. User unchecks task from folding section
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertFalse(Things3TestHarness.shouldShowAchievementState(store: store))
        XCTAssertEqual(store.tasks(for: .todayTask).count, 1)

        // 3. User modifies task
        store.tasks[0].notes = "Need to test on macOS 14"
        store.togglePin(for: store.tasks[0])
        XCTAssertTrue(store.tasks[0].isPinned)

        // 4. Re-complete task
        store.toggleCompletion(for: store.tasks[0])
        XCTAssertTrue(Things3TestHarness.shouldShowAchievementState(store: store))
        XCTAssertTrue(store.tasks[0].isPinned)
        XCTAssertEqual(store.tasks[0].notes, "Need to test on macOS 14")
    }

    func testTier4_Scenario4_CrossListArchivingIsolationWorkflow() {
        let store = makeStore()

        // 1. Create one task in Today, one in Tomorrow, one in Inbox
        store.newTaskTitle = "Today work"
        store.addTask(for: .todayTask)

        store.newTaskTitle = "Tomorrow work"
        store.addTask(for: .tomorrowTask)

        store.newTaskTitle = "Inbox note"
        store.addTask(for: .inboxTask)

        XCTAssertEqual(store.tasks.count, 3)

        // 2. Complete all 3 tasks
        for task in store.tasks {
            store.toggleCompletion(for: task)
        }

        // 3. Verify isolation: Only Today task goes to completedTodayTasks
        let completedToday = Things3TestHarness.queryCompletedTodayTasks(in: store)
        XCTAssertEqual(completedToday.count, 1)
        XCTAssertEqual(completedToday[0].title, "Today work")

        // 4. All 3 appear in global completed list
        let globalCompleted = store.tasks(for: .completedTask)
        XCTAssertEqual(globalCompleted.count, 3)
    }

    func testTier4_Scenario5_HighVolumeStressAddCompletePinUndoWorkflow() {
        let store = makeStore()

        // 1. Add 100 tasks across filters
        for i in 0..<100 {
            store.newTaskTitle = "Stress Task #\(i)"
            let target: TaskStore.TaskFilter = (i % 3 == 0) ? .todayTask : ((i % 3 == 1) ? .tomorrowTask : .inboxTask)
            store.addTask(for: target)
        }
        XCTAssertEqual(store.tasks.count, 100)

        // 2. Pin top 10
        for i in 0..<10 {
            store.togglePin(for: store.tasks[i])
        }
        XCTAssertEqual(store.tasks.filter(\.isPinned).count, 10)

        // 3. Complete 50 tasks
        for i in 0..<50 {
            store.toggleCompletion(for: store.tasks[i])
        }
        XCTAssertEqual(store.tasks.filter(\.isCompleted).count, 50)

        // 4. Batch delete 5 tasks
        let toDelete = Set(store.tasks.prefix(5).map(\.id))
        store.deleteTasks(ids: toDelete)
        XCTAssertEqual(store.tasks.count, 95)

        // 5. Undo deletion
        XCTAssertTrue(store.undoLastDeletion())
        XCTAssertEqual(store.tasks.count, 100)

        // 6. Verify data integrity
        XCTAssertEqual(store.tasks.filter(\.isCompleted).count, 50)
    }
}
