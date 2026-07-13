# 运营小家 App 交互补全 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让个人中心、家庭成员、空间、物品和提醒中已经展示的入口都能真实查看、编辑、启停或删除。

**Architecture:** Laravel 继续作为家庭权限和数据真值来源，SwiftData 保存当前家庭的本地镜像。新增后端接口先通过 Feature Test 固定权限和响应结构，iOS 再补 DTO、APIClient 和可复用的新增/编辑表单；提醒启停同时更新云端字段和 iOS 本地通知。

**Tech Stack:** SwiftUI、SwiftData、UserNotifications、XCTest、Laravel、Sanctum、MySQL、PHPUnit、七牛云 PHP SDK、Docker Compose、XcodeGen。

## Global Constraints

- iOS 最低版本保持 iOS 17.0，Swift 保持 5.10。
- 保持现有玻璃风格和三项底部标签栏，不重做视觉系统。
- 空间仍是物品必填项；非空空间不允许删除。
- Owner 可以修改家庭和管理成员，Member 只读。
- 所有新增数据库字段必须带中文字段备注，现有表备注保持完整。
- 图片上传前继续压缩到不超过 5 MB；更新时未选择新图片则保留旧图。
- 本轮不实现所有权转让、APNs、NFC 实际扫描和语音录入。

---

### Task 1: 后端个人资料与家庭成员接口

**Files:**
- Create: `server/database/migrations/2026_07_13_000000_add_avatar_fields_to_users.php`
- Create: `server/app/Http/Controllers/ProfileController.php`
- Modify: `server/app/Models/User.php`
- Modify: `server/app/Models/Family.php`
- Modify: `server/app/Http/Controllers/FamilyController.php`
- Modify: `server/app/Services/QiniuStorage.php`
- Modify: `server/routes/api.php`
- Modify: `server/database/migrations/2026_06_16_010000_add_comments_to_operations_home_tables.php`
- Test: `server/tests/Feature/OperationsHomeApiTest.php`

**Interfaces:**
- Produces: `GET /api/auth/me -> UserDTO`
- Produces: `PATCH /api/profile` and multipart `POST /api/profile` with `_method=PATCH`
- Produces: `PATCH /api/families/{family}`
- Produces: `GET /api/families/{family}/members`
- Produces: `DELETE /api/families/{family}/members/{member}`
- Produces: family list objects shaped as `{id, name, role}`

- [ ] **Step 1: Write failing profile and family permission tests**

Add tests that exercise the public contract before adding routes:

```php
public function test_user_can_refresh_and_update_profile_with_avatar(): void
{
    $this->app->instance(QiniuStorage::class, new class extends QiniuStorage {
        public function uploadAvatar(UploadedFile $file, int $userId): array
        {
            return [
                'key' => "users/{$userId}/avatar/fake.png",
                'hash' => 'avatar-hash',
                'url' => "https://cdn.example.com/users/{$userId}/avatar/fake.png",
            ];
        }

        public function url(string $key): string
        {
            return 'https://cdn.example.com/'.$key;
        }
    });

    [$user, $token] = $this->login('13800000010');

    $this->withToken($token)->getJson('/api/auth/me')
        ->assertOk()
        ->assertJsonPath('data.id', $user->id)
        ->assertJsonPath('data.phone', '13800000010');

    $this->withToken($token)->post('/api/profile', [
        '_method' => 'PATCH',
        'name' => '新的昵称',
        'avatar' => $this->fakePngUpload(),
    ], ['Accept' => 'application/json'])
        ->assertOk()
        ->assertJsonPath('data.name', '新的昵称')
        ->assertJsonPath('data.avatar_hash', 'avatar-hash');
}

public function test_only_owner_can_update_family_and_remove_member(): void
{
    [$owner, $ownerToken] = $this->login('13800000011');
    [$member, $memberToken] = $this->login('13800000012');

    $familyId = $this->withToken($ownerToken)
        ->postJson('/api/families', ['name' => '原家庭名'])
        ->assertCreated()
        ->assertJsonPath('data.role', 'owner')
        ->json('data.id');

    $membership = \App\Models\Family::findOrFail($familyId)->members()->create([
        'user_id' => $member->id,
        'role' => 'member',
    ]);

    $this->withToken($memberToken)
        ->patchJson("/api/families/{$familyId}", ['name' => '越权修改'])
        ->assertForbidden();

    $this->withToken($ownerToken)
        ->patchJson("/api/families/{$familyId}", ['name' => '新家庭名'])
        ->assertOk()
        ->assertJsonPath('data.name', '新家庭名');

    $this->withToken($ownerToken)
        ->getJson("/api/families/{$familyId}/members")
        ->assertOk()
        ->assertJsonFragment([
            'id' => $membership->id,
            'user_id' => $member->id,
            'phone' => $member->phone,
            'role' => 'member',
        ]);

    $this->withToken($ownerToken)
        ->deleteJson("/api/families/{$familyId}/members/{$membership->id}")
        ->assertOk();
}
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
docker compose exec -T api ./vendor/bin/phpunit --filter '/test_user_can_refresh_and_update_profile_with_avatar|test_only_owner_can_update_family_and_remove_member/'
```

