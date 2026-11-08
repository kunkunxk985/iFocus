# E2E Test Infrastructure: Things 3 Style Floating Modal & Task Interaction Redesign

## 1. Test Philosophy & Architectural Principles

### 1.1 Opaque-Box & Requirement-Driven Verification
The Things 3 Style Floating Modal & Task Interaction Redesign test infrastructure strictly enforces opaque-box and requirement-driven testing, derived directly from `ORIGINAL_REQUEST.md` (Requirements R1–R5) and `PROJECT.md` (Features 1–17, Milestones M1–M4).
- **Decoupled from Private UI View Tree**: Tests interact through published interface contracts, domain stores (`TaskStore`, `SettingsStore`, `TimerStore`), data models (`FocusTask`, `EditTaskSession`), visual design tokens (`FloatingCardSurfaceModifier`, `FloatingModalShortcutHint`, `FloatingModalCloseButton`, `AppTheme`), and authoritative calculation oracles.
- **Specification-Derived Authoritative Oracles**:
  - **Floating Modal Geometry & Surface**: Continuous squircle curvature (`cornerRadius: 18, style: .continuous`), `.ultraThinMaterial` translucency, 0.75pt specular inner highlight stroke (`AppTheme.cardInnerHighlight`), `.multiLayerShadow(elevation: .popover)`, task modal width (`460pt`), profile modal width (`350pt`), and keyboard shortcut hints (`⌘↵ 保存 · Esc 取消`).
  - **Things 3 Date Capsule Logic & Conversions**: 5 standard preset capsules (`[ 无 ]`, `[ 今天 ]`, `[ 明天 ]`, `[ 稍后 ]`, `[ 自定义日期… ⌵ ]`) with deterministic bidirectional mapping to/from `Date?`, and `M月d日` compact date formatting.
  - **4-Tier Context Menu Hierarchy & Action Dispatching**: Tier 1 Core Focus & Edit (`bolt.fill`, `pencil`), Tier 2 Quick Reschedule & Move (`sun.max`, `sunrise`, `clock`, `tray.and.arrow.down`), Tier 3 Status (`pin`/`pin.slash`, `checkmark.circle`/`circle`), and Tier 4 Utility & Safety (`doc.on.doc`, `trash` with `role: .destructive`).
  - **Inline Note Lightweight Summary**: First non-empty trimmed line extraction, 12pt regular font, 50% opacity (`AppTheme.secondaryText.opacity(0.50)`), `lineLimit(1)`, `truncationMode(.tail)`, and full note exposure via tooltip hover (`.help(task.notes)`).
  - **Profile State Transaction Safety**: Uncommitted changes to avatar photo and color swatches during modal presentation roll back cleanly upon cancel/backdrop-tap/Esc/xmark dismiss.
- **Strict Isolation & Zero Side Effects**: Every test provisions an isolated sandbox filesystem directory (`FileManager.default.temporaryDirectory`), creates dedicated store instances, uses a deterministic Gregorian calendar (UTC), and cleans up all resources on `tearDownWithError`.

### 1.2 Four-Tier Testing Pyramid
The test suite implements an exhaustive four-tier structure adhering to Dual-Track E2E Quality Standards:
1. **Tier 1 — Feature Coverage**: Isolated unit and functional verification of each redesign capability across M1–M3 (Floating modal surfaces, Date capsules, 4-tier context menu, Inline note summary, Profile modal state).
2. **Tier 2 — Boundary & Corner Cases**: Comprehensive edge condition stress testing (empty notes, whitespace/newline notes, multi-line trailing newlines, extreme line lengths, valid vs invalid URL schemes, leap year Feb 29, year rollover Dec 31 to Jan 01, uncommitted profile state rollbacks, empty task title validation).
3. **Tier 3 — Cross-Feature Interactions**: Multi-module pairwise interaction testing (task rescheduling with note retention, modal editing save with live ticking focus timer preservation, context menu pin + complete list sort order, EditTaskSession snapshot isolation, and clipboard copy with task reproduction).
4. **Tier 4 — Real-World Application Scenarios**: Complete multi-step end-to-end user journeys (full lifecycle from task creation -> context menu reschedule -> note inspection -> floating modal editing -> timer focus -> completion; and multi-task backlog triage workflow).

---

## 2. Requirement Coverage Matrix (R1–R4 across Tiers 1–4)

