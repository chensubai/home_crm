# Space Items Screen Style Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the space-filtered item list match the existing Operations Home visual language without changing item business behavior.

**Architecture:** Keep `ItemsView` and its existing `List` so swipe actions remain native. Replace the system navigation bar with a custom header, place the list over `OnboardingBackground`, and restyle each row as a translucent card.

**Tech Stack:** SwiftUI, SwiftData, SF Symbols

## Global Constraints

- Modify only `ios/OperationsHome/Views/ItemsView.swift`.
- Preserve item add, edit, delete, quantity adjustment, sync, and image behavior.
- Preserve accessibility labels for icon-only controls.
- Do not add dependencies.

---

### Task 1: Restyle the space item list

**Files:**
- Modify: `ios/OperationsHome/Views/ItemsView.swift`

**Interfaces:**
- Consumes: `ItemsView.spaceFilter`, `ItemFormView`, `EmptyStateView`, `OnboardingBackground`
- Produces: A custom item-list header and card-styled item rows

- [ ] **Step 1: Replace the system navigation presentation**

Wrap the content in `ZStack`, render `OnboardingBackground`, add a custom header, and hide the navigation bar.

- [ ] **Step 2: Preserve native list behavior**

Keep `List` and swipe actions, then apply `.scrollContentBackground(.hidden)`, clear row backgrounds, hidden separators, and card insets.

- [ ] **Step 3: Add the empty state**

When `items.isEmpty`, render `EmptyStateView` below the custom header.

- [ ] **Step 4: Restyle item controls**

Use rounded white cards, a larger item image, compact status and quantity text, and circular minus/plus buttons.

- [ ] **Step 5: Build**

Run:

```bash
xcodebuild build \
  -project ios/OperationsHome.xcodeproj \
  -scheme OperationsHome \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .derivedData \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Verify in the simulator**

Open a storage space and confirm the custom header, circular buttons, background, empty state or item cards, edit sheet, and add sheet.

- [ ] **Step 7: Run the iOS tests**

Run:

```bash
xcodebuild test \
  -project ios/OperationsHome.xcodeproj \
  -scheme OperationsHome \
  -destination 'platform=iOS Simulator,id=AA227D64-1621-4E21-A8DB-33D2DC5F5137' \
  -derivedDataPath .derivedData \
  CODE_SIGNING_ALLOWED=NO
```

Expected: 8 tests, 0 failures.

- [ ] **Step 8: Commit**

```bash
git add \
  docs/superpowers/specs/2026-07-23-space-items-screen-style-design.md \
  docs/superpowers/plans/2026-07-23-space-items-screen-style.md \
  ios/OperationsHome/Views/ItemsView.swift
git commit -m "ui: align space item list with app style"
```
