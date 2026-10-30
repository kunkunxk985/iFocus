# Project: iFocus Things 3 Minimalist Task List Redesign

## Architecture
- **Architecture Overview**:
  - `TaskRowView.swift`: Pure-flat typography row, absolute checkbox column alignment (20pt invariant leading slot), top-alignment with title cap-height, borderless hover wash with 4 flat action glyphs (Focus, Pin, Edit, Delete), and whisper-quiet metadata display.
  - `TaskListView.swift`: Embedded transparent Quick Add Bar with focus edge glow, seamless date capsules, Option+Enter detail shortcut; collapsible "今天已完成 (N) ⌵" group with spring transitions and tactile haptics; refined achievement empty state with ultra-light contour sun vector and serene copy.
  - `TaskStore.swift`: Non-breaking addition of `completedTodayTasks` accessor querying tasks completed on current calendar day with due/start date on or before today. Zero schema or serialization modifications to `FocusTask`.
  - `TaskStoreTests.swift`: Unit test verification for `completedTodayTasks`, filter isolation, and reversibility.
  - `./Scripts/package_app.sh`: Automated release compilation, ad-hoc codesigning, and installation to `/Applications/iFocus.app`.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Pure-flat row layout | Remove row stroke borders; apply borderless soft wash (`Color.primary.opacity(0.035..0.055)`) on hover | M1 | Survey 1 / ORIGINAL_REQUEST §1 |
| 2 | Checkbox horizontal alignment | Eliminate 20pt left-jump on completion by keeping a dedicated 20pt leading slot across all rows | M1 | Survey 1 / ORIGINAL_REQUEST §1 |
| 3 | Checkbox vertical alignment | Align checkbox to top with optical offset (~2pt) locked to title text cap-height | M1 | Survey 1 / ORIGINAL_REQUEST §1 |
| 4 | Hover action bar | Expose Focus, Pin, Edit, and Delete (`trash`) flat buttons on hover; remove circular grey fills | M1 | Survey 1 / ORIGINAL_REQUEST §1 |
| 5 | Ultra-muted metadata | Unify metadata icons/labels to quiet opacity (0.50..0.55), warm rose overdue, render line 2 conditionally | M1 | Survey 1 / ORIGINAL_REQUEST §1 |
| 6 | Transparent Quick Add Bar | Strip opaque cardBackground, borders, and drop shadows; blend transparently into background | M2 | Survey 2 / ORIGINAL_REQUEST §2 |
| 7 | Focus edge glow | Delicate 1.0pt stroke + diffuse accent ambient glow (`radius: 8, y: 2`) with spring interactive transition | M2 | Survey 2 / ORIGINAL_REQUEST §2 |
| 8 | Clean input glyphs & buttons | Clean vector `+` glyph; action buttons appear smoothly only when text is entered | M2 | Survey 2 / ORIGINAL_REQUEST §2 |
| 9 | Minimal date capsules | Borderless minimal capsules with micro accent indicator on active state | M2 | Survey 2 / ORIGINAL_REQUEST §2 |
| 10 | Option+Enter detail shortcut | Support `⌥↵` in `.onSubmit` and `.keyboardShortcut(.return, modifiers: [.option])` on detail button | M2 | Survey 2 / ORIGINAL_REQUEST §2 |
| 11 | `completedTodayTasks` query | Query tasks completed today with due/start date on or before today, preserving non-today archiving | M3 | Survey 3 / ORIGINAL_REQUEST §3 |
| 12 | "今天已完成 (N) ⌵" folding section | Collapsible group at bottom of Today list, default collapsed, spring animation and haptic feedback | M3 | Survey 3 / ORIGINAL_REQUEST §3 |
| 13 | Uncheck reversibility | Unchecking task in "今天已完成" restores it immediately to active "今日待办" list | M3 | Survey 3 / ORIGINAL_REQUEST §3 |
| 14 | Quiet achievement empty state | When Today active tasks are 0: delicate contour sun vector, serene copy, completed fold below | M3 | Survey 3 / ORIGINAL_REQUEST §3 |
| 15 | E2E & unit test verification | 100% pass across all 248+ tests and performance benchmarks under latency caps | M4 | ORIGINAL_REQUEST §约束 |
| 16 | App packaging & installation | Execute `./Scripts/package_app.sh` to compile release build and install to `/Applications/iFocus.app` | M4 | ORIGINAL_REQUEST §约束 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Pure-Flat Row & Checkbox Alignment | `TaskRowView.swift`: de-carding, 20pt slot checkbox alignment, top alignment, hover actions (focus/pin/edit/delete), metadata muting | none | DONE |
| M2 | Embedded Quick Add Bar | `TaskListView.swift`: transparent natural-blend bar, focus edge glow, minimal date capsules, `⌥↵` shortcut | none | DONE |
| M3 | Today Completed Section & Achievement Empty State | `TaskStore.swift`, `TaskListView.swift`: `completedTodayTasks` accessor, folding section, reversibility, achievement empty state, unit tests | M1, M2 | DONE |
| M4 | Final E2E Pass, Audit & Packaging | Run full test suite, verify benchmarks, forensic audit, build and package to `/Applications/iFocus.app` | M1, M2, M3 | DONE |

## Interface Contracts
### `TaskRowView` ↔ `TaskStore`
- Delete: `taskStore.deleteTask(task)` triggers soft deletion with undo toast banner.
- Pin: `taskStore.togglePin(for: task)` toggles pinned state.
- Focus: `onStartFocus()` triggers navigation to timer with task context.
- Edit: `onEdit()` presents `EditTaskView` sheet.

### `TaskListView` (Quick Add) ↔ `TaskStore`
- Add: `taskStore.addTask(for: currentFilter, dueOverride: dueOverride) -> UUID?`.
- Detail: If `openEditor: true`, look up task by returned UUID and present `.edit(EditTaskSession(task: task))`.

### `TaskListView` (Today Completed) ↔ `TaskStore`
- Accessor: `var completedTodayTasks: [FocusTask]` returns tasks completed on current calendar day with `(dueDate <= today || startDate <= today)`.
- Reversal: `taskStore.toggleCompletion(for: task)` unchecks completed task, clearing `completedAt` and returning it to active filtering.

## Code Layout
- `Sources/iFocus/Views/Tasks/TaskRowView.swift`: Owned exclusively by Milestone 1.
- `Sources/iFocus/Views/Tasks/TaskListView.swift`: Owned exclusively by Milestone 2 (Quick Add section) then Milestone 3 (Today Completed section & empty states).
- `Sources/iFocus/ViewModels/Tasks/TaskStore.swift`: Owned exclusively by Milestone 3 (`completedTodayTasks`).
- `Tests/iFocusTests/Stores/TaskStoreTests.swift`: Owned exclusively by Milestone 3 (unit tests).
- `Tests/iFocusTests/E2E/`: Owned exclusively by E2E Testing Track.