Expected: FAIL because `/api/auth/me`, `/api/profile`, family update and member delete routes do not exist.

- [ ] **Step 3: Add avatar columns with comments**

Create the migration with nullable `avatar_key` length 500, `avatar_url` length 1000 and `avatar_hash` length 120. Each column must use these comments:

```php
$table->string('avatar_key', 500)->nullable()->after('name')->comment('七牛云用户头像对象 key');
$table->string('avatar_url', 1000)->nullable()->after('avatar_key')->comment('用户头像访问地址');
$table->string('avatar_hash', 120)->nullable()->after('avatar_url')->comment('七牛云用户头像 hash');
```

Add the same three entries to the `users` section of the comments migration. Add all three fields to `User::$fillable`.

- [ ] **Step 4: Implement profile APIs using the existing Qiniu SDK service**

Add a dedicated avatar method without changing existing family image keys:

```php
public function uploadAvatar(UploadedFile $file, int $userId): array
{
    return $this->uploadToKeyPrefix($file, sprintf('users/%d/avatar', $userId));
}
```

Move the common SDK upload body into private `uploadToKeyPrefix(UploadedFile $file, string $prefix): array`; `uploadImage()` passes `families/{familyId}/{directory}` and `uploadAvatar()` passes `users/{userId}/avatar`.

Implement `ProfileController::show()` and `ProfileController::update()` with these validation rules:

```php
'name' => ['sometimes', 'required', 'string', 'max:80'],
'avatar' => ['nullable', 'image', 'max:10240'],
```

When an avatar is uploaded, store `avatar_key`, `avatar_url`, and `avatar_hash`; when returning a private-space avatar, refresh `avatar_url` through `QiniuStorage::url($user->avatar_key)`.

- [ ] **Step 5: Implement owner-only family mutation and normalized responses**

Add these controller methods:

```php
public function update(Request $request, Family $family)
public function removeMember(Request $request, Family $family, FamilyMember $member)
```

`update()` calls `authorizeFamily(..., 'owner')`, validates required `name`, updates the family and returns `{id, name, role: owner}`. `removeMember()` verifies `$member->family_id === $family->id`, rejects `$member->role === 'owner'` with HTTP 422, then deletes the membership.

Normalize family list and member list responses to these shapes:

```php
['id' => $family->id, 'name' => $family->name, 'role' => $family->pivot->role]
['id' => $member->id, 'family_id' => $member->family_id, 'user_id' => $member->user_id,
 'name' => $member->user->name, 'phone' => $member->user->phone, 'role' => $member->role]
```

- [ ] **Step 6: Register routes and verify GREEN**

Register:

```php
Route::get('/auth/me', [ProfileController::class, 'show']);
Route::patch('/profile', [ProfileController::class, 'update']);
Route::patch('/families/{family}', [FamilyController::class, 'update']);
Route::delete('/families/{family}/members/{member}', [FamilyController::class, 'removeMember']);
```

