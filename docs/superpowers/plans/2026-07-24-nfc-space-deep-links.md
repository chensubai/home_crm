# 运营小家 NFC 空间贴纸 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让用户在保存储物空间后把安全的空间链接写入 NFC 贴纸，并在 iPhone 感应贴纸后经过登录和家庭权限校验直达该空间的物品列表。

**Architecture:** Laravel 使用现有 `nfc_tags` 表保存全局唯一随机 Token，并提供幂等创建与鉴权解析接口；SwiftUI 通过 App 级深链路由保存待处理 Token，由主页解析后切换家庭并驱动空间导航。Core NFC 被封装为可替换的写入服务，页面只依赖协议和状态模型，因此 URL、登录续跳和写入状态都可以在模拟器中测试。

**Tech Stack:** Laravel 12、Sanctum、MySQL、PHPUnit、Swift 5.10、SwiftUI、SwiftData、Core NFC、XCTest、XcodeGen。

## Global Constraints

- iOS 最低版本保持 iOS 17.0，Swift 保持 5.10。
- NFC 贴纸只写入 HTTPS Universal Link，不写入自定义 Scheme；`operationshome://` 仅用于模拟器深链测试。
- 当前没有正式域名，不承诺后台 NFC 真机唤起；域名、HTTPS、AASA 和 Associated Domains 就绪后再做最终验收。
- 继续使用现有 `nfc_tags` 表，不新增 NFC 业务表。
- Token 必须不可预测、全局唯一，不使用空间 ID 作为贴纸凭据。
- 服务端始终执行家庭成员权限校验，客户端不得凭本地缓存直接放行。
- 新增空间保存成功后自动展示 NFC 写入页；用户可以跳过，并从编辑空间页重新写入。
- 空间编辑页移除手动输入 `NFC UID` 的控件。
- 页面沿用现有浅色背景、玻璃材质和圆形图标操作。
- 不修改用户尚未提交的 `ios/OperationsHome/Views/ItemsView.swift`。

---

### Task 1: 后端 NFC Token 创建与鉴权解析

**Files:**
- Create: `server/database/migrations/2026_07_24_000000_secure_nfc_tag_tokens.php`
- Create: `server/app/Http/Controllers/NfcController.php`
- Create: `server/config/nfc.php`
- Modify: `server/app/Models/NfcTag.php`
- Modify: `server/app/Http/Controllers/SpaceController.php`
- Modify: `server/routes/api.php`
- Modify: `server/tests/Feature/OperationsHomeApiTest.php`
- Modify: `server/.env.example`

**Interfaces:**
- Produces: `POST /api/spaces/{space}/nfc-token -> {token: string, url: ?string}`
- Produces: `GET /api/nfc/{token} -> {space_id: int, family_id: int, space_name: string}`
- Produces: `NfcTag::space(): BelongsTo`
- Produces: `config('nfc.public_base_url')`, `config('nfc.ios_team_id')`, `config('nfc.ios_bundle_id')`

- [ ] **Step 1: Write failing Token and permission tests**

Add these focused tests to `OperationsHomeApiTest`:

