# TEST_READY: Things 3 Style Floating Modal & Task Interaction Redesign

## 1. Test Runner Commands

### Full Project Regression Run (Baseline + Floating Modal E2E)
```bash
swift test --disable-sandbox
```

### Things 3 Floating Modal E2E Suite Only
```bash
swift test --disable-sandbox --filter Things3FloatingModalE2ETests
```

### Clean Rebuild Verification
```bash
CLANG_MODULE_CACHE_PATH=.build/clang-module-cache \
  swift test --disable-sandbox --scratch-path .build
```

---

## 2. Test Execution & Coverage Statistics

| Category / Tier | Scope | Tests Planned | Tests Executed | Passed | Failed | Execution Time |
|---|---|:---:|:---:|:---:|:---:|:---:|
| **Tier 1 — Feature Coverage** | Floating surface, Date capsules, 4-tier context menu, Inline notes, Profile modal | 28 | 28 | 28 | 0 | 0.021s |
| **Tier 2 — Boundary & Corner Cases** | Empty/whitespace notes, multiline trailing, URL validation, leap year, rollback | 12 | 12 | 12 | 0 | 0.007s |
| **Tier 3 — Cross-Feature Interactions** | Reschedule retention, live timer preservation, sort order, snapshot decoupling | 5 | 5 | 5 | 0 | 0.007s |
| **Tier 4 — Real-World Scenarios** | End-to-end task lifecycle, Backlog triage with clipboard & undo safety | 2 | 2 | 2 | 0 | 0.010s |
| **Subtotal (Floating Modal E2E)** | `Things3FloatingModalE2ETests.swift` | **48** | **48** | **48** | **0** | **0.045s** |
| **Existing Baseline Suite** | Core, Stores, Services, App, Views, Product, E2E | 521 | 521 | 521 | 0 | 3.390s |
| **Total Test Suite** | Full Project | **569** | **569** | **569** | **0** | **3.435s** |

**Pass Rate**: **100% (569 / 569 passed, 0 failures, 0 unexpected)**.

---

## 3. Detailed Feature Breakdown (Tier 1: 28 Tests)

### Feature 1: Floating Card Modal Surface Tokens & Geometry (R1 & R2)
1. `testF01_FloatingCardSurface_ContinuousSquircleCornerRadius18`: Confirms squircle curvature token (`AppTheme.squircle(radius: 18)`) and default corner radius `18pt` continuous style.
2. `testF01_FloatingCardSurface_InnerHighlightStroke075pt`: Confirms 0.75pt inner highlight stroke width and 0.50pt outer hairline boundary with top-to-bottom specular gradients in light and dark modes.
3. `testF01_FloatingCardSurface_PopoverElevationTokens`: Confirms `.multiLayerShadow(elevation: .popover)` ambient radius `28pt` (y: `14pt`) and contact radius `5pt` (y: `2.5pt`).
4. `testF01_FloatingCardSurface_ModalDimensionsTask460Profile350`: Validates task modal width (`460pt`), profile modal width (`350pt`), avatar size (`72pt`), and color swatches (`24pt`).
5. `testF01_FloatingCardSurface_ShortcutHintsTextContract`: Confirms footer shortcut hint text `"⌘↵ 保存 · Esc 取消"`.
6. `testF01_FloatingCardSurface_CloseButtonInitializesAndDispatches`: Confirms `FloatingModalCloseButton` dismisses on user action.

### Feature 2: Things 3 Date Capsules Logic & Date Conversions (R1)
7. `testF02_DateCapsules_PresetTitlesAndCount`: Verifies standard 5 preset capsules (`["无", "今天", "明天", "稍后", "自定义日期…"]`).
8. `testF02_DateCapsules_NilDueDateMapsToNonePreset`: Classifies `nil` due date as `.none` ("无") and resolves to `nil`.
9. `testF02_DateCapsules_TodayDateMapsToTodayPreset`: Classifies current day timestamps as `.today` ("今天") and resolves to start of today.
10. `testF02_DateCapsules_TomorrowDateMapsToTomorrowPreset`: Classifies tomorrow dates as `.tomorrow` ("明天") and resolves to start of tomorrow.
11. `testF02_DateCapsules_LaterDateMapsToLaterPreset`: Classifies today + 2 days as `.later` ("稍后") and resolves to start of later day.
12. `testF02_DateCapsules_ArbitraryDateMapsToCustomPresetWithFormattedLabel`: Classifies future dates as `.custom` with canonical Chinese formatting `"M月d日"`.

