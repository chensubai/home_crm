<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OperationsHomeApiTest extends TestCase
{
    use RefreshDatabase;

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
                'nfc_uid' => 'nfc-demo-001',
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
        config([
            'services.qiniu.access_key' => 'test-access-key',
            'services.qiniu.secret_key' => 'test-secret-key',
            'services.qiniu.bucket' => 'operations-home-test',
            'services.qiniu.domain' => 'https://cdn.example.com',
            'services.qiniu.upload_url' => 'https://upload.qiniup.com',
        ]);

        Http::fake([
            'upload.qiniup.com' => Http::response([
                'hash' => 'qiniu-file-hash',
            ], 200),
        ]);

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
