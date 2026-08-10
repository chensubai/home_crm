<?php

namespace Tests\Feature;

use App\Models\Family;
use App\Models\Item;
use App\Models\NfcTag;
use App\Models\StorageSpace;
use App\Models\User;
use App\Services\QiniuStorage;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OperationsHomeApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_submit_feedback(): void
    {
        [$user, $token] = $this->login('13800000005');

        $this->withToken($token)
            ->postJson('/api/feedback', ['content' => '希望增加反馈入口'])
            ->assertCreated()
            ->assertJsonPath('data.user_id', $user->id)
            ->assertJsonPath('data.content', '希望增加反馈入口')
            ->assertJsonPath('data.status', 'pending');

        $this->assertDatabaseHas('feedback', [
            'user_id' => $user->id,
            'content' => '希望增加反馈入口',
            'status' => 'pending',
        ]);
    }

    public function test_sms_login_creates_user_and_token(): void
    {
        $this->postJson('/api/auth/sms/send', ['phone' => '13800000001'])
            ->assertOk()
            ->assertJsonPath('data.mock_code', '123456');

        $this->postJson('/api/auth/sms/verify', [
            'phone' => '13800000001',
            'code' => '123456',
            'name' => '用户A',
        ])
            ->assertOk()
            ->assertJsonStructure(['data' => ['token', 'user' => ['id', 'phone', 'name']]]);
    }

    public function test_family_inventory_reminder_and_sync_flow(): void
    {
        [$user, $token] = $this->login('13800000002');

        $familyId = $this->withToken($token)
            ->postJson('/api/families', ['name' => '我的家'])
            ->assertCreated()
            ->json('data.id');

        $spaceId = $this->withToken($token)
            ->postJson('/api/spaces', [
                'family_id' => $familyId,
                'name' => '客厅柜子',
            ])
            ->assertCreated()
            ->json('data.id');

        $itemId = $this->withToken($token)
            ->postJson('/api/items', [
                'family_id' => $familyId,
                'space_id' => $spaceId,
                'name' => '纸巾',
                'category' => '日用品',
                'quantity' => 6,
                'unit' => '包',
                'status' => 'idle',
            ])
            ->assertCreated()
            ->json('data.id');

        $this->withToken($token)
            ->postJson("/api/items/{$itemId}/adjust", ['delta' => -1, 'reason' => '取用'])
            ->assertOk()
            ->assertJsonPath('data.quantity', 5);

        $this->withToken($token)
            ->postJson('/api/reminders', [
                'family_id' => $familyId,
                'title' => '交水电费',
                'kind' => 'important_date',
                'remind_at' => now()->addDay()->toIso8601String(),
                'repeat_rule' => 'monthly',
            ])
            ->assertCreated();

        $this->withToken($token)
            ->getJson("/api/sync?family_id={$familyId}")
            ->assertOk()
            ->assertJsonCount(1, 'data.spaces')
            ->assertJsonCount(1, 'data.items')
            ->assertJsonCount(1, 'data.reminders');

        $this->assertDatabaseHas('item_changes', [
            'user_id' => $user->id,
            'before_quantity' => 6,
            'after_quantity' => 5,
        ]);
    }

    public function test_incremental_sync_refreshes_image_urls_for_unchanged_records(): void
    {
        $this->app->instance(QiniuStorage::class, new class extends QiniuStorage
        {
            public function url(string $key): string
            {
                return "https://cdn.example.com/original/{$key}";
            }

            public function thumbnailUrl(string $key): string
            {
                return "https://cdn.example.com/thumbnail/{$key}";
            }
        });

        [, $token] = $this->login('13800000053');
        $familyId = $this->withToken($token)
            ->postJson('/api/families', ['name' => '图片同步家庭'])
            ->assertCreated()
            ->json('data.id');
        $spaceId = $this->withToken($token)
            ->postJson('/api/spaces', ['family_id' => $familyId, 'name' => '带图空间'])
            ->assertCreated()
            ->json('data.id');
        $itemId = $this->withToken($token)
            ->postJson('/api/items', [
                'family_id' => $familyId,
                'space_id' => $spaceId,
                'name' => '带图物品',
                'quantity' => 1,
            ])
            ->assertCreated()
            ->json('data.id');

        $updatedAt = now()->subHour();
        StorageSpace::whereKey($spaceId)->update([
            'image_key' => 'families/1/spaces/space.jpg',
            'updated_at' => $updatedAt,
        ]);
        Item::whereKey($itemId)->update([
            'image_key' => 'families/1/items/item.jpg',
            'updated_at' => $updatedAt,
        ]);

        $since = now()->subMinute()->toIso8601String();

        $this->withToken($token)
            ->getJson('/api/sync?family_id='.$familyId.'&since='.rawurlencode($since))
            ->assertOk()
            ->assertJsonCount(1, 'data.spaces')
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.spaces.0.image_url', 'https://cdn.example.com/original/families/1/spaces/space.jpg')
            ->assertJsonPath('data.spaces.0.thumbnail_url', 'https://cdn.example.com/thumbnail/families/1/spaces/space.jpg')
            ->assertJsonPath('data.items.0.image_url', 'https://cdn.example.com/original/families/1/items/item.jpg')
            ->assertJsonPath('data.items.0.thumbnail_url', 'https://cdn.example.com/thumbnail/families/1/items/item.jpg');
    }

    public function test_family_data_is_isolated_between_memberships(): void
    {
        $owner = User::create(['phone' => '13800000003', 'name' => 'Owner']);
        $outsider = User::create(['phone' => '13800000004', 'name' => 'Outsider']);

        Sanctum::actingAs($owner);
        $familyId = $this
            ->postJson('/api/families', ['name' => 'A 家'])
            ->assertCreated()
            ->json('data.id');

        $this->assertDatabaseMissing('family_members', [
            'family_id' => $familyId,
            'user_id' => $outsider->id,
        ]);

        Sanctum::actingAs($outsider);
        $this
            ->getJson("/api/spaces?family_id={$familyId}")
            ->assertForbidden();
    }

    public function test_uploads_space_and_item_images_to_qiniu(): void
    {
        $this->app->instance(QiniuStorage::class, new class extends QiniuStorage
        {
            public function uploadImage(UploadedFile $file, int $familyId, string $directory = 'images'): array
            {
                return [
                    'key' => "families/{$familyId}/{$directory}/fake.png",
                    'hash' => 'qiniu-file-hash',
                    'url' => "https://cdn.example.com/families/{$familyId}/{$directory}/fake.png",
                ];
            }

            public function url(string $key): string
            {
                return 'https://cdn.example.com/'.$key;
            }
        });

        [, $token] = $this->login('13800000005');

        $familyId = $this->withToken($token)
            ->postJson('/api/families', ['name' => '图片家庭'])
            ->assertCreated()
            ->json('data.id');

        $spaceId = $this->withToken($token)
            ->post('/api/spaces', [
                'family_id' => $familyId,
                'image' => $this->fakePngUpload(),
                'name' => '带图柜子',
            ], ['Accept' => 'application/json'])
            ->assertCreated()
            ->assertJsonPath('data.family_id', $familyId)
            ->assertJsonPath('data.image_hash', 'qiniu-file-hash')
            ->assertJson(fn ($json) => $json->where('ok', true)->whereType('data.image_url', 'string')->etc())
            ->json('data.id');

        $this->assertDatabaseHas('storage_spaces', [
            'id' => $spaceId,
            'family_id' => $familyId,
            'image_hash' => 'qiniu-file-hash',
        ]);

        $this->withToken($token)
            ->post('/api/items', [
                'family_id' => $familyId,
                'space_id' => $spaceId,
                'name' => '带图纸巾',
                'quantity' => 2,
                'image' => $this->fakePngUpload(),
            ], ['Accept' => 'application/json'])
            ->assertCreated()
            ->assertJsonPath('data.family_id', $familyId)
            ->assertJsonPath('data.image_hash', 'qiniu-file-hash')
            ->assertJson(fn ($json) => $json->where('ok', true)->whereType('data.image_url', 'string')->etc());
    }

    public function test_user_can_refresh_and_update_profile_with_avatar(): void
    {
        $this->app->instance(QiniuStorage::class, new class extends QiniuStorage
        {
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
        [$member] = $this->login('13800000012');

        $familyId = $this->withToken($ownerToken)
            ->postJson('/api/families', ['name' => '原家庭名'])
            ->assertCreated()
            ->assertJsonPath('data.role', 'owner')
            ->json('data.id');

        $membership = Family::findOrFail($familyId)->members()->create([
            'user_id' => $member->id,
            'role' => 'member',
        ]);

        Sanctum::actingAs($member);
        $this->getJson('/api/auth/me')
            ->assertOk()
            ->assertJsonPath('data.id', $member->id);

        $this->patchJson("/api/families/{$familyId}", ['name' => '越权修改'])
            ->assertForbidden();

        Sanctum::actingAs($owner);
        $this->patchJson("/api/families/{$familyId}", ['name' => '新家庭名'])
            ->assertOk()
            ->assertJsonPath('data.name', '新家庭名');

        $this->getJson("/api/families/{$familyId}/members")
            ->assertOk()
            ->assertJsonFragment([
                'id' => $membership->id,
                'user_id' => $member->id,
                'phone' => $member->phone,
                'role' => 'member',
            ]);

        $this->deleteJson("/api/families/{$familyId}/members/{$membership->id}")
            ->assertOk();
    }

    public function test_space_update_and_nonempty_delete_are_safe(): void
    {
        [, $token] = $this->login('13800000020');
        $familyId = $this->withToken($token)
            ->postJson('/api/families', ['name' => '空间测试家庭'])
            ->assertCreated()
            ->json('data.id');
        $spaceId = $this->withToken($token)
            ->postJson('/api/spaces', [
                'family_id' => $familyId,
                'name' => '原柜子',
            ])
            ->assertCreated()
            ->json('data.id');
        $itemId = $this->withToken($token)
            ->postJson('/api/items', [
                'family_id' => $familyId,
                'space_id' => $spaceId,
                'name' => '纸巾',
                'quantity' => 1,
            ])
            ->assertCreated()
            ->json('data.id');

        $this->withToken($token)->patchJson("/api/spaces/{$spaceId}", [
            'name' => '更新后的柜子',
            'description' => '客厅北侧',
        ])->assertOk()
            ->assertJsonPath('data.name', '更新后的柜子');

        $this->withToken($token)->deleteJson("/api/spaces/{$spaceId}")
            ->assertStatus(422)
            ->assertJsonPath('message', '空间内仍有物品，请先移动或删除物品');

        $this->withToken($token)->deleteJson("/api/items/{$itemId}")->assertOk();
        $this->withToken($token)->deleteJson("/api/spaces/{$spaceId}")->assertOk();
    }

    public function test_item_adjustment_is_clamped_and_space_stays_in_family(): void
    {
        [, $token] = $this->login('13800000021');
        $familyId = $this->withToken($token)
            ->postJson('/api/families', ['name' => '库存家庭'])
            ->assertCreated()
            ->json('data.id');
        $otherFamilyId = $this->withToken($token)
            ->postJson('/api/families', ['name' => '另一个家庭'])
            ->assertCreated()
            ->json('data.id');
        $spaceId = $this->withToken($token)
            ->postJson('/api/spaces', ['family_id' => $familyId, 'name' => '本家庭柜子'])
            ->assertCreated()
            ->json('data.id');
        $otherSpaceId = $this->withToken($token)
            ->postJson('/api/spaces', ['family_id' => $otherFamilyId, 'name' => '其他家庭柜子'])
            ->assertCreated()
            ->json('data.id');
        $itemId = $this->withToken($token)
            ->postJson('/api/items', [
                'family_id' => $familyId,
                'space_id' => $spaceId,
                'name' => '清洁剂',
                'quantity' => 2,
            ])
            ->assertCreated()
            ->json('data.id');

        $this->withToken($token)->postJson("/api/items/{$itemId}/adjust", ['delta' => -99])
            ->assertOk()
            ->assertJsonPath('data.quantity', 0);
        $this->assertDatabaseHas('item_changes', [
            'item_id' => $itemId,
            'before_quantity' => 2,
            'after_quantity' => 0,
            'delta' => -2,
        ]);

        $this->withToken($token)->patchJson("/api/items/{$itemId}", [
            'space_id' => $otherSpaceId,
        ])->assertStatus(422)
            ->assertJsonValidationErrors('space_id');
    }

    public function test_space_crud_rejects_caller_chosen_nfc_uid(): void
    {
        [, $token] = $this->login('13800000023');
        $familyId = $this->withToken($token)
            ->postJson('/api/families', ['name' => 'NFC 重绑家庭'])
            ->assertCreated()
            ->json('data.id');
        $this->withToken($token)
            ->postJson('/api/spaces', [
                'family_id' => $familyId,
                'name' => '不应绑定 NFC 的柜子',
                'nfc_uid' => 'caller-chosen',
            ])
            ->assertStatus(422)
            ->assertJsonValidationErrors('nfc_uid');

        $spaceId = $this->withToken($token)
            ->postJson('/api/spaces', [
                'family_id' => $familyId,
                'name' => '普通柜子',
            ])
            ->assertCreated()
            ->json('data.id');

        $this->withToken($token)
            ->patchJson("/api/spaces/{$spaceId}", ['nfc_uid' => 'caller-chosen'])
            ->assertStatus(422)
            ->assertJsonValidationErrors('nfc_uid');
        $this->assertDatabaseMissing('nfc_tags', ['space_id' => $spaceId]);
    }

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
        $this->assertMatchesRegularExpression('/^oh_[A-Za-z0-9]{48}$/', $first['token']);

        $tag = NfcTag::where('space_id', $spaceId)->firstOrFail();
        $tag->delete();
        $restored = $this->withToken($token)
            ->postJson("/api/spaces/{$spaceId}/nfc-token")
            ->assertOk()
            ->json('data');

        $this->assertSame($first['token'], $restored['token']);
        $this->assertDatabaseHas('nfc_tags', ['id' => $tag->id, 'deleted_at' => null]);

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

        $this->app['auth']->forgetGuards();
        $this->withToken($outsiderToken)
            ->getJson('/api/auth/me')
            ->assertOk()
            ->assertJsonPath('data.phone', '13800000042');
        $this->withToken($outsiderToken)
            ->postJson("/api/spaces/{$spaceId}/nfc-token")
            ->assertForbidden();
        $this->withToken($outsiderToken)
            ->getJson("/api/nfc/{$nfcToken}")
            ->assertForbidden();

        $this->app['auth']->forgetGuards();
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
            ->assertJsonPath(
                'data.token',
                fn (string $value) => preg_match('/^oh_[A-Za-z0-9]{48}$/', $value) === 1
            );
    }

    public function test_secure_nfc_token_migration_preserves_only_unique_canonical_tokens(): void
    {
        $spaceMigration = require database_path(
            'migrations/2026_07_24_010000_enforce_one_nfc_tag_per_space.php'
        );
        $tokenMigration = require database_path(
            'migrations/2026_07_24_000000_secure_nfc_tag_tokens.php'
        );
        $spaceMigration->down();
        $tokenMigration->down();

        $firstFamily = Family::create(['name' => '迁移家庭 A']);
        $secondFamily = Family::create(['name' => '迁移家庭 B']);
        $spaces = collect([
            StorageSpace::create(['family_id' => $firstFamily->id, 'name' => '保留空间']),
            StorageSpace::create(['family_id' => $firstFamily->id, 'name' => '旧格式空间']),
            StorageSpace::create(['family_id' => $firstFamily->id, 'name' => '重复空间 A']),
            StorageSpace::create(['family_id' => $secondFamily->id, 'name' => '重复空间 B']),
        ]);
        $canonicalToken = 'oh_'.str_repeat('A', 48);
        $duplicateToken = 'oh_'.str_repeat('B', 48);

        DB::table('nfc_tags')->insert([
            [
                'family_id' => $firstFamily->id,
                'space_id' => $spaces[0]->id,
                'uid' => $canonicalToken,
            ],
            [
                'family_id' => $firstFamily->id,
                'space_id' => $spaces[1]->id,
                'uid' => 'legacy-manual-uid',
            ],
            [
                'family_id' => $firstFamily->id,
                'space_id' => $spaces[2]->id,
                'uid' => $duplicateToken,
            ],
            [
                'family_id' => $secondFamily->id,
                'space_id' => $spaces[3]->id,
                'uid' => $duplicateToken,
            ],
        ]);

        $tokenMigration->up();
        $spaceMigration->up();

        $tokens = DB::table('nfc_tags')->orderBy('id')->pluck('uid')->all();
        $this->assertSame($canonicalToken, $tokens[0]);
        $this->assertNotSame('legacy-manual-uid', $tokens[1]);
        $this->assertNotContains($duplicateToken, $tokens, true);
        $this->assertCount(4, array_unique($tokens));
        foreach ($tokens as $token) {
            $this->assertMatchesRegularExpression('/^oh_[A-Za-z0-9]{48}$/', $token);
        }
    }

    public function test_nfc_space_deduplication_handles_more_than_one_thousand_duplicate_groups(): void
    {
        $spaceMigration = require database_path(
            'migrations/2026_07_24_010000_enforce_one_nfc_tag_per_space.php'
        );
        $spaceMigration->down();

        $family = Family::create(['name' => '大批量迁移家庭']);
        $spaceRows = [];
        $tagRows = [];
        for ($group = 1; $group <= 1001; $group++) {
            $spaceId = 10_000 + $group;
            $spaceRows[] = [
                'id' => $spaceId,
                'family_id' => $family->id,
                'name' => "批量空间 {$group}",
            ];
            $tagRows[] = [
                'family_id' => $family->id,
                'space_id' => $spaceId,
                'uid' => 'oh_'.str_pad((string) ($group * 2 - 1), 48, '0', STR_PAD_LEFT),
            ];
            $tagRows[] = [
                'family_id' => $family->id,
                'space_id' => $spaceId,
                'uid' => 'oh_'.str_pad((string) ($group * 2), 48, '0', STR_PAD_LEFT),
            ];
        }
        foreach (array_chunk($spaceRows, 250) as $chunk) {
            DB::table('storage_spaces')->insert($chunk);
        }
        foreach (array_chunk($tagRows, 250) as $chunk) {
            DB::table('nfc_tags')->insert($chunk);
        }

        $spaceMigration->up();

        $duplicateGroups = DB::table('nfc_tags')
            ->select('space_id')
            ->whereNotNull('space_id')
            ->groupBy('space_id')
            ->havingRaw('COUNT(*) > 1')
            ->count();
        $this->assertSame(0, $duplicateGroups);
        $this->assertSame(1001, DB::table('nfc_tags')->whereNotNull('space_id')->count());
        $this->assertSame(1001, DB::table('nfc_tags')->whereNull('space_id')->count());
    }

    public function test_nfc_token_url_is_null_for_malformed_https_public_base_urls(): void
    {
        [, $token] = $this->login('13800000045');
        $familyId = $this->withToken($token)
            ->postJson('/api/families', ['name' => '无效 HTTPS 家庭'])
            ->assertCreated()
            ->json('data.id');
        $spaceId = $this->withToken($token)
            ->postJson('/api/spaces', ['family_id' => $familyId, 'name' => '无效 HTTPS 柜子'])
            ->assertCreated()
            ->json('data.id');

        foreach (['https://', 'https:///missing-host', 'https://?missing-host'] as $baseUrl) {
            config()->set('nfc.public_base_url', $baseUrl);

            $this->withToken($token)
                ->postJson("/api/spaces/{$spaceId}/nfc-token")
                ->assertOk()
                ->assertJsonPath('data.url', null);
        }
    }

    public function test_nfc_token_url_is_null_for_non_origin_https_public_base_urls(): void
    {
        [, $token] = $this->login('13800000046');
        $familyId = $this->withToken($token)
            ->postJson('/api/families', ['name' => '非 Origin HTTPS 家庭'])
            ->assertCreated()
            ->json('data.id');
        $spaceId = $this->withToken($token)
            ->postJson('/api/spaces', ['family_id' => $familyId, 'name' => '非 Origin HTTPS 柜子'])
            ->assertCreated()
            ->json('data.id');

        foreach ([
            'https://example.com/foo',
            'https://example.com?x=1',
            'https://example.com#fragment',
            'https://user@example.com',
            'https://user:secret@example.com',
        ] as $baseUrl) {
            config()->set('nfc.public_base_url', $baseUrl);

            $this->withToken($token)
                ->postJson("/api/spaces/{$spaceId}/nfc-token")
                ->assertOk()
                ->assertJsonPath('data.url', null);
        }
    }

    public function test_nfc_tag_database_allows_only_one_row_per_space_including_soft_deleted_rows(): void
    {
        [, $token] = $this->login('13800000044');
        $familyId = $this->withToken($token)
            ->postJson('/api/families', ['name' => 'NFC 唯一性家庭'])
            ->assertCreated()
            ->json('data.id');
        $spaceId = $this->withToken($token)
            ->postJson('/api/spaces', ['family_id' => $familyId, 'name' => '唯一标签柜子'])
            ->assertCreated()
            ->json('data.id');

        $tag = NfcTag::create([
            'family_id' => $familyId,
            'space_id' => $spaceId,
            'uid' => str_repeat('A', 48),
        ]);
        $tag->delete();

        $this->expectException(QueryException::class);

        NfcTag::create([
            'family_id' => $familyId,
            'space_id' => $spaceId,
            'uid' => str_repeat('B', 48),
        ]);
    }

    public function test_apple_app_site_association_only_matches_nfc_links(): void
    {
        config()->set('nfc.ios_team_id', 'TEAM123456');
        config()->set('nfc.ios_bundle_id', 'com.operationshome.OperationsHome');

        $this->getJson('/.well-known/apple-app-site-association')
            ->assertOk()
            ->assertHeader('Content-Type', 'application/json')
            ->assertExactJson([
                'applinks' => [
                    'details' => [[
                        'appIDs' => ['TEAM123456.com.operationshome.OperationsHome'],
                        'components' => [[
                            '/' => '/nfc/*',
                            'comment' => '运营小家 NFC 空间链接',
                        ]],
                    ]],
                ],
            ])
            ->assertJsonCount(1, 'applinks.details')
            ->assertJsonCount(1, 'applinks.details.0.appIDs')
            ->assertJsonCount(1, 'applinks.details.0.components');
    }

    public function test_reminder_can_be_disabled_and_sync_keeps_state(): void
    {
        [, $token] = $this->login('13800000022');
        $familyId = $this->withToken($token)
            ->postJson('/api/families', ['name' => '提醒家庭'])
            ->assertCreated()
            ->json('data.id');
        $reminderId = $this->withToken($token)
            ->postJson('/api/reminders', [
                'family_id' => $familyId,
                'title' => '缴费',
                'remind_at' => now()->addDay()->toIso8601String(),
            ])
            ->assertCreated()
            ->assertJsonPath('data.is_enabled', true)
            ->json('data.id');

        $this->withToken($token)->patchJson("/api/reminders/{$reminderId}", [
            'title' => '暂停的提醒',
            'is_enabled' => false,
        ])->assertOk()
            ->assertJsonPath('data.is_enabled', false);

        $this->withToken($token)->getJson("/api/sync?family_id={$familyId}")
            ->assertOk()
            ->assertJsonPath('data.reminders.0.is_enabled', false);
    }

    public function test_sync_push_cannot_modify_another_familys_records(): void
    {
        [, $attackerToken] = $this->login('13800000030');
        [, $ownerToken] = $this->login('13800000031');

        $attackerFamilyId = $this->withToken($attackerToken)
            ->postJson('/api/families', ['name' => '攻击者家庭'])
            ->assertCreated()
            ->json('data.id');
        $targetFamilyId = $this->withToken($ownerToken)
            ->postJson('/api/families', ['name' => '目标家庭'])
            ->assertCreated()
            ->json('data.id');
        $targetSpaceId = $this->withToken($ownerToken)
            ->postJson('/api/spaces', ['family_id' => $targetFamilyId, 'name' => '目标空间'])
            ->assertCreated()
            ->json('data.id');
        $targetItemId = $this->withToken($ownerToken)
            ->postJson('/api/items', [
                'family_id' => $targetFamilyId,
                'space_id' => $targetSpaceId,
                'name' => '目标物品',
                'quantity' => 1,
            ])->assertCreated()->json('data.id');
        $targetReminderId = $this->withToken($ownerToken)
            ->postJson('/api/reminders', [
                'family_id' => $targetFamilyId,
                'title' => '目标提醒',
                'remind_at' => now()->addDay()->toIso8601String(),
            ])->assertCreated()->json('data.id');

        foreach ([
            ['spaces' => [[
                'id' => $targetSpaceId,
                'family_id' => $targetFamilyId,
                'name' => '越权空间',
            ]]],
            ['items' => [[
                'id' => $targetItemId,
                'family_id' => $targetFamilyId,
                'space_id' => $targetSpaceId,
                'name' => '越权物品',
                'quantity' => 99,
            ]]],
            ['reminders' => [[
                'id' => $targetReminderId,
                'family_id' => $targetFamilyId,
                'title' => '越权提醒',
                'remind_at' => now()->addWeek()->toIso8601String(),
            ]]],
        ] as $payload) {
            $this->withToken($attackerToken)
                ->postJson('/api/sync/push', ['family_id' => $attackerFamilyId] + $payload)
                ->assertStatus(422);
        }

        $this->assertDatabaseHas('storage_spaces', ['id' => $targetSpaceId, 'name' => '目标空间']);
        $this->assertDatabaseHas('items', ['id' => $targetItemId, 'name' => '目标物品', 'quantity' => 1]);
        $this->assertDatabaseHas('reminders', ['id' => $targetReminderId, 'title' => '目标提醒']);
    }

    public function test_sync_push_updates_and_creates_records_in_the_authorized_family(): void
    {
        [, $token] = $this->login('13800000032');
        $familyId = $this->withToken($token)
            ->postJson('/api/families', ['name' => '同步家庭'])
            ->assertCreated()
            ->json('data.id');
        $spaceId = $this->withToken($token)
            ->postJson('/api/spaces', ['family_id' => $familyId, 'name' => '同步前空间'])
            ->assertCreated()
            ->json('data.id');

        $this->withToken($token)->postJson('/api/sync/push', [
            'family_id' => $familyId,
            'spaces' => [[
                'id' => $spaceId,
                'family_id' => $familyId + 1000,
                'name' => '同步后空间',
            ]],
            'items' => [[
                'family_id' => $familyId + 1000,
                'space_id' => $spaceId,
                'name' => '同步物品',
                'quantity' => 3,
            ]],
            'reminders' => [[
                'family_id' => $familyId + 1000,
                'title' => '同步提醒',
                'remind_at' => now()->addDay()->toIso8601String(),
            ]],
        ])->assertOk();

        $this->assertDatabaseHas('storage_spaces', [
            'id' => $spaceId,
            'family_id' => $familyId,
            'name' => '同步后空间',
        ]);
        $this->assertDatabaseHas('items', [
            'family_id' => $familyId,
            'space_id' => $spaceId,
            'name' => '同步物品',
            'quantity' => 3,
        ]);
        $this->assertDatabaseHas('reminders', [
            'family_id' => $familyId,
            'title' => '同步提醒',
        ]);
    }

    public function test_sync_push_rolls_back_the_batch_when_a_later_record_is_invalid(): void
    {
        [, $token] = $this->login('13800000033');
        $familyId = $this->withToken($token)
            ->postJson('/api/families', ['name' => '事务家庭'])
            ->assertCreated()
            ->json('data.id');
        $spaceId = $this->withToken($token)
            ->postJson('/api/spaces', ['family_id' => $familyId, 'name' => '原空间名'])
            ->assertCreated()
            ->json('data.id');

        $this->withToken($token)->postJson('/api/sync/push', [
            'family_id' => $familyId,
            'spaces' => [[
                'id' => $spaceId,
                'name' => '不应保留的空间名',
            ]],
            'items' => [[
                'space_id' => 999999,
                'name' => '无效物品',
                'quantity' => 1,
            ]],
        ])->assertStatus(422);

        $this->assertDatabaseHas('storage_spaces', [
            'id' => $spaceId,
            'name' => '原空间名',
        ]);
    }

    public function test_sync_push_requires_a_space_for_new_items(): void
    {
        [, $token] = $this->login('13800000034');
        $familyId = $this->withToken($token)
            ->postJson('/api/families', ['name' => '必填空间家庭'])
            ->assertCreated()
            ->json('data.id');

        foreach ([[], ['space_id' => null]] as $spacePayload) {
            $this->withToken($token)->postJson('/api/sync/push', [
                'family_id' => $familyId,
                'items' => [[
                    'name' => '无空间物品',
                    'quantity' => 1,
                ] + $spacePayload],
            ])->assertStatus(422)
                ->assertJsonValidationErrors('items.0.space_id');
        }

        $this->assertDatabaseMissing('items', [
            'family_id' => $familyId,
            'name' => '无空间物品',
        ]);
    }

    private function login(string $phone): array
    {
        $this->postJson('/api/auth/sms/send', ['phone' => $phone])->assertOk();

        $response = $this->postJson('/api/auth/sms/verify', [
            'phone' => $phone,
            'code' => '123456',
        ])->assertOk();

        return [User::where('phone', $phone)->firstOrFail(), $response->json('data.token')];
    }

    private function fakePngUpload(): UploadedFile
    {
        $path = tempnam(sys_get_temp_dir(), 'operations-home-image-');
        file_put_contents($path, base64_decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMB/axm'
            .'ZAAAAABJRU5ErkJggg=='
        ));

        return new UploadedFile($path, 'cabinet.png', 'image/png', null, true);
    }
}