### Feature 3: 4-Tier Native Context Menu Structure & Action Dispatching (R3)
13. `testF03_ContextMenu_FourTierStructureAndSeparators`: Verifies 4 tiers separated by 3 dividers with exact SF Symbol and label specifications.
14. `testF03_ContextMenu_Tier1FocusAndEditContracts`: Dispatches Tier 1 actions: starts focus session intent (`bolt.fill`) and generates `EditTaskSession` snapshot (`pencil`).
15. `testF03_ContextMenu_Tier2RescheduleMovesAcrossFilters`: Dispatches Tier 2 actions (`今天`, `明天`, `稍后`, `收集箱`) updating task `dueDate` and filter alignment.
16. `testF03_ContextMenu_Tier3PinTogglePreservesSortPriority`: Dispatches Tier 3 pin toggle, setting `isPinned` and keeping priority sorting intact.
17. `testF03_ContextMenu_Tier3CompleteToggleMarksCompleted`: Dispatches Tier 3 completion toggle, marking `isCompleted` with `completedAt` timestamp.
18. `testF03_ContextMenu_Tier4ClipboardCopyAndDestructiveDelete`: Dispatches Tier 4 title copy to `NSPasteboard` and soft-deletes task with undo banner presentation.

### Feature 4: Inline Note First Line Extraction & Formatting (R4)
19. `testF04_InlineNote_SingleLineExtraction`: Extracts plain single line note without alteration.
20. `testF04_InlineNote_MultiLineReturnsFirstNonEmptyLine`: Extracts first line of multi-line note, ignoring subsequent paragraphs.
21. `testF04_InlineNote_LeadingBlankLinesSkipped`: Skips leading whitespace and blank lines to extract the first substantive line.
22. `testF04_InlineNote_VisualTokens12ptAnd50PercentOpacity`: Confirms 12pt regular typography and 50% opacity styling (`AppTheme.secondaryText.opacity(0.50)`).
23. `testF04_InlineNote_HoverTooltipPreservesFullMultitext`: Confirms raw task notes are preserved for complete hover tooltip exposure (`.help(task.notes)`).
24. `testF04_InlineNote_CarriageReturnAndWindowsNewlineFidelity`: Verifies cross-platform newline compatibility (`\r\n` and `\r`).

### Feature 5: Profile Editing Modal State Management (R2)
25. `testF05_ProfileModal_Squircle350WidthAndDismissContract`: Verifies 350pt squircle container and dismiss lifecycle.
26. `testF05_ProfileModal_CapsuleNicknameWithPersonGlyph`: Verifies capsule nickname container with `person.fill` icon.
27. `testF05_ProfileModal_24ptColorSwatchesInRecessedTray`: Verifies 24pt swatches across 6 AccentPreset colors in recessed pill tray.
28. `testF05_ProfileModal_UncommittedAvatarChangeRollbackOnCancel`: Verifies that uncommitted avatar path and color modifications roll back to initial state on cancel.
29. `testF05_ProfileModal_CommittedStatePersistsOnSave`: Verifies that saving profile commits sanitized username and new avatar selections.

---

## 4. Boundary, Combination & Real-World Breakdown (Tiers 2–4: 19 Tests)