```php
public function test_family_member_can_create_and_resolve_an_idempotent_nfc_token(): void
{
    config()->set('nfc.public_base_url', 'https://nfc.example.com');
    [$user, $token] = $this->login('13800000040');
    $familyId = $this->withToken($token)
        ->postJson('/api/families', ['name' => 'NFC 家庭'])
        ->assertCreated()
        ->json('data.id');
    $spaceId = $this->withToken($token)
        ->postJson('/api/spaces', ['family_id' => $familyId, 'name' => '玄关柜'])
        ->assertCreated()
        ->json('data.id');

    $first = $this->withToken($token)
        ->postJson("/api/spaces/{$spaceId}/nfc-token")
        ->assertOk()
        ->assertJsonPath('data.url', fn (string $url) => str_starts_with($url, 'https://nfc.example.com/nfc/'))
        ->json('data');

    $second = $this->withToken($token)
        ->postJson("/api/spaces/{$spaceId}/nfc-token")
        ->assertOk()
        ->json('data');

    $this->assertSame($first['token'], $second['token']);
    $this->assertSame(48, strlen($first['token']));

    $this->withToken($token)
        ->getJson("/api/nfc/{$first['token']}")
        ->assertOk()
        ->assertJsonPath('data.space_id', $spaceId)
        ->assertJsonPath('data.family_id', $familyId)
        ->assertJsonPath('data.space_name', '玄关柜');
}

public function test_nfc_token_resolution_rejects_outsiders_and_deleted_spaces(): void
{
    [, $ownerToken] = $this->login('13800000041');
    [, $outsiderToken] = $this->login('13800000042');
    $familyId = $this->withToken($ownerToken)
        ->postJson('/api/families', ['name' => '受保护家庭'])
        ->assertCreated()
        ->json('data.id');
    $spaceId = $this->withToken($ownerToken)
        ->postJson('/api/spaces', ['family_id' => $familyId, 'name' => '私有柜子'])
        ->assertCreated()
        ->json('data.id');
    $nfcToken = $this->withToken($ownerToken)
        ->postJson("/api/spaces/{$spaceId}/nfc-token")
        ->assertOk()
        ->json('data.token');

    $this->withToken($outsiderToken)
        ->postJson("/api/spaces/{$spaceId}/nfc-token")
        ->assertForbidden();
    $this->withToken($outsiderToken)
        ->getJson("/api/nfc/{$nfcToken}")
        ->assertForbidden();

    $this->withToken($ownerToken)->deleteJson("/api/spaces/{$spaceId}")->assertOk();
    $this->withToken($ownerToken)->getJson("/api/nfc/{$nfcToken}")->assertNotFound();
    $this->withToken($ownerToken)->getJson('/api/nfc/not-a-real-token')->assertNotFound();
}

public function test_nfc_token_url_is_null_until_https_domain_is_configured(): void
{
    config()->set('nfc.public_base_url', null);
    [, $token] = $this->login('13800000043');
    $familyId = $this->withToken($token)
        ->postJson('/api/families', ['name' => '本地开发家庭'])
        ->assertCreated()
        ->json('data.id');
    $spaceId = $this->withToken($token)
        ->postJson('/api/spaces', ['family_id' => $familyId, 'name' => '本地柜子'])
        ->assertCreated()
        ->json('data.id');

    $this->withToken($token)
        ->postJson("/api/spaces/{$spaceId}/nfc-token")
        ->assertOk()
        ->assertJsonPath('data.url', null)
        ->assertJsonPath('data.token', fn (string $value) => strlen($value) === 48);
}
```

- [ ] **Step 2: Run focused backend tests and verify RED**

Run:

```bash
docker compose exec -T api ./vendor/bin/phpunit \
  --filter '/test_family_member_can_create_and_resolve_an_idempotent_nfc_token|test_nfc_token_resolution_rejects_outsiders_and_deleted_spaces|test_nfc_token_url_is_null_until_https_domain_is_configured/'
```

Expected: FAIL with HTTP 404 because the NFC routes do not exist.

- [ ] **Step 3: Secure existing NFC identifiers and enforce global uniqueness**

Create a migration that replaces legacy manually entered UIDs with 48-character random
tokens, drops the family-scoped unique index and adds a global unique index:

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration {
    public function up(): void
    {
        DB::table('nfc_tags')->orderBy('id')->each(function (object $tag): void {
            do {
                $token = Str::random(48);
            } while (DB::table('nfc_tags')->where('uid', $token)->exists());

            DB::table('nfc_tags')->where('id', $tag->id)->update(['uid' => $token]);
        });

        Schema::table('nfc_tags', function (Blueprint $table): void {
            $table->dropUnique('nfc_tags_family_id_uid_unique');
            $table->unique('uid', 'nfc_tags_uid_unique');
        });
    }

    public function down(): void
    {
        Schema::table('nfc_tags', function (Blueprint $table): void {
            $table->dropUnique('nfc_tags_uid_unique');
            $table->unique(['family_id', 'uid']);
        });
    }
};
```

Do not add or remove columns; the existing Chinese table and field comments remain intact.

- [ ] **Step 4: Add NFC configuration and model relationship**

Create `server/config/nfc.php`:

```php
<?php

return [
    'public_base_url' => env('NFC_PUBLIC_BASE_URL'),
    'ios_team_id' => env('IOS_TEAM_ID'),
    'ios_bundle_id' => env('IOS_BUNDLE_ID', 'com.operationshome.OperationsHome'),
];
```

Append to `server/.env.example`:

```dotenv
NFC_PUBLIC_BASE_URL=
IOS_TEAM_ID=
IOS_BUNDLE_ID=com.operationshome.OperationsHome
```

Add this relationship to `NfcTag`:

```php
use Illuminate\Database\Eloquent\Relations\BelongsTo;