Re-run the focused tests. Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add server/app server/routes/api.php server/database/migrations server/tests/Feature/OperationsHomeApiTest.php
git commit -m "feat: add profile and family management APIs"
```

---

### Task 2: 后端库存编辑安全性与提醒启停

**Files:**
- Create: `server/database/migrations/2026_07_13_010000_add_is_enabled_to_reminders.php`
- Modify: `server/app/Models/Reminder.php`
- Modify: `server/app/Models/StorageSpace.php`
- Modify: `server/app/Http/Controllers/SpaceController.php`
- Modify: `server/app/Http/Controllers/ItemController.php`
- Modify: `server/app/Http/Controllers/ReminderController.php`
- Modify: `server/app/Http/Controllers/SyncController.php`
- Modify: `server/database/migrations/2026_06_16_010000_add_comments_to_operations_home_tables.php`
- Test: `server/tests/Feature/OperationsHomeApiTest.php`

**Interfaces:**
- Produces: spaces with flattened nullable `nfc_uid`
- Produces: reminder JSON with boolean `is_enabled`
- Guarantees: item space belongs to the same family
- Guarantees: quantity adjustment never produces a negative quantity
- Guarantees: a space with active items returns HTTP 422 on delete

- [ ] **Step 1: Write failing inventory and reminder tests**

Add one test that creates a family, two spaces, one item and one reminder, then verifies:

```php
$this->withToken($token)->patchJson("/api/spaces/{$spaceId}", [
    'name' => '更新后的柜子',
    'description' => '客厅北侧',
    'nfc_uid' => 'nfc-updated',
])->assertOk()->assertJsonPath('data.nfc_uid', 'nfc-updated');

$this->withToken($token)->deleteJson("/api/spaces/{$spaceId}")
    ->assertStatus(422)
    ->assertJsonPath('message', '空间内仍有物品，请先移动或删除物品');

$this->withToken($token)->postJson("/api/items/{$itemId}/adjust", ['delta' => -99])
    ->assertOk()
    ->assertJsonPath('data.quantity', 0);

$this->withToken($token)->patchJson("/api/reminders/{$reminderId}", [
    'title' => '暂停的提醒',
    'is_enabled' => false,
])->assertOk()
    ->assertJsonPath('data.is_enabled', false);
```

Also create a space in another family and assert that assigning an item to that space returns HTTP 422.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
docker compose exec -T api ./vendor/bin/phpunit --filter test_inventory_updates_and_reminder_toggle_are_safe
```

Expected: FAIL because `nfc_uid` is not returned, non-empty spaces can be deleted, quantity can become negative, and `is_enabled` does not exist.

- [ ] **Step 3: Add `reminders.is_enabled` with a field comment**

Create a boolean column after `repeat_value`:

```php
$table->boolean('is_enabled')->default(true)->after('repeat_value')->comment('提醒是否启用：1=启用，0=停用');
```

Add `is_enabled` to the reminder model fillable/casts, controller validation (`sometimes|boolean`), sync push whitelist, and the comments migration.

- [ ] **Step 4: Flatten and update NFC data**

In `SpaceController`, accept nullable `nfc_uid` in update. Load the space's first NFC tag with `withTrashed()`. When `nfc_uid` is empty, soft-delete the current tag. When it is non-empty, validate that the same UID is not bound to another tag in this family, update the current row and call `restore()` when necessary; create a row only when this space has never had a tag. This avoids violating the existing unique index after clearing and re-binding a UID.

Before returning a space, load `nfcTags` and set:

```php
$space->setAttribute('nfc_uid', $space->nfcTags->first()?->uid);
```

This same response mapping must be used by index, store, update and sync pull.

- [ ] **Step 5: Protect space deletion and item family isolation**

Before deleting a space:

```php
if (Item::query()->where('space_id', $space->id)->whereNull('deleted_at')->exists()) {
    return $this->fail('空间内仍有物品，请先移动或删除物品', 422);
}
```

After validating an item create/update payload, verify that its `space_id` resolves to a non-deleted `StorageSpace` whose `family_id` equals the item's family. Throw a validation error on `space_id` when it does not.

- [ ] **Step 6: Make quantity adjustment atomic and non-negative**

Replace `increment()` with a database transaction and row lock. Compute:

```php
$after = max(0, $before + (int) $data['delta']);
$actualDelta = $after - $before;
```

Save `$after` to the item and write `$actualDelta` to `item_changes.delta`. Return the refreshed item with its signed private image URL.

- [ ] **Step 7: Run tests and commit**

Run the focused test, then the full backend suite:

```bash
docker compose exec -T api ./vendor/bin/phpunit
```

Expected: all tests PASS.

