# E2E Test Infrastructure: Things 3 Minimalist Task List Redesign

## 1. Test Philosophy & Principles

### 1.1 Opaque-Box & Requirement-Driven
The Things 3 Minimalist Task List Redesign test suite is strictly opaque-box and requirement-driven, derived directly from `PROJECT.md § Feature Inventory` (Features 1–14) and `ORIGINAL_REQUEST.md`.
- **Zero Coupling to Private Internals**: Tests interact solely through public and package-internal contracts (`TaskStore`, `FocusTask`, `TaskFiltering`, `AppTheme`, `TypeScale`, `AppScreen`, `ContentViewState`). Private view hierarchy `@State` variables are never accessed directly.
- **Specification-Derived Assertions**: Every expected value is mathematically derived from product requirements, design system tokens, or explicit user agreements from the Grill-Me consensus.
- **Progressive Testability**: The test suite validates features through stable interface contracts. Test harnesses decouple view visual tokens from logic state machines, ensuring that tests execute and verify cleanly at every milestone iteration.
- **Deterministic & Isolated**: Each test provisions an isolated sandbox filesystem (`FileManager.default.temporaryDirectory`), sets up fresh store instances, cleans up on `tearDownWithError`, and runs without order dependency or side effects.

### 1.2 Four-Tier Testing Pyramid
The test suite implements an exhaustive four-tier structure:
1. **Tier 1 — Feature Coverage**: Comprehensive requirement verification for Features 1–14 (minimum 5 tests per feature = 70 tests).
2. **Tier 2 — Boundary & Corner Cases**: Stress-testing edge cases (empty strings, extreme unicode, max length, past/future dates, midnight boundaries, rapid toggling, undo expirations).
3. **Tier 3 — Cross-Feature Combinations**: Pairwise multi-step feature interactions (Quick Add with override + completion + revival; Pin + Hover + Delete + Undo; Recurrence spawning + Today completed settling).
4. **Tier 4 — Real-World Application Scenarios**: Multi-task, multi-screen end-to-end workflows representing realistic user journeys throughout a workday.

---

## 2. Feature Inventory Mapping

| Feature # | Feature Name | Requirement Contract | Test Suite Target | Tier 1 Tests |
|---|---|---|---|---|
| **F1** | Pure-Flat Row Layout | Stroke border = 0; soft neutral hover wash (`0.035..0.055`); cornerRadius = 6 | `testF01_PureFlatRow_*` | 5 |
| **F2** | Checkbox Horizontal Alignment | Dedicated 20pt leading slot; 0pt horizontal shift on completion or selection | `testF02_CheckboxHorizontalAlignment_*` | 5 |
| **F3** | Checkbox Vertical Alignment | Top alignment; optical offset ~2pt (comfortable) / ~1.5pt (compact) locked to title cap-height | `testF03_CheckboxVerticalAlignment_*` | 5 |
| **F4** | Hover Action Bar | 4 flat unboxed buttons (Focus, Pin, Edit, Delete); direct delete with undo toast | `testF04_HoverActionBar_*` | 5 |
| **F5** | Ultra-Muted Metadata | Quiet opacity 0.50..0.55; conditional line 2 rendering; calm warm rose overdue tint | `testF05_UltraMutedMetadata_*` | 5 |
| **F6** | Transparent Quick Add Bar | Borderless & shadowless idle state; blends transparently into background | `testF06_TransparentQuickAddBar_*` | 5 |
| **F7** | Focus Edge Glow | 1.0pt stroke + diffuse accent ambient glow (`radius: 8, y: 2`); spring physics | `testF07_FocusEdgeGlow_*` | 5 |
| **F8** | Clean Input Glyphs & Buttons | Naked `+` glyph; action buttons hidden when empty, appear on text entry; blank title rejection | `testF08_CleanInputGlyphsAndButtons_*` | 5 |
| **F9** | Minimal Date Capsules | Borderless minimal capsules; 4x4 micro accent dot on active state; correct list routing | `testF09_MinimalDateCapsules_*` | 5 |
| **F10** | Option+Enter Detail Shortcut | `⌥↵` in `.onSubmit` and `.keyboardShortcut`; routes `openEditor: true` with task UUID | `testF10_OptionEnterDetailShortcut_*` | 5 |
| **F11** | `completedTodayTasks` Query | Queries tasks completed today with `(dueDate <= today \|\| startDate <= today)`; excludes Inbox/Tomorrow/Later | `testF11_CompletedTodayTasksQuery_*` | 5 |
| **F12** | "今天已完成 (N) ⌵" Folding Section | Collapsible group at bottom of Today list; default collapsed; spring animation; dynamic count | `testF12_TodayCompletedFoldingSection_*` | 5 |
| **F13** | Uncheck Reversibility | Unchecking in "今天已完成" restores task immediately to "今日待办"; preserves all metadata | `testF13_UncheckReversibility_*` | 5 |
| **F14** | Quiet Achievement Empty State | Triggers when Today active tasks = 0; ultra-light contour sun; serene copy; completed fold below | `testF14_QuietAchievementEmptyState_*` | 5 |

---

## 3. Test Architecture & Harness Design

### 3.1 Architecture Overview