public function space(): BelongsTo
{
    return $this->belongsTo(StorageSpace::class, 'space_id');
}
```

- [ ] **Step 5: Implement the minimal authenticated controller**

Create `NfcController` using `AuthorizesFamilyAccess`. Token creation must reuse an existing
48-character alphanumeric token; legacy values are replaced once. Use `Str::random(48)` in a
collision loop and `NfcTag::withTrashed()` so a soft-deleted row for the same space can be
restored.

```php
public function createToken(Request $request, StorageSpace $space)
{
    $this->authorizeFamily($request->user(), $space->family_id);
    $tag = NfcTag::withTrashed()->where('space_id', $space->id)->latest('id')->first();

    if (! $tag || ! preg_match('/^[A-Za-z0-9]{48}$/', $tag->uid)) {
        do {
            $token = Str::random(48);
        } while (NfcTag::withTrashed()->where('uid', $token)->exists());

        $tag ??= new NfcTag([
            'family_id' => $space->family_id,
            'space_id' => $space->id,
        ]);
        $tag->uid = $token;
        $tag->save();
    }

    if ($tag->trashed()) {
        $tag->restore();
    }
    $space->touch();

    $baseUrl = rtrim((string) config('nfc.public_base_url'), '/');
    $url = str_starts_with($baseUrl, 'https://')
        ? "{$baseUrl}/nfc/{$tag->uid}"
        : null;

    return $this->ok(['token' => $tag->uid, 'url' => $url]);
}

public function resolve(Request $request, string $token)
{
    $tag = NfcTag::query()
        ->with('space')
        ->where('uid', $token)
        ->firstOrFail();
    abort_if($tag->space === null, 404);

    $this->authorizeFamily($request->user(), $tag->space->family_id);

    return $this->ok([
        'space_id' => $tag->space->id,
        'family_id' => $tag->space->family_id,
        'space_name' => $tag->space->name,
    ]);
}
```

Register inside the existing Sanctum group:

```php
Route::post('/spaces/{space}/nfc-token', [NfcController::class, 'createToken']);
Route::get('/nfc/{token}', [NfcController::class, 'resolve']);
```

Update `SpaceController::syncNfcTag()` to search `uid` globally instead of filtering by
`family_id`. If the same UID belongs to any other space, return the existing
`NFC UID 已绑定其他空间` validation error. This keeps the legacy API compatible with the new
global unique index and prevents a database 1062 error.

- [ ] **Step 6: Run tests and verify GREEN**

Run:

```bash
docker compose exec -T api php artisan migrate
docker compose exec -T api ./vendor/bin/phpunit \
  --filter '/test_family_member_can_create_and_resolve_an_idempotent_nfc_token|test_nfc_token_resolution_rejects_outsiders_and_deleted_spaces|test_nfc_token_url_is_null_until_https_domain_is_configured/'
```

Expected: migration succeeds and all three tests pass.

- [ ] **Step 7: Commit backend Token APIs**

```bash
git add server/app/Http/Controllers/NfcController.php \
  server/app/Http/Controllers/SpaceController.php server/app/Models/NfcTag.php \
  server/config/nfc.php server/routes/api.php \
  server/database/migrations/2026_07_24_000000_secure_nfc_tag_tokens.php \
  server/tests/Feature/OperationsHomeApiTest.php server/.env.example
git commit -m "feat: add secure NFC space tokens"
```

---

### Task 2: AASA 响应与 NFC 接口文档

**Files:**
- Create: `server/routes/web.php`
- Modify: `server/bootstrap/app.php`
- Modify: `server/app/Http/Controllers/NfcController.php`
- Modify: `server/tests/Feature/OperationsHomeApiTest.php`
- Modify: `docs/api.md`
- Modify: `docs/data-model.md`

**Interfaces:**
- Consumes: `config('nfc.ios_team_id')`, `config('nfc.ios_bundle_id')`
- Produces: `GET /.well-known/apple-app-site-association`

- [ ] **Step 1: Write a failing AASA contract test**

```php
public function test_apple_app_site_association_only_matches_nfc_links(): void
{
    config()->set('nfc.ios_team_id', 'TEAM123456');
    config()->set('nfc.ios_bundle_id', 'com.operationshome.OperationsHome');

    $this->getJson('/.well-known/apple-app-site-association')
        ->assertOk()
        ->assertHeader('Content-Type', 'application/json')
        ->assertJsonPath('applinks.details.0.appIDs.0', 'TEAM123456.com.operationshome.OperationsHome')
        ->assertJsonFragment(['/' => '/nfc/*']);
}
```

- [ ] **Step 2: Run the AASA test and verify RED**

Run:

```bash
docker compose exec -T api ./vendor/bin/phpunit \
  --filter test_apple_app_site_association_only_matches_nfc_links