```bash
git add server/app server/database/migrations server/tests/Feature/OperationsHomeApiTest.php
git commit -m "feat: support safe inventory edits and reminder toggles"
```

---

### Task 3: iOS API 合约、会话持久化与单元测试基础

**Files:**
- Modify: `ios/project.yml`
- Modify: `ios/OperationsHome/Networking/APIModels.swift`
- Modify: `ios/OperationsHome/Networking/APIClient.swift`
- Modify: `ios/OperationsHome/Models/LocalModels.swift`
- Modify: `ios/OperationsHome/Sync/SyncEngine.swift`
- Create: `ios/OperationsHomeTests/APIModelsTests.swift`
- Create: `ios/OperationsHomeTests/SessionStoreTests.swift`

**Interfaces:**
- Produces: cached `SessionStore.user`
- Produces: `UserDTO.avatarUrl`, `FamilyDTO.role`, `FamilyMemberDTO`, `FamilyInviteDTO`
- Produces: `SpaceDTO.nfcUid`, `ReminderDTO.isEnabled`
- Produces: APIClient methods consumed by Tasks 4-6

- [ ] **Step 1: Add the unit test target**

Append to `ios/project.yml`:

```yaml
  OperationsHomeTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - OperationsHomeTests
    dependencies:
      - target: OperationsHome
```

Run `cd ios && xcodegen generate` so the test target is present.

- [ ] **Step 2: Write failing DTO and session persistence tests**

`APIModelsTests` decodes exact representative payloads and asserts:

```swift
XCTAssertEqual(family.role, "owner")
XCTAssertEqual(member.phone, "13800000012")
XCTAssertEqual(space.nfcUid, "nfc-updated")
XCTAssertFalse(reminder.isEnabled)
```

`SessionStoreTests` is annotated `@MainActor` and uses an isolated defaults suite:

```swift
func testUserSurvivesSessionStoreRecreation() {
    let suite = "SessionStoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)

    var store: SessionStore? = SessionStore(defaults: defaults)
    store?.user = UserDTO(id: 9, phone: "13800000019", name: "小佳", avatarKey: nil, avatarUrl: nil, avatarHash: nil)
    store = nil

    let restored = SessionStore(defaults: defaults)
    XCTAssertEqual(restored.user?.id, 9)
    XCTAssertEqual(restored.user?.name, "小佳")
}
```

- [ ] **Step 3: Run tests and verify RED**

Run:

```bash
xcodebuild -project ios/OperationsHome.xcodeproj -scheme OperationsHome -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' -derivedDataPath /Users/dev/code/home_crm/.derivedData CODE_SIGNING_ALLOWED=NO test
```

Expected: FAIL because the DTO fields and injectable/persistent `SessionStore` initializer do not exist.

- [ ] **Step 4: Extend DTO and local model contracts**

Add optional avatar fields to `UserDTO`, required `role` to `FamilyDTO`, flattened member/invite DTOs, optional `nfcUid` to `SpaceDTO`, and boolean `isEnabled` to `ReminderDTO` using snake-case coding keys.

Add `isEnabled: Bool` to `ReminderRecord`, defaulting to `true`, and map it in `SyncEngine.upsertReminder()`.

- [ ] **Step 5: Persist and refresh the user**

Change `SessionStore` to accept `UserDefaults`, encode/decode `UserDTO` under `currentUser`, and remove cached user data when the token becomes nil:

```swift
init(defaults: UserDefaults = .standard)
func refreshUser() async
```

`refreshUser()` calls `APIClient(token: token).me()` and replaces the cached DTO. Call it during authenticated app startup without blocking the first screen.

- [ ] **Step 6: Add APIClient mutation methods**

Add these exact methods:

```swift
func me() async throws -> UserDTO
func updateProfile(name: String, avatarData: Data?) async throws -> UserDTO
func updateFamily(id: Int, name: String) async throws -> FamilyDTO
func familyMembers(familyId: Int) async throws -> [FamilyMemberDTO]
func inviteMember(familyId: Int, phone: String?) async throws -> FamilyInviteDTO
func removeMember(familyId: Int, memberId: Int) async throws
func updateSpace(id: Int, name: String, description: String?, nfcUid: String?, imageData: Data?) async throws -> SpaceDTO
func deleteSpace(id: Int) async throws
func updateItem(id: Int, payload: [String: EncodableValue], imageData: Data?) async throws -> ItemDTO
func deleteItem(id: Int) async throws
func updateReminder(id: Int, payload: [String: EncodableValue]) async throws -> ReminderDTO
```

