# Family Settings And Member Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate family settings from member management while enforcing owner-only member operations and matching the app's circular navigation style.

**Architecture:** Add a `FamilyDetailMode` and centralized `FamilyScreenPermissions` policy. Keep one `FamilyDetailView` data loader, but conditionally compose settings or member-management content and route each profile entry with an explicit mode.

**Tech Stack:** SwiftUI, XCTest, SF Symbols

## Global Constraints

- Modify runtime code only in `ios/OperationsHome/Views/ProfileView.swift` and `ios/OperationsHome/Views/FamilyDetailView.swift`.
- Preserve existing API methods, family refresh, invitation, removal confirmation, and family-name update behavior.
- Member-management entry and operations are owner-only.
- Do not stage unrelated `ItemsView.swift` or Xcode user state changes.

---

### Task 1: Add permission policy

**Files:**
- Modify: `ios/OperationsHome/Views/FamilyDetailView.swift`
- Test: `ios/OperationsHomeTests/APIModelsTests.swift`

- [x] Add failing tests for settings and member-management permissions.
- [x] Add `FamilyDetailMode` and `FamilyScreenPermissions`.
- [x] Run the focused test target.

### Task 2: Route and compose separate modes

**Files:**
- Modify: `ios/OperationsHome/Views/ProfileView.swift`
- Modify: `ios/OperationsHome/Views/FamilyDetailView.swift`

- [x] Route family information to `.settings`.
- [x] Show the `.memberManagement` entry only for `owner`.
- [x] Render family editing only in settings mode.
- [x] Render invitation and removal only in member-management mode.
- [x] Keep the member list read-only in settings mode.

### Task 3: Restyle and verify navigation

- [x] Replace the system back button with `chevron.left.circle.fill`.
- [x] Replace refresh with `arrow.clockwise.circle.fill`.
- [x] Build and inspect both owner pages in the iPhone 16 Pro simulator.
- [x] Run all iOS tests.
- [x] Commit only the target source, test, and documentation files.