```

Expected: FAIL with HTTP 404 because no root web route is registered.

- [ ] **Step 3: Add the public association response**

Add this method to `NfcController`:

```php
public function association()
{
    $appId = sprintf(
        '%s.%s',
        (string) config('nfc.ios_team_id'),
        (string) config('nfc.ios_bundle_id')
    );

    return response()->json([
        'applinks' => [
            'details' => [[
                'appIDs' => [$appId],
                'components' => [[
                    '/' => '/nfc/*',
                    'comment' => '运营小家 NFC 空间链接',
                ]],
            ]],
        ],
    ], 200, ['Content-Type' => 'application/json']);
}
```

Create `server/routes/web.php`:

```php
<?php

use App\Http\Controllers\NfcController;
use Illuminate\Support\Facades\Route;

Route::get('/.well-known/apple-app-site-association', [NfcController::class, 'association']);
```

Add `web: __DIR__.'/../routes/web.php'` to the existing `withRouting(...)` call in
`server/bootstrap/app.php`.

- [ ] **Step 4: Document exact NFC contracts and deployment boundary**

Update `docs/api.md` with the two authenticated JSON endpoints, their response fields and
403/404 behavior. Document that `url` is `null` until `NFC_PUBLIC_BASE_URL` is valid HTTPS.

Update `docs/data-model.md` so `nfc_tags.uid` is described as a 48-character random link
Token, not a manually entered physical chip UID. Add the AASA path and the three environment
variables to the deployment section.

- [ ] **Step 5: Verify and commit AASA support**

Run:

```bash
docker compose exec -T api ./vendor/bin/phpunit \
  --filter test_apple_app_site_association_only_matches_nfc_links
docker compose exec -T api php artisan route:list --path=nfc
docker compose exec -T api php artisan route:list --path=apple-app-site-association
```

Expected: the test passes; route list includes the two API NFC routes and the AASA route is
available at the root web path.

Commit:

```bash
git add server/routes/web.php server/bootstrap/app.php \
  server/app/Http/Controllers/NfcController.php \
  server/tests/Feature/OperationsHomeApiTest.php docs/api.md docs/data-model.md
git commit -m "feat: serve NFC universal link association"
```

---

### Task 3: iOS NFC DTO、URL 解析与待处理路由

**Files:**
- Create: `ios/OperationsHome/Services/NFCDeepLinkRouter.swift`
- Create: `ios/OperationsHomeTests/NFCDeepLinkRouterTests.swift`
- Modify: `ios/OperationsHome/Networking/APIModels.swift`
- Modify: `ios/OperationsHome/Networking/APIClient.swift`
- Modify: `ios/OperationsHome/Views/ContentView.swift`
- Modify: `ios/OperationsHome/OperationsHomeApp.swift`
- Modify: `ios/project.yml`
- Modify: `ios/OperationsHome/Info.plist`

**Interfaces:**
- Consumes: `POST spaces/{id}/nfc-token`, `GET nfc/{token}`
- Produces: `NFCTokenDTO(token: String, url: URL?)`
- Produces: `NFCSpaceDestinationDTO(spaceId: Int, familyId: Int, spaceName: String)`
- Produces: `@MainActor final class NFCDeepLinkRouter: ObservableObject`
- Produces: `func token(from url: URL) -> String?`

- [ ] **Step 1: Write failing parser and persistence tests**

Create `NFCDeepLinkRouterTests.swift`:

```swift
import XCTest
@testable import OperationsHome

@MainActor
final class NFCDeepLinkRouterTests: XCTestCase {
    func testParsesUniversalAndDevelopmentLinks() {
        let router = NFCDeepLinkRouter()

        XCTAssertEqual(
            router.token(from: URL(string: "https://nfc.example.com/nfc/ABC123")!),
            "ABC123"
        )
        XCTAssertEqual(
            router.token(from: URL(string: "operationshome://nfc/ABC123")!),
            "ABC123"
        )
        XCTAssertNil(router.token(from: URL(string: "https://nfc.example.com/items/1")!))
    }

    func testPendingTokenSurvivesRouterRecreationUntilConsumed() {
        let suite = "NFCDeepLinkRouterTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        var router: NFCDeepLinkRouter? = NFCDeepLinkRouter(defaults: defaults)
        XCTAssertTrue(router?.handle(URL(string: "operationshome://nfc/ABC123")!) == true)
        router = nil

        let restored = NFCDeepLinkRouter(defaults: defaults)
        XCTAssertEqual(restored.pendingToken, "ABC123")
        restored.consumePendingToken()
        XCTAssertNil(restored.pendingToken)
        defaults.removePersistentDomain(forName: suite)
    }
}
```

- [ ] **Step 2: Run iOS tests and verify RED**

Run:

```bash
xcodebuild test -project ios/OperationsHome.xcodeproj -scheme OperationsHome \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/OperationsHomeNFCDerivedData \
  -only-testing:OperationsHomeTests/NFCDeepLinkRouterTests