Extend multipart requests with a configurable file field name. For image updates send `POST` with `_method=PATCH`; use field name `avatar` for profile and `image` for spaces/items.

- [ ] **Step 7: Verify GREEN and commit**

Re-run the iOS unit tests. Expected: PASS.

```bash
git add ios/project.yml ios/OperationsHome.xcodeproj ios/OperationsHome ios/OperationsHomeTests
git commit -m "feat: add iOS interaction API contracts"
```

---

### Task 4: 空间和物品完整编辑交互

**Files:**
- Modify: `ios/OperationsHome/Views/ImageInputView.swift`
- Modify: `ios/OperationsHome/Views/SpacesView.swift`
- Modify: `ios/OperationsHome/Views/ItemsView.swift`

**Interfaces:**
- Consumes: `APIClient.updateSpace/deleteSpace/updateItem/deleteItem`
- Produces: space card edit/delete menu
- Produces: tappable item row and swipe delete

- [ ] **Step 1: Record the failing accessibility check**

Run the app in Simulator and inspect the accessibility tree on the space and item screens. Expected failing state: no controls named `编辑空间`, `删除空间`, `编辑物品` or `删除物品` exist.

- [ ] **Step 2: Preserve existing images in edit forms**

Add `existingImageURL: URL? = nil` to `ImageInputView`. Preview priority must be new `imageData`, then `AsyncImage(existingImageURL)`, then the current placeholder. The remove button only clears a newly selected image; this task does not add remote-image deletion.

- [ ] **Step 3: Convert `SpaceFormView` to create/edit mode**

Add `var space: SpaceRecord?` and initialize `@State` from the record. Use title `添加空间` or `编辑空间`; call `createSpace` for nil and `updateSpace` otherwise. On update, assign every returned DTO field, including `nfcUid`, to the existing `SpaceRecord` before pulling sync.

In each grid cell, keep the `NavigationLink` and add a sibling top-trailing `Menu` with buttons labeled `编辑空间` and `删除空间`. Present the form with `.sheet(item: $editingSpace)` and confirm deletion with `.alert`.

- [ ] **Step 4: Convert `ItemFormView` to create/edit mode**

Add `var item: ItemRecord?`, prefill all fields and retain `initialSpaceId` only for create mode. The save branch is:

```swift
if let item {
    let dto = try await client.updateItem(id: item.remoteId, payload: payload, imageData: imageData)
    apply(dto, to: item)
} else {
    let dto = try await client.createItem(payload, imageData: imageData)
    context.insert(makeItem(from: dto))
}
```

Define file-local `makeItem(from dto: ItemDTO) -> ItemRecord` and `apply(_ dto: ItemDTO, to item: ItemRecord)` helpers with all fields from `ItemDTO`. Use `apply` for form save and quantity adjustment so field mapping cannot diverge again.

- [ ] **Step 5: Add item edit and delete actions**

Make the item content area tappable and set `editingItem`; keep plus/minus as independent buttons. Add trailing swipe action `删除物品`, present confirmation, call the delete API, then mark `deletedAt` locally and pull sync. Errors restore the original local state and remain visible.

- [ ] **Step 6: Build and repeat the accessibility check**

Run:

```bash
xcodebuild -project ios/OperationsHome.xcodeproj -scheme OperationsHome -destination 'generic/platform=iOS' -derivedDataPath /Users/dev/code/home_crm/.derivedData CODE_SIGNING_ALLOWED=NO build
```

Expected: `BUILD SUCCEEDED`. In Simulator, all four edit/delete controls now exist and open the correct confirmation or prefilled form.

- [ ] **Step 7: Commit**

```bash
git add ios/OperationsHome/Views/ImageInputView.swift ios/OperationsHome/Views/SpacesView.swift ios/OperationsHome/Views/ItemsView.swift
git commit -m "feat: enable space and item editing"
```

---

### Task 5: 提醒编辑、启停和通知清理