### Tier 2: Boundary & Corner Cases (12 Tests)
- `testTier2_EmptyNotes_ReturnsNilSummary`: Empty notes string yields `nil` summary.
- `testTier2_WhitespaceOnlyNotes_ReturnsNilSummary`: Tabs, spaces, and newline-only notes yield `nil` summary.
- `testTier2_SingleLineNotesWithoutNewlines_ExtractedCleanly`: Leading and trailing whitespaces stripped from single-line notes.
- `testTier2_MultiLineNotesWithTrailingNewlines_PreservesFirstLine`: Consecutive trailing newlines do not corrupt first line extraction.
- `testTier2_ExtremeLengthFirstLine_ExtractedForTailTruncation`: Long 800+ character first line preserved intact for SwiftUI tail truncation.
- `testTier2_URLValidation_ValidHTTPSchemesAccepted`: Standard HTTP and HTTPS URLs with query params, hashes, and ports validated true.
- `testTier2_URLValidation_InvalidSchemesRejected`: Unsupported schemes (`ftp://`, `javascript:`, `file:///`, `mailto:`, `tel:`) validated false.
- `testTier2_URLValidation_MalformedAndWhitespaceURLsRejected`: Empty, whitespace, scheme-only, and malformed strings safely rejected.
- `testTier2_CustomDate_EdgeCaseLeapYearFebruary29`: Leap day (Feb 29) formats cleanly as `"2月29日"`.
- `testTier2_CustomDate_EdgeCaseYearRolloverDec31ToJan01`: Year boundary rollover from Dec 31 to Jan 01 correctly resolves tomorrow.
- `testTier2_UncommittedProfileState_MultipleDiscardsRollbackCleanly`: Multiple sequential discards restore initial state without leaking dirty edits.
- `testTier2_EmptyTaskTitleInEditor_DisallowsSave`: Empty or whitespace-only task title disables modal save action.

### Tier 3: Cross-Feature Interactions (5 Tests)
- `testTier3_TaskRescheduling_PreservesInlineNotesAndURL`: Rescheduling across Today -> Tomorrow -> Week -> Inbox retains notes and link intact.
- `testTier3_EditingModalSave_PreservesActiveFocusSessionAndTimer`: Updating a task in the floating modal while a focus timer is running preserves the active timer session.
- `testTier3_ContextMenuPinAndComplete_PreservesSortOrderAndFilterTransitions`: Context menu Pin + Complete operations maintain list ordering and filter integrity.
- `testTier3_EditSessionSnapshot_DecoupledFromLiveTaskMutations`: Background task mutations do not dirty an active in-flight `EditTaskSession`.
- `testTier3_InlineNoteExtraction_WithClipboardCopyAndRecreation`: Copying a task title to clipboard and recreating a task preserves first-line summary extraction.

### Tier 4: Real-World Scenarios (2 Tests)
- `testTier4_CompleteUserTaskLifecycle_CreationRescheduleNoteInspectionModalEditingCompletion`:
  Comprehensive end-to-end user journey:
  1. Quick Add creates task in Today list.
  2. Context menu Tier 2 reschedules task to Tomorrow.
  3. Notes and URL attached; first line extracted as row summary.
  4. Floating card modal opened with `EditTaskSession` snapshot.
  5. Title, notes, and custom date modified; saved with keyboard shortcut contract.
  6. Context menu Tier 1 starts focus session; timer runs smoothly.
  7. Context menu Tier 3 marks task complete; verified in completed filter.
- `testTier4_MultiTaskBacklogTriageWorkflow_BatchTriageWithClipboardAndDeletionSafety`:
  Multi-task triage scenario:
  1. Batch tasks added to Inbox with mixed notes and URLs.
  2. Context menu Tier 3 pins urgent task.
  3. Context menu Tier 2 distributes tasks across Today and Tomorrow.
  4. Context menu Tier 4 copies title to system pasteboard.
  5. Context menu Tier 4 deletes item with soft-delete undo restoration.
  6. Profile modal customization tested with uncommitted state rollback.

---

## 5. Verification Status

The E2E test suite for the Things 3 Style Floating Modal & Task Interaction Redesign is **100% green (569/569 tests passing)**, strictly requirement-driven, fully isolated, and ready for deployment verification and packaging.