```

Expected: FAIL because `NFCDeepLinkRouter` does not exist.

- [ ] **Step 3: Add API response models and client methods**

Add:

```swift
struct NFCTokenDTO: Codable {
    let token: String
    let url: URL?
}

struct NFCSpaceDestinationDTO: Codable {
    let spaceId: Int
    let familyId: Int
    let spaceName: String

    enum CodingKeys: String, CodingKey {
        case spaceId = "space_id"
        case familyId = "family_id"
        case spaceName = "space_name"
    }
}
```

Add these methods to `APIClient`:

```swift
func nfcToken(spaceId: Int) async throws -> NFCTokenDTO {
    try await request("spaces/\(spaceId)/nfc-token", method: "POST")
}

func resolveNfcToken(_ token: String) async throws -> NFCSpaceDestinationDTO {
    try await request("nfc/\(token.urlPathValue)")
}
```

Add `urlPathValue` next to the existing query encoding helper using
`addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)`.

- [ ] **Step 4: Implement the app-level router**

`NFCDeepLinkRouter` stores only the pending Token in `UserDefaults`:

```swift
@MainActor
final class NFCDeepLinkRouter: ObservableObject {
    @Published private(set) var pendingToken: String?
    @Published var requestedSpaceId: Int?
    @Published var message: String?

    private let defaults: UserDefaults
    private let storageKey = "pendingNfcToken"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pendingToken = defaults.string(forKey: storageKey)
    }

    func token(from url: URL) -> String? {
        if url.scheme == "operationshome", url.host == "nfc" {
            return url.pathComponents.dropFirst().first?.nonEmpty
        }
        guard url.scheme == "https" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == "nfc" else { return nil }
        return parts[1].nonEmpty
    }

    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let token = token(from: url) else { return false }
        pendingToken = token
        defaults.set(token, forKey: storageKey)
        return true
    }

    func consumePendingToken() {
        pendingToken = nil
        defaults.removeObject(forKey: storageKey)
    }
}
```

Define a private or internal `String.nonEmpty` helper in the same file.

- [ ] **Step 5: Connect URL delivery at the App root**

Create the router once in `OperationsHomeApp`, pass it into `ContentView`, and then into
`HomeView`. Add both handlers to `ContentView`:

```swift
.onOpenURL { router.handle($0) }
.onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
    guard let url = activity.webpageURL else { return }
    router.handle(url)
}
```

Register the development Scheme in `ios/project.yml` and the generated `Info.plist`:

```yaml
CFBundleURLTypes:
  - CFBundleURLName: com.operationshome.OperationsHome
    CFBundleURLSchemes:
      - operationshome
```

Run `xcodegen generate --spec ios/project.yml` after editing the spec.

- [ ] **Step 6: Verify tests and commit router work**

Run the focused test command from Step 2.

Expected: both router tests pass.

Commit:

```bash
git add ios/project.yml ios/OperationsHome/Info.plist \
  ios/OperationsHome/OperationsHomeApp.swift ios/OperationsHome/Views/ContentView.swift \
  ios/OperationsHome/Networking/APIModels.swift ios/OperationsHome/Networking/APIClient.swift \
  ios/OperationsHome/Services/NFCDeepLinkRouter.swift \
  ios/OperationsHomeTests/NFCDeepLinkRouterTests.swift \
  ios/OperationsHome.xcodeproj/project.pbxproj
git commit -m "feat: add NFC deep link routing"
```

---

### Task 4: Core NFC 写入服务与玻璃写入页面

**Files:**
- Create: `ios/OperationsHome/Services/NFCWriter.swift`
- Create: `ios/OperationsHome/Views/NFCWriteView.swift`
- Create: `ios/OperationsHomeTests/NFCWriterTests.swift`
- Modify: `ios/project.yml`
- Modify: `ios/OperationsHome/Info.plist`
- Modify: `ios/OperationsHome/OperationsHome.entitlements`

**Interfaces:**
- Consumes: `NFCTokenDTO.url`
- Produces: `protocol NFCWriting { var isAvailable: Bool { get }; func write(url: URL) async throws }`
- Produces: `enum NFCWriteState: Equatable`
- Produces: `@MainActor final class NFCWriteViewModel: ObservableObject`
- Produces: `struct NFCWriteView: View`

- [ ] **Step 1: Write failing write-state tests with a fake writer**

```swift
import XCTest
@testable import OperationsHome

private final class FakeNFCWriter: NFCWriting {
    var isAvailable = true
    var result: Result<Void, Error> = .success(())
    private(set) var writtenURL: URL?

    func write(url: URL) async throws {
        writtenURL = url
        try result.get()
    }
}