```
Tests/iFocusTests/E2E/Things3RedesignE2ETests.swift
├── Design Metrics & Specification Oracle (Things3DesignSpec)
│   ├── Row Layout Tokens (wash opacity, corner radius, stroke width)
│   ├── Checkbox Slot Geometry (20pt leading slot, 2pt optical offset)
│   ├── Quick Add Bar Surface & Glow (1pt stroke, radius: 8, y: 2)
│   ├── Metadata Opacities & Semantic Hues
│   └── Achievement State Assets & Copy Strings
├── Lifecycle & Query Specification Harness (Things3TestHarness)
│   ├── completedTodayTasks query predicate
│   ├── achievementStatePredicate
│   ├── foldingSectionHeader formatting
│   └── isolated temporary environment provisioning
├── Test Suites
│   ├── Tier 1: Feature Tests (Features 1–14, 5 tests each = 70 tests)
│   ├── Tier 2: Boundary & Corner Cases (10 tests)
│   ├── Tier 3: Cross-Feature Combinations (10 tests)
│   └── Tier 4: Real-World Application Scenarios (5 tests)
```

### 3.2 Design Tokens Verification
Visual and design-token contracts are tested through `Things3DesignSpec`, which asserts mathematical properties against `AppTheme`, `TypeScale`, and layout constants:
- Confirms light/dark mode opacity boundaries (e.g. `0.035 <= wash <= 0.055`).
- Confirms geometric invariants (e.g. `leadingSlotWidth == 20.0`).
- Confirms spring physics constants (`AppTheme.springInteractive.dampingFraction`).

### 3.3 State & Store Lifecycle Verification
Task lifecycle and state transitions are tested through isolated `TaskStore` sandboxes:
- Verifies task creation with default filter vs. `dueOverride`.
- Verifies soft deletion and 6-second undo window expiration.
- Verifies completion toggle, timestamp stamping, and revival back into active filters.
- Verifies cross-list filtering isolation between Today, Tomorrow, Inbox, Later, and Completed.

---

## 4. Tier 4 Real-World Application Scenarios

The suite includes five end-to-end integration scenarios representing complete user sessions:

1. **Scenario 1 — Daily Morning Workday Flow (`testTier4_Scenario1_DailyMorningPlanning`)**:
   - User launches app on Today view.
   - Quick-adds 3 tasks using different targets: standard Today task, Tomorrow override task, and Inbox override task.
   - Verifies each task lands in its respective list with correct due dates.
   - Starts focus on Today task (verifying active task binding).

2. **Scenario 2 — Full Today Completion & Achievement Flow (`testTier4_Scenario2_FullTodayCompletionAchievement`)**:
   - User has 3 active tasks in Today.
   - Completes tasks sequentially.
   - Verifies active Today tasks drop to 0, achievement empty state triggers with serene copy (*"今日待办已悉数达成 · 享受从容当下"*), and folding completed group contains all 3 tasks.

3. **Scenario 3 — Revival & Modification Workflow (`testTier4_Scenario3_RevivalAndTaskModification`)**:
   - Starting from full achievement state, user expands "今天已完成 (3) ⌵".
   - Unchecks one completed task.
   - Verifies achievement state exits, active task returns to "今日待办", user updates task notes, pins it to top, and re-completes it.

4. **Scenario 4 — Cross-List Archiving Isolation Flow (`testTier4_Scenario4_CrossListArchivingIsolation`)**:
   - User completes 1 Today task, 1 Tomorrow task, and 1 Inbox task.
   - Verifies Today's completed folding section contains strictly the Today task.
   - Verifies Tomorrow and Inbox completed tasks bypass Today's completed section and archive directly to global "已完成".

5. **Scenario 5 — High-Volume Stress Workflow (`testTier4_Scenario5_HighVolumeStressAddCompletePinUndo`)**:
   - Adds 100 tasks across multiple lists.
   - Pins 10 tasks, completes 50 tasks, batch-deletes 5 tasks and restores via undo.
   - Verifies count invariants, sort ordering, zero memory leaks, and performance latencies well below threshold limits.

---

## 5. Coverage & Verification Thresholds

| Metric | Threshold | Method of Verification |
|---|---|---|
| **Tier 1 Feature Coverage** | 100% of Features 1–14 (>=5 tests / feature) | `Things3RedesignE2ETests.swift` (70 tests) |
| **Tier 2 Boundary Cases** | >= 10 edge case scenarios | `Things3RedesignE2ETests.swift` (10 tests) |
| **Tier 3 Combinations** | >= 10 pairwise cross-feature tests | `Things3RedesignE2ETests.swift` (10 tests) |
| **Tier 4 Workflows** | 5 comprehensive real-world scenarios | `Things3RedesignE2ETests.swift` (5 tests) |
| **Total E2E Tests** | >= 95 new test cases | `swift test` execution output |
| **Baseline Regression** | 248 / 248 existing tests pass (0 failures) | `swift test` execution output |
| **Total Passing Tests** | >= 343 tests passed | `swift test` execution output |
| **Performance Benchmark** | `tasks(for: .today) @2000 < 150ms` | Performance benchmark suites |
| **Release Build** | 0 warnings, clean release compilation | `bash Scripts/package_app.sh` |