| Requirement | Scope & Feature Summary | Tier 1 (Feature) | Tier 2 (Boundary) | Tier 3 (Cross-Feature) | Tier 4 (Real-World) | Total Tests |
|---|---|:---:|:---:|:---:|:---:|:---:|
| **R1** | **Floating Card Task Editing Modal**<br>• 460pt floating squircle container (`cornerRadius: 18`)<br>• 0.75pt inner highlight & popover shadow<br>• Things 3 date capsule presets (`[ 无 ]`, `[ 今天 ]`, `[ 明天 ]`, `[ 稍后 ]`, `[ 自定义日期… ]`)<br>• Borderless 16pt title input & embedded cards<br>• URL validation (http/https) & clickable link | 11 tests | 6 tests | 2 tests | 2 tests | **21 tests** |
| **R2** | **Profile Editing Floating Modal**<br>• 350pt floating squircle container (`cornerRadius: 18`)<br>• Capsule nickname input with `person.fill`<br>• 24pt swatches in recessed pill tray<br>• Top-right `xmark` dismiss & shortcut hints<br>• Safe uncommitted avatar state rollback | 5 tests | 2 tests | 1 test | 2 tests | **10 tests** |
| **R3** | **Task Row 4-Tier Native Context Menu**<br>• Tier 1: 立即开启专注 (`bolt.fill`), 编辑任务… (`pencil`)<br>• Tier 2: 今天 (`sun.max`), 明天 (`sunrise`), 稍后 (`clock`), 收集箱 (`tray.and.arrow.down`)<br>• Tier 3: 置顶/取消置顶 (`pin`/`pin.slash`), 标记完成/未完成 (`checkmark.circle`/`circle`)<br>• Tier 4: 复制标题 (`doc.on.doc`), 破坏性删除 (`trash`) | 6 tests | 1 test | 2 tests | 2 tests | **11 tests** |
| **R4** | **Inline Note Lightweight Summary**<br>• Extraction of first non-empty trimmed line<br>• 12pt secondary text at 50% opacity (`lineLimit(1)`)<br>• Nil on empty/whitespace-only notes<br>• Full note preserved in hover tooltip | 6 tests | 3 tests | 2 tests | 2 tests | **13 tests** |
| **R5** | **Zero Breaking Changes & Zero Regression**<br>• Backward compatible `FocusTask` & `EditTaskSession`<br>• `tasks.json` storage stability<br>• 100% pass of baseline 501 tests + new E2E tests | — | — | — | — | **All Tests** |

---

## 3. Test Architecture & Harness Design

```
Tests/iFocusTests/Things3FloatingModalE2ETests.swift
├── Design Specification Oracle (Things3FloatingModalDesignSpec)
│   ├── Modal Surface Metrics (taskModalWidth: 460pt, profileModalWidth: 350pt, cornerRadius: 18pt)
│   ├── Stroke & Shadow Constants (innerHighlight: 0.75pt, popover elevation tokens)
│   ├── Typography Tokens (title: 16pt, inlineNote: 12pt, inlineNoteOpacity: 0.50)
│   ├── Things 3 Date Presets (无, 今天, 明天, 稍后, 自定义日期…)
│   ├── 4-Tier Context Menu Actions & SF Symbols
│   └── Keyboard Shortcut Contracts ("⌘↵ 保存 · Esc 取消")
├── Query & Algorithm Oracle (Things3FloatingModalTestHarness)
│   ├── Deterministic UTC Gregorian Calendar
│   ├── Date Capsule Preset Classifier & Date Resolver
│   ├── Custom Date Label Formatter ("M月d日")
│   ├── Inline Note First-Line Extractor
│   ├── Valid URL Scheme Verifier (http / https)
│   ├── Context Menu Action Dispatch Simulator
│   └── Profile Transaction State Rollback Verifier
└── Test Suites
    ├── Tier 1: Feature Coverage (28 tests)
    │   ├── Feature 1: Floating Card Modal Surface Tokens (6 tests)
    │   ├── Feature 2: Things 3 Date Capsules Logic & Conversions (6 tests)
    │   ├── Feature 3: 4-Tier Native Context Menu Structure & Dispatching (6 tests)
    │   ├── Feature 4: Inline Note First Line Extraction & Formatting (6 tests)
    │   └── Feature 5: Profile Editing Modal State Management (4 tests)
    ├── Tier 2: Boundary & Corner Cases (13 tests)
    │   ├── Empty / whitespace-only notes
    │   ├── Multi-line trailing newlines & carriage returns (\r\n)
    │   ├── Extreme length first lines
    │   ├── Valid HTTP/HTTPS URLs vs invalid schemes (ftp, javascript, file, mailto)
    │   ├── Custom date leap year (Feb 29) & year rollover (Dec 31 -> Jan 01)
    │   ├── Uncommitted profile state discards & rollbacks
    │   └── Empty task title validation in editor
    ├── Tier 3: Cross-Feature Interactions (5 tests)
    │   ├── Rescheduling across lists while retaining notes, links, and priority
    │   ├── Modal save preserving live active focus timer session
    │   ├── Context menu pin + complete list sort order & filter stability
    │   ├── EditTaskSession snapshot decoupling from live TaskStore background changes
    │   └── Inline note extraction with clipboard title copy & task reproduction
    └── Tier 4: Real-World Scenarios (2 tests)
        ├── Complete task lifecycle: Quick Add -> Context Menu Reschedule -> Note Review -> Modal Edit -> Focus -> Completion
        └── Multi-task backlog triage: Batch creation, 4-tier context triage, link inspection, undo deletion, and profile customization
```

---

## 4. Verification Methods & Commands

### Running the New E2E Suite
```bash
swift test --filter Things3FloatingModalE2ETests
```

### Running Full Project Regression (Baseline 501 + New Tests)
```bash
swift test --disable-sandbox
```

---

## 5. Quality Invariants & Exit Criteria
1. **Zero Failures**: 100% of tests pass cleanly (0 unexpected failures, 0 regressions).
2. **Deterministic Reproducibility**: Zero flaky tests; all date and string calculations run with fixed calendars and temporary isolated sandboxes.
3. **Zero Implementation Modifications**: Authored strictly within `Tests/iFocusTests/` without altering production code in `Sources/`.
