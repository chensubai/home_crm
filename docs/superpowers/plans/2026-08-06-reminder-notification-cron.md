# 提醒通知与 Cron Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让一次性、周期和物品保质期提醒通过 iOS 本地通知提前触发，并启用服务端 Laravel Scheduler 做每小时校正。

**Architecture:** iOS 在现有 `NotificationScheduler` 中统一计算提前量：`item_expiry` 提前 2 天，其余提前 30 分钟；服务端新增幂等 Artisan 命令并注册每小时调度，命令只查询有效提醒并记录结果，不发送推送。

**Tech Stack:** Swift/UIKit UserNotifications、XCTest、Laravel Artisan、Laravel Scheduler、PHPUnit。

## Global Constraints

- 普通/周期提醒提前 30 分钟，`item_expiry` 提前 2 天。
- iOS 使用设备当前时区，服务端继续以 UTC 序列化。
- 已禁用、已完成、已删除或通知时间已过去的提醒不注册。
- 不引入 APNs、设备 token 或新的通知表。
- cron 通过系统每分钟调用 `php artisan schedule:run`，Laravel 每小时实际运行命令。

### Task 1: iOS 提前通知计算

**Files:**
- Modify: `ios/OperationsHome/Services/NotificationScheduler.swift`
- Test: `ios/OperationsHomeTests/NotificationSchedulerTests.swift`

**Interfaces:**
- Consumes: `ReminderRecord.kind`, `remindAt`, `repeatRule`, `isEnabled`, `completedAt`, `deletedAt`。
- Produces: `NotificationScheduler.schedules(for:)` 返回已应用提前量的 `NotificationSchedule`。

- [ ] **Step 1: Write failing tests**

在现有 scheduler 测试中增加普通提醒的组件断言（目标 10:00 → 09:30）和 `itemExpiry`（目标 2026-08-10 10:00 → 2026-08-08 10:00），同时断言已过提前时间的一次性提醒为空。

- [ ] **Step 2: Run focused tests and verify failure**

Run: `xcodebuild test -project ios/OperationsHome.xcodeproj -scheme OperationsHome -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OperationsHomeTests/NotificationSchedulerTests`

Expected: 新增时间组件断言失败，因为当前调度使用原始 `remindAt` 且未区分 `item_expiry`。

- [ ] **Step 3: Implement minimal calculation**

在 `schedules(for:)` 开头计算 `leadTime`，使用 `Calendar.date(byAdding:)` 得到 `notificationDate`；一次性规则用该日期生成完整组件，重复规则用该日期的时间组件和周期组件。若一次性 `notificationDate <= .now` 返回空数组，周期规则仍允许未来重复触发。

- [ ] **Step 4: Run focused tests and verify pass**

重复执行上述 `xcodebuild test`，预期全部通过，并确认现有 weekly identifier 测试不变。

- [ ] **Step 5: Commit**

```bash
git add ios/OperationsHome/Services/NotificationScheduler.swift ios/OperationsHomeTests/NotificationSchedulerTests.swift
git commit -m "feat: schedule reminder notifications in advance"
```

### Task 2: 服务端 Artisan 命令与 Scheduler

**Files:**
- Create: `server/app/Console/Commands/ReconcileReminderNotifications.php`
- Modify: `server/routes/console.php`
- Test: `server/tests/Feature/ReminderNotificationScheduleTest.php`

**Interfaces:**
- Produces command: `reminders:reconcile-notifications`。
- Produces schedule: `Schedule::command('reminders:reconcile-notifications')->hourly()`。

- [ ] **Step 1: Write failing tests**

测试创建有效、关闭、完成和软删除提醒，调用 Artisan 命令并断言命令成功、输出有效提醒数量；再检查 `app()->make(Schedule::class)->events()` 中存在该命令且表达式为 hourly。测试使用现有 TestCase、RefreshDatabase 和工厂/模型创建方式。

- [ ] **Step 2: Run focused tests and verify failure**

Run: `cd server && php artisan test --filter=ReminderNotificationScheduleTest`

Expected: 命令不存在或 scheduler event 不存在而失败。

- [ ] **Step 3: Implement command and registration**

命令查询 `Reminder::query()->where('is_enabled', true)->whereNull('completed_at')->get()`，由于软删除模型默认排除删除项；输出 `Reconciled N active reminders.` 并捕获单条处理异常后记录 `report($e)`、继续执行。将命令闭包/类注册到 `routes/console.php`，并调用 `$schedule->command(...)->hourly()`。

- [ ] **Step 4: Run focused tests and verify pass**

Run: `cd server && php artisan test --filter=ReminderNotificationScheduleTest`，预期 PASS；再运行 `php artisan schedule:list`，确认命令显示 hourly。

- [ ] **Step 5: Commit**

```bash
git add server/app/Console/Commands/ReconcileReminderNotifications.php server/routes/console.php server/tests/Feature/ReminderNotificationScheduleTest.php
git commit -m "feat: add reminder notification reconciliation schedule"
```

### Task 3: 全量验证与部署说明

**Files:**
- Modify: `docs/deployment.md`
- Modify: `docs/api.md`

- [ ] **Step 1: Document production cron**

补充每分钟执行 `cd /path/to/server && php artisan schedule:run >> /dev/null 2>&1`，说明 Laravel 每小时运行提醒校正命令，以及 iOS 本地通知需要用户授权。

- [ ] **Step 2: Run full test suites**

Run: `cd server && php artisan test`; then run the iOS `xcodebuild test` command without `-only-testing`。预期服务端和 iOS 测试均通过。

- [ ] **Step 3: Review changed files**

Run: `git diff --check` and `git status --short`; ensure only this feature's source, tests, and docs are changed, preserving unrelated existing user edits.