@MainActor
final class NFCWriterTests: XCTestCase {
    func testWriteViewModelWritesExactUniversalLinkAndShowsSuccess() async {
        let writer = FakeNFCWriter()
        let model = NFCWriteViewModel(writer: writer)
        let url = URL(string: "https://nfc.example.com/nfc/ABC123")!

        await model.write(url: url)

        XCTAssertEqual(writer.writtenURL, url)
        XCTAssertEqual(model.state, .success)
    }

    func testMissingDomainAndUnsupportedDeviceShowActionableStates() async {
        let writer = FakeNFCWriter()
        writer.isAvailable = false
        let model = NFCWriteViewModel(writer: writer)

        await model.write(url: nil)
        XCTAssertEqual(model.state, .domainUnavailable)

        await model.write(url: URL(string: "https://nfc.example.com/nfc/ABC123"))
        XCTAssertEqual(model.state, .deviceUnavailable)
    }
}
```

- [ ] **Step 2: Run focused tests and verify RED**

Run:

```bash
xcodebuild test -project ios/OperationsHome.xcodeproj -scheme OperationsHome \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/OperationsHomeNFCDerivedData \
  -only-testing:OperationsHomeTests/NFCWriterTests
```

Expected: FAIL because `NFCWriting`, `NFCWriteViewModel` and `NFCWriteState` do not exist.

- [ ] **Step 3: Implement testable write states**

Use these states and precedence:

```swift
enum NFCWriteState: Equatable {
    case ready
    case writing
    case success
    case domainUnavailable
    case deviceUnavailable
    case failed(String)
}
```

`NFCWriteViewModel.write(url:)` first checks `url`, then `writer.isAvailable`, sets
`.writing`, awaits the writer, and maps success or `localizedDescription` to the final state.

- [ ] **Step 4: Implement Core NFC NDEF writing**

Create `NFCWriter` as an `NSObject` implementing `NFCNDEFReaderSessionDelegate`. It owns one
checked continuation per session. `write(url:)` must:

1. Reject when `NFCNDEFReaderSession.readingAvailable` is false.
2. Build `NFCNDEFPayload.wellKnownTypeURIPayload(string: url.absoluteString)`.
3. Start an `NFCNDEFReaderSession` with `invalidateAfterFirstRead: false`.
4. In `didDetect tags`, require exactly one tag and connect to it.
5. Call `queryNDEFStatus`; reject `.notSupported`, `.readOnly`, and insufficient capacity.
6. Call `writeNDEF`, show the system success message, invalidate the session, and resume the
   continuation exactly once.
7. Map user cancellation without presenting it as an unexpected failure.

Keep all Core NFC delegate logic in this file; do not place it in a SwiftUI view.

- [ ] **Step 5: Build the NFC write page**

`NFCWriteView` accepts `spaceName`, `url`, `writer` and `onClose`. Use:

- `OnboardingBackground` as the full background.
- A circular `xmark` toolbar button with accessibility label “关闭”.
- A glass section containing `wave.3.right.circle.fill`.
- Copy “将 iPhone 顶部靠近 NFC 贴纸” in ready state.
- A green circular NFC button with accessibility label “写入 NFC 贴纸”.
- `ProgressView` while writing.
- A green `checkmark.circle.fill` on success.
- Exact unavailable copy:
  - Domain: “配置正式 HTTPS 域名后即可写入 NFC 贴纸。”
  - Device: “请使用支持 NFC 的 iPhone 写入贴纸。”

The page never displays the Token or full URL.

- [ ] **Step 6: Enable Core NFC capability**

Update the usage description to:

```text
用于将储物空间链接写入 NFC 贴纸。
```

Add to `OperationsHome.entitlements`:

```xml
<key>com.apple.developer.nfc.readersession.formats</key>
<array>
    <string>NDEF</string>
</array>
```

Mirror the description and entitlement in `ios/project.yml`, then regenerate the project.
Do not add Associated Domains yet because no real domain exists; document this as the one
remaining deployment step.

- [ ] **Step 7: Verify and commit NFC writer**

Run the focused test command from Step 2 and:

```bash
xcodebuild build -project ios/OperationsHome.xcodeproj -scheme OperationsHome \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/OperationsHomeNFCDerivedData
```

Expected: tests pass and simulator build succeeds.

Commit:

```bash
git add ios/project.yml ios/OperationsHome/Info.plist \
  ios/OperationsHome/OperationsHome.entitlements \
  ios/OperationsHome/Services/NFCWriter.swift \
  ios/OperationsHome/Views/NFCWriteView.swift \
  ios/OperationsHomeTests/NFCWriterTests.swift \
  ios/OperationsHome.xcodeproj/project.pbxproj
