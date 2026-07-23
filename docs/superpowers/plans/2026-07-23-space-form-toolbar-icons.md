# Space Form Toolbar Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the space form's text-only cancel and save actions with icon-only native iOS toolbar buttons.

**Architecture:** Keep the existing `SpaceFormView` toolbar placements and actions. Change only each button label to an SF Symbol image, preserve the current save validation, and add explicit accessibility labels.

**Tech Stack:** SwiftUI, SF Symbols, XCTest/Xcode build tooling

## Global Constraints

- Modify only the shared space add/edit form.
- Use `xmark` for cancel and `checkmark` for save.
- Display no visible button text.
- Preserve the current save-disabled condition.
- Preserve VoiceOver labels “取消” and “保存”.
- Add no dependencies or reusable abstractions for this single-use visual change.

---

### Task 1: Replace Space Form Toolbar Text With Icons

**Files:**
- Modify: `ios/OperationsHome/Views/SpacesView.swift:456-462`

**Interfaces:**
- Consumes: Existing `dismiss()`, `save()`, `name`, and `session.selectedFamilyId`.
- Produces: Icon-only cancellation and confirmation toolbar buttons with unchanged behavior.

- [ ] **Step 1: Replace the toolbar button labels**

Update the existing toolbar block to:

```swift
.toolbar {
    ToolbarItem(placement: .cancellationAction) {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
        }
        .accessibilityLabel("取消")
    }
    ToolbarItem(placement: .confirmationAction) {
        Button {
            Task { await save() }
        } label: {
            Image(systemName: "checkmark")
        }
        .accessibilityLabel("保存")
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.selectedFamilyId == nil)
    }
}
```

- [ ] **Step 2: Build the iOS app**

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

- [ ] **Step 3: Verify the visible toolbar behavior**

Launch the app in the iPhone 16 Pro simulator, open the space tab, tap the add button, and verify:

- Left toolbar action shows only `xmark`.
- Right toolbar action shows only `checkmark`.
- The checkmark is disabled until a space name is entered.
- The xmark dismisses the form.

- [ ] **Step 4: Commit**

```bash
git add ios/OperationsHome/Views/SpacesView.swift
git commit -m "ui: use icons for space form actions"
```