**Files:**
- Modify: `ios/OperationsHome/Services/NotificationScheduler.swift`
- Modify: `ios/OperationsHome/Sync/SyncEngine.swift`
- Modify: `ios/OperationsHome/Views/RemindersView.swift`
- Create: `ios/OperationsHomeTests/NotificationSchedulerTests.swift`

**Interfaces:**
- Consumes: `ReminderRecord.isEnabled`, `APIClient.updateReminder`
- Produces: async `schedule(reminder:)` and `cancel(reminderId:)`
- Produces: tappable reminder row and functional enable toggle

- [ ] **Step 1: Write failing notification schedule tests**

Expose an internal `NotificationSchedule` value and internal pure `schedules(for:)`. Add tests:

```swift
func testDisabledReminderProducesNoSchedules() {
    let reminder = ReminderRecord(remoteId: 7, familyId: 1, title: "缴费", kind: .importantDate,
                                  remindAt: Date().addingTimeInterval(3600), isEnabled: false)
    XCTAssertTrue(NotificationScheduler().schedules(for: reminder).isEmpty)
}

func testWeeklyReminderUsesOneIdentifierPerWeekday() {
    let reminder = ReminderRecord(remoteId: 8, familyId: 1, title: "打扫", kind: .periodicTask,
                                  remindAt: Date().addingTimeInterval(3600), repeatRule: .weekly,
                                  repeatValue: "2,3,4,5,6")
    XCTAssertEqual(NotificationScheduler().schedules(for: reminder).map(\.identifier), [
        "reminder-8-weekday-2", "reminder-8-weekday-3", "reminder-8-weekday-4",
        "reminder-8-weekday-5", "reminder-8-weekday-6",
    ])
}
```

- [ ] **Step 2: Run tests and verify RED**

Run the iOS test command from Task 3. Expected: FAIL because `isEnabled` and accessible schedule generation do not exist.

- [ ] **Step 3: Make notification replacement deterministic**

Implement:

```swift
func cancel(reminderId: Int) async
func schedule(reminder: ReminderRecord) async
```

`cancel` fetches pending requests and removes identifiers equal to `reminder-{id}` or prefixed with `reminder-{id}-`. `schedule` first calls `cancel`, then returns immediately when the reminder is disabled, completed, deleted or an expired one-time reminder; otherwise it adds the newly generated requests.

Make `SyncEngine.rescheduleReminders` async and await schedule for each reminder.

- [ ] **Step 4: Convert reminder form to create/edit mode**

Add `var reminder: ReminderRecord?`, prefill title, kind, date/time, repeat rule/value and notes, and select create or update API by whether the record exists. Before applying an edited reminder, cancel its old requests; after updating local fields, schedule only when `isEnabled` is true.

- [ ] **Step 5: Wire row tap and toggle**

Replace `.constant(isEnabled)` and `.disabled(true)` with a real binding callback. The text/time region opens edit; the switch calls `updateReminder` with only `is_enabled`, updates the local record from the DTO, and awaits notification schedule/cancel. If the API fails, restore the switch and show the error.

Deleting a reminder must call `cancel(reminderId:)` after the API succeeds.

- [ ] **Step 6: Verify tests, build and commit**

Run iOS tests and generic build. Expected: tests PASS and `BUILD SUCCEEDED`.

```bash
git add ios/OperationsHome/Services/NotificationScheduler.swift ios/OperationsHome/Sync/SyncEngine.swift ios/OperationsHome/Views/RemindersView.swift ios/OperationsHomeTests/NotificationSchedulerTests.swift
git commit -m "feat: enable reminder editing and toggles"
```

---

### Task 6: 个人资料与家庭管理界面

**Files:**
- Modify: `ios/OperationsHome/Views/HomeView.swift`
- Modify: `ios/OperationsHome/Views/ProfileView.swift`
- Modify: `ios/project.yml`
- Create: `ios/OperationsHome/Views/ProfileEditView.swift`
- Create: `ios/OperationsHome/Views/FamilyDetailView.swift`

**Interfaces:**
- Consumes: cached `SessionStore.user`
- Consumes: family/member/profile APIClient methods
- Produces: editable profile and owner-aware family detail

- [ ] **Step 1: Record the failing accessibility check**

Inspect the current personal center in Simulator. Expected failing state: `家庭信息` and `成员管理` are text containers, not buttons; there is no `编辑个人资料` control.