git commit -m "feat: write space links to NFC tags"
```

---

### Task 5: 空间保存后写入 NFC 与深链直达导航

**Files:**
- Modify: `ios/OperationsHome/Views/SpacesView.swift`
- Modify: `ios/OperationsHome/Views/HomeView.swift`
- Modify: `ios/OperationsHome/Views/ContentView.swift`
- Modify: `ios/OperationsHomeTests/APIModelsTests.swift`
- Test: `ios/OperationsHomeTests/NFCDeepLinkRouterTests.swift`

**Interfaces:**
- Consumes: `NFCDeepLinkRouter.pendingToken`, `.requestedSpaceId`, `.message`
- Consumes: `APIClient.nfcToken(spaceId:)`, `APIClient.resolveNfcToken(_:)`
- Consumes: `NFCWriteView`
- Produces: `SpacesView(..., requestedSpaceId: Binding<Int?>)`

- [ ] **Step 1: Add failing navigation decision tests**

Add pure routing helpers to the intended contract:

```swift
struct NFCNavigationDecision: Equatable {
    let familyId: Int
    let spaceId: Int
}

func nfcNavigationDecision(
    destination: NFCSpaceDestinationDTO,
    availableFamilyIds: Set<Int>
) -> NFCNavigationDecision? {
    availableFamilyIds.contains(destination.familyId)
        ? NFCNavigationDecision(familyId: destination.familyId, spaceId: destination.spaceId)
        : nil
}
```

Write tests before implementing:

```swift
func testNfcDestinationOnlyNavigatesInsideLoadedMemberships() {
    let target = NFCSpaceDestinationDTO(spaceId: 11, familyId: 3, spaceName: "玄关柜")

    XCTAssertEqual(
        nfcNavigationDecision(destination: target, availableFamilyIds: [3, 4]),
        NFCNavigationDecision(familyId: 3, spaceId: 11)
    )
    XCTAssertNil(
        nfcNavigationDecision(destination: target, availableFamilyIds: [4])
    )
}
```

Run the router test target and verify compilation fails because the helper does not exist.

- [ ] **Step 2: Resolve pending links in `HomeView`**

Pass `NFCDeepLinkRouter` into `HomeView`. Add:

```swift
@State private var requestedSpaceId: Int?
```

When `router.pendingToken` changes and a session token exists:

1. Call `APIClient(token: token).resolveNfcToken(pendingToken)`.
2. Reload families if the destination family is absent.
3. Build `nfcNavigationDecision`.
4. On success set `session.selectedFamilyId`, `selectedTab = .spaces`,
   `requestedSpaceId`, then consume the Token.
5. On 403/404 or other API errors, set `router.message` to the server message and consume
   invalid/forbidden Tokens.
6. On `URLError`, keep the Token and expose a “重试” alert action that calls the same resolver
   again.

Attach this work with `.task(id: router.pendingToken)` so a Token received before login is
processed automatically after `HomeView` appears.

- [ ] **Step 3: Make `SpacesView` programmatically navigable**

Change its initializer contract to accept:

```swift
@Binding var requestedSpaceId: Int?
```

Use `NavigationStack(path: $path)` with `[Int]` values. Convert card links to
`NavigationLink(value: space.remoteId)` and register:

```swift
.navigationDestination(for: Int.self) { spaceId in
    if let space = spaces.first(where: { $0.remoteId == spaceId }) {
        ItemsView(session: session, sync: sync, spaceFilter: space)
    }
}
```

Handle both initial and later requests. Append only when the requested active space exists,
then clear the binding so the same deep link is not pushed twice.

- [ ] **Step 4: Replace manual NFC UID input with the NFC section**

Remove `@State private var nfcUid` and the `OnboardingTextField(title: "NFC UID", ...)`.
Space create/update continues sending the existing `space?.nfcUid` value so editing unrelated
fields does not clear a bound Token.

Add a glass “NFC 贴纸” section:

```swift
Button {
    Task { await prepareNfc(for: space.remoteId) }
} label: {
    Label(
        space.nfcUid == nil ? "写入 NFC 贴纸" : "重新写入 NFC 贴纸",
        systemImage: "wave.3.right"
    )
}
```

For a newly created space:

1. Save and insert the returned `SpaceDTO`.
2. Request `nfcToken(spaceId:)`.
3. Apply the returned Token to the local `SpaceRecord.nfcUid`.
4. Automatically present `NFCWriteView`.
5. Dismiss the add-space form after the NFC page closes, whether writing succeeded or the
   user skipped.

For an existing space, the NFC section requests/reuses the Token and presents the same page
without dismissing the edit form afterward.

- [ ] **Step 5: Present router errors without blocking navigation**

In `HomeView`, add an alert bound to `router.message` with a single “知道了” action. Use:

- Server 403 message: “你没有权限访问这个空间。”
- Server 404 message: “该 NFC 贴纸已失效。”
- Network error: “网络不可用，请联网后重试。”

The network alert includes “重试” and “稍后” actions. Other errors use one “知道了” action.
Do not display raw Token values.

- [ ] **Step 6: Run iOS tests and verify GREEN**

Run:

```bash
xcodebuild test -project ios/OperationsHome.xcodeproj -scheme OperationsHome \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/OperationsHomeNFCDerivedData \
  -only-testing:OperationsHomeTests/NFCDeepLinkRouterTests \
  -only-testing:OperationsHomeTests/APIModelsTests
