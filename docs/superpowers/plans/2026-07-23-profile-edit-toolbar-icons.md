# Profile Edit Toolbar Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace text cancellation and confirmation actions in personal profile and family-name editing with the app's circular toolbar icons.

**Architecture:** Keep both forms and their save functions unchanged. Replace only the SwiftUI toolbar button labels and add matching tint and accessibility labels.

**Tech Stack:** SwiftUI, SF Symbols, XCTest

## Global Constraints

- Modify runtime code only in `ios/OperationsHome/Views/ProfileEditView.swift` and `ios/OperationsHome/Views/FamilyDetailView.swift`.
- Do not change invite, member-removal, profile update, family update, or validation behavior.
- Do not stage unrelated `ItemsView.swift` or Xcode user state changes.

---

### Task 1: Unify profile editing toolbar actions

**Files:**
- Modify: `ios/OperationsHome/Views/ProfileEditView.swift`
- Modify: `ios/OperationsHome/Views/FamilyDetailView.swift`

**Interfaces:**
- Consumes: Existing `dismiss()`, `save()`, `isSaving`, and name validation
- Produces: Circular cancellation and confirmation toolbar buttons

- [ ] Replace each text cancellation action with `xmark.circle.fill` at `24pt semibold`.
- [ ] Replace each text confirmation action with `checkmark.circle.fill` at `24pt semibold`.
- [ ] Apply `Color(red: 0.20, green: 0.32, blue: 0.25)` and accessibility labels.
- [ ] Preserve each existing disabled condition.
- [ ] Build for the generic iOS Simulator.
- [ ] Check both editing sheets in the iPhone 16 Pro simulator.
- [ ] Run the existing 8 iOS tests.
- [ ] Commit only the two source files and these documents.
