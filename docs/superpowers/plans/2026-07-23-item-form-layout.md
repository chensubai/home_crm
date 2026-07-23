# Item Form Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the visually fragmented item form with aligned full-width glass sections and circular toolbar actions.

**Architecture:** Keep all existing `ItemFormView` state and save behavior. Change only its view composition, introduce one local full-width text-row component, and retain native Pickers, Stepper, Toggle, DatePicker, scanner, and image input.

**Tech Stack:** SwiftUI, SwiftData, SF Symbols

## Global Constraints

- Modify only `ios/OperationsHome/Views/ItemsView.swift`.
- Do not change API payloads, validation, sync, scanner, or image upload behavior.
- Use `xmark.circle.fill` and `checkmark.circle.fill` at `24pt semibold`.
- Preserve VoiceOver labels.

---

### Task 1: Rebuild ItemFormView layout

**Files:**
- Modify: `ios/OperationsHome/Views/ItemsView.swift`

**Interfaces:**
- Consumes: Existing `ItemFormView` state, `GlassSection`, `ImageInputView`
- Produces: Full-width grouped form rows and circular toolbar controls

- [ ] **Step 1: Add a full-width text row**

Create a local `ItemFormTextRow` that renders an SF Symbol, title, and `TextField` without its own outer card.

- [ ] **Step 2: Recompose the form sections**

Build four `GlassSection` groups for basic information, storage and inventory, expiry and notes, and barcode and image.

- [ ] **Step 3: Stabilize native controls**

Place Pickers, Stepper, Toggle, and DatePicker in full-width rows with consistent minimum heights and dividers.

- [ ] **Step 4: Replace toolbar text**

Use circular SF Symbols for cancellation and confirmation while preserving labels and disabled state.

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

Open the add-item sheet and confirm full-width rows, circular toolbar icons, space preselection, save-disabled state, scrolling, scanner entry, and image controls.

- [ ] **Step 7: Run tests**

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
  docs/superpowers/specs/2026-07-23-item-form-layout-design.md \
  docs/superpowers/plans/2026-07-23-item-form-layout.md \
  ios/OperationsHome/Views/ItemsView.swift
git commit -m "ui: reorganize item form layout"
```