- [ ] **Step 2: Implement profile editing**

Make the profile hero and nickname row open `ProfileEditView`. The form contains nickname plus `ImageInputView(existingImageURL:)`, calls `updateProfile`, assigns the returned DTO to `session.user`, and dismisses only on success.

Render the avatar with `AsyncImage` when `avatarUrl` is present and fall back to the first nickname character. Update `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` in `ios/project.yml` to include personal avatars; Task 7 regenerates `Info.plist` through XcodeGen.

- [ ] **Step 3: Implement family detail loading and role state**

Convert both profile action rows into `NavigationLink` values that open `FamilyDetailView` for `session.selectedFamilyId`. On appear, load the current family and members. Display family name, current role and member rows; use `family.role == "owner"` as the only permission switch.

- [ ] **Step 4: Add owner-only family operations**

For Owner, show:

- edit family name sheet calling `updateFamily`;
- invite sheet with optional phone calling `inviteMember`, then display returned code and Chinese-formatted expiry;
- destructive member removal button only for `role == "member"`, with confirmation and `removeMember` call.

For Member, omit all three controls. Both roles can refresh and view members.

- [ ] **Step 5: Refresh Home family names after editing**

Pass an async refresh closure from `HomeView` into `ProfileView`/`FamilyDetailView`. After family rename, reload `families` so the top family picker immediately reflects the new name.

- [ ] **Step 6: Build and verify Simulator interactions**

Run the generic iOS build. Then verify in Simulator that profile editing opens, both action rows navigate, Owner controls appear, and a Member account receives a read-only page.

- [ ] **Step 7: Commit**

```bash
git add ios/project.yml ios/OperationsHome/Views
git commit -m "feat: add profile and family management screens"
```

---

### Task 7: 文档、迁移与端到端验收

**Files:**
- Modify: `docs/api.md`
- Modify: `docs/data-model.md`
- Modify: `README.md`

**Interfaces:**
- Documents: all new endpoints, fields, role rules and image update semantics
- Verifies: backend, database, iOS build, unit tests and live Simulator controls

- [ ] **Step 1: Update API and data model documentation**

Document the exact endpoints from Tasks 1-2, multipart `_method=PATCH`, family role response, normalized member response, `users.avatar_*`, `spaces.nfc_uid`, and `reminders.is_enabled`. Document that deleting a non-empty space returns 422.

- [ ] **Step 2: Regenerate the Xcode project**

Run:

```bash
cd ios
xcodegen generate
```

Expected: project generation succeeds and includes `OperationsHomeTests`.

- [ ] **Step 3: Apply production database migrations**

Run:

```bash
docker compose exec -T api php artisan migrate --force
```

Expected: both `2026_07_13` migrations report `DONE`.

- [ ] **Step 4: Run all automated verification**

Run:

```bash
docker compose exec -T api ./vendor/bin/phpunit
```

```bash
xcodebuild -project ios/OperationsHome.xcodeproj -scheme OperationsHome -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' -derivedDataPath /Users/dev/code/home_crm/.derivedData CODE_SIGNING_ALLOWED=NO test
```

```bash
xcodebuild -project ios/OperationsHome.xcodeproj -scheme OperationsHome -destination 'generic/platform=iOS' -derivedDataPath /Users/dev/code/home_crm/.derivedData CODE_SIGNING_ALLOWED=NO build
```

Expected: PHPUnit PASS, iOS tests PASS, and `BUILD SUCCEEDED`.

- [ ] **Step 5: Complete the live Simulator checklist**

Verify with the existing Docker API:

1. Edit nickname and avatar, relaunch App, and confirm both persist.
2. Rename a family and confirm the top picker changes immediately.
3. Invite a member; confirm Owner can remove that Member and Member cannot see management controls.
4. Edit a space and its image; confirm deleting a non-empty space shows the 422 message.
5. Edit an item, move it to another space, adjust quantity through zero, and left-swipe delete it.
6. Edit one-time, weekly and monthly reminders; turn each off/on and confirm the switch remains correct after refresh.
7. Delete a reminder and confirm no pending notification identifier begins with its remote ID.

- [ ] **Step 6: Check the final diff and commit docs**

Run `git diff --check`; expected: no output.

```bash
git add docs README.md
git commit -m "docs: document completed app interactions"
```
