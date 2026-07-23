# Reminder Form Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle reminder form actions, date/time controls, and periodic rule controls to match the app's full-width glass form language.

**Architecture:** Keep all reminder state, scheduling calculations, API payloads, and synchronization behavior in `ReminderFormView`. Recompose only the SwiftUI form with local full-width rows, shared SF Symbol styling, segmented period selection, and circular toolbar actions.

**Tech Stack:** SwiftUI, SwiftData, SF Symbols, XCTest

## Global Constraints

- Modify only `ios/OperationsHome/Views/RemindersView.swift`.
- Preserve existing reminder type switching, repeat values, date calculation, API, sync, and notification behavior.
- Use `xmark.circle.fill` and `checkmark.circle.fill` at `24pt semibold`.
- Use the existing application green and `GlassSection`.
- Preserve Chinese date/time locale and VoiceOver labels.
- Do not stage unrelated changes in `ItemsView.swift` or Xcode user state.

---

### Task 1: Restyle ReminderFormView controls

**Files:**
- Modify: `ios/OperationsHome/Views/RemindersView.swift`
- Test: `ios/OperationsHomeTests/APIModelsTests.swift`

**Interfaces:**
- Consumes: Existing `ReminderFormView` bindings and `GlassSection`
- Produces: `ReminderFormRowIcon`, full-width date/time/menu rows, segmented periodic rule selection, and circular toolbar actions

- [ ] **Step 1: Record the existing behavior baseline**

Run:

```bash
xcodebuild test \
  -project ios/OperationsHome.xcodeproj \
  -scheme OperationsHome \
  -destination 'platform=iOS Simulator,id=AA227D64-1621-4E21-A8DB-33D2DC5F5137' \
  -derivedDataPath .derivedData \
  CODE_SIGNING_ALLOWED=NO
```

Expected: the existing 8 tests pass before UI changes.

- [ ] **Step 2: Replace default form composition**

In `ReminderFormView`, keep the current bindings and show:

```swift
if kind == .periodicTask {
    Picker("周期", selection: $repeatRule) {
        Text("每天").tag(RepeatRule.daily)
        Text("每周").tag(RepeatRule.weekly)
        Text("每月").tag(RepeatRule.monthly)
    }
    .pickerStyle(.segmented)

    ReminderDatePickerRow(
        title: "提醒时间",
        systemImage: "clock",
        selection: $reminderTime,
        displayedComponents: .hourAndMinute
    )
} else {
    ReminderDatePickerRow(
        title: "提醒日期",
        systemImage: "calendar",
        selection: $reminderDate,
        displayedComponents: .date
    )
    ReminderDatePickerRow(
        title: "提醒时间",
        systemImage: "clock",
        selection: $reminderTime,
        displayedComponents: .hourAndMinute
    )
}
```

Use a full-width menu row with a leading SF Symbol for weekly choice and monthly day. Add dividers only between visible rows.

- [ ] **Step 3: Add local reusable rows**

Add a private icon helper and date picker row in `RemindersView.swift`:

```swift
private struct ReminderDatePickerRow: View {
    var title: String
    var systemImage: String
    @Binding var selection: Date
    var displayedComponents: DatePickerComponents

    var body: some View {
        HStack(spacing: 12) {
            ReminderFormRowIcon(systemImage: systemImage)
            DatePicker(title, selection: $selection, displayedComponents: displayedComponents)
                .font(.body.weight(.medium))
                .tint(Color(red: 0.20, green: 0.32, blue: 0.25))
        }
        .frame(minHeight: 52)
        .environment(\.locale, Locale(identifier: "zh_CN"))
    }
}
```

The menu rows use the same icon, minimum height, label weight, trailing green value, and full-width alignment.

- [ ] **Step 4: Replace toolbar text actions**

Use circular icons while preserving the existing save-disabled condition:

```swift
Image(systemName: "xmark.circle.fill")
    .font(.system(size: 24, weight: .semibold))

Image(systemName: "checkmark.circle.fill")
    .font(.system(size: 24, weight: .semibold))
```

Apply the existing green tint and accessibility labels `取消` and `保存`.

- [ ] **Step 5: Remove the duplicate environment declaration**

Keep exactly one:

```swift
@Environment(\.modelContext) private var context
```

- [ ] **Step 6: Build**

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

- [ ] **Step 7: Verify both form states in the simulator**

Install and launch the built app. Confirm:

- Once-only reminders show full-width Chinese date and time rows.
- Periodic reminders show segmented daily/weekly/monthly controls.
- Weekly shows one rule menu; monthly shows one day menu.
- Both states show only circular cancel/save toolbar icons.
- No controls overlap or clip.

- [ ] **Step 8: Run regression tests**

Run the test command from Step 1.

Expected: 8 tests, 0 failures.

- [ ] **Step 9: Commit only reminder files**

```bash
git add \
  docs/superpowers/plans/2026-07-23-reminder-form-controls.md \
  ios/OperationsHome/Views/RemindersView.swift
git commit -m "ui: align reminder form controls"
```