```

Expected: parser, persistence, DTO and navigation-decision tests pass.

- [ ] **Step 7: Verify simulator deep-link flow**

Build, install and launch:

```bash
xcodebuild build -project ios/OperationsHome.xcodeproj -scheme OperationsHome \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/OperationsHomeNFCDerivedData
xcrun simctl install booted \
  /tmp/OperationsHomeNFCDerivedData/Build/Products/Debug-iphonesimulator/OperationsHome.app
xcrun simctl launch --terminate-running-process booted com.operationshome.OperationsHome
NFC_TOKEN=$(docker compose exec -T api php artisan tinker \
  --execute="echo App\\Models\\NfcTag::query()->latest('id')->value('uid');")
xcrun simctl openurl booted "operationshome://nfc/${NFC_TOKEN}"
```

Expected: the App selects the latest Token’s family and opens that space’s item list. When
logged out, expected: login appears first and the same navigation continues after successful
login.

- [ ] **Step 8: Commit the integrated iOS flow**

```bash
git add ios/OperationsHome/Views/SpacesView.swift \
  ios/OperationsHome/Views/HomeView.swift ios/OperationsHome/Views/ContentView.swift \
  ios/OperationsHomeTests/APIModelsTests.swift \
  ios/OperationsHomeTests/NFCDeepLinkRouterTests.swift
git commit -m "feat: open storage spaces from NFC links"
```

---

### Task 6: 全量回归与正式域名交付说明

**Files:**
- Modify: `docs/deployment.md`

**Interfaces:**
- Consumes: all NFC backend and iOS interfaces from Tasks 1-5
- Produces: exact production domain activation checklist

- [ ] **Step 1: Document the production activation checklist**

Add these required steps to `docs/deployment.md`:

1. Set `NFC_PUBLIC_BASE_URL=https://实际域名`, `IOS_TEAM_ID` and `IOS_BUNDLE_ID`.
2. Ensure `https://实际域名/.well-known/apple-app-site-association` returns HTTP 200,
   `application/json`, and no redirect.
3. Add `applinks:实际域名` under the iOS target’s Associated Domains capability.
4. Regenerate the Xcode project and sign with the matching Apple Team.
5. Reinstall the App so iOS fetches the association.
6. Test on iPhone XS or newer with a writable NDEF tag.

State explicitly that setting only `NFC_PUBLIC_BASE_URL` is insufficient; AASA, entitlement
and signing Team must all match.

- [ ] **Step 2: Run the complete backend suite**

Run:

```bash
docker compose exec -T api php artisan migrate
docker compose exec -T api ./vendor/bin/phpunit
```

Expected: all backend tests pass with no migration errors.

- [ ] **Step 3: Run the complete iOS suite and build**

Run:

```bash
xcodebuild test -project ios/OperationsHome.xcodeproj -scheme OperationsHome \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/OperationsHomeNFCDerivedData
xcodebuild build -project ios/OperationsHome.xcodeproj -scheme OperationsHome \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/OperationsHomeNFCDerivedData
```

Expected: all iOS tests pass and `** BUILD SUCCEEDED **` is printed.

- [ ] **Step 4: Inspect the final UI in Simulator**

Verify:

- Add-space form no longer shows a manual NFC UID field.
- Saving a space automatically opens the NFC page.
- With no domain configured, the page shows the exact domain-unavailable message.
- Editing a bound space shows “重新写入 NFC 贴纸”.
- A development Scheme URL containing a valid local Token opens the correct item list.
- NFC views use glass sections, circular icon controls, and no raw Token text.

- [ ] **Step 5: Confirm only intended files changed**

Run:

```bash
git status --short
git diff --check
```

Expected: no whitespace errors. Do not stage or revert the user’s pre-existing
`ios/OperationsHome/Views/ItemsView.swift` or Xcode `UserInterfaceState.xcuserstate`.

- [ ] **Step 6: Commit deployment documentation**

```bash
git add docs/deployment.md
git commit -m "docs: add NFC domain activation steps"
```
