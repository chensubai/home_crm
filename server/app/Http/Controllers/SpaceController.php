<?php

namespace App\Http\Controllers;

use App\Exceptions\QiniuUploadException;
use App\Http\Controllers\Concerns\AuthorizesFamilyAccess;
use App\Models\NfcTag;
use App\Models\StorageSpace;
use App\Services\QiniuStorage;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class SpaceController extends Controller
{
    use AuthorizesFamilyAccess;

    public function index(Request $request, QiniuStorage $storage)
    {
        $familyId = (int) $request->query('family_id');
        $this->authorizeFamily($request->user(), $familyId);

        return $this->ok(StorageSpace::where('family_id', $familyId)->with('nfcTags')->get()->map(
            fn (StorageSpace $space) => $this->withImageUrl($space, $storage)
        ));
    }

    public function store(Request $request, QiniuStorage $storage)
    {
        $data = $request->validate([
            'family_id' => ['required', 'integer', 'exists:families,id'],
            'name' => ['required', 'string', 'max:120'],
            'description' => ['nullable', 'string', 'max:500'],
            'nfc_uid' => ['nullable', 'string', 'max:120'],
            'image' => ['nullable', 'image', 'max:10240'],
        ]);
        $this->authorizeFamily($request->user(), (int) $data['family_id']);
        try {
            $data = $this->attachImageData($data, $storage, (int) $data['family_id'], 'spaces');
        } catch (QiniuUploadException $exception) {
            return $this->qiniuFailed($exception);
        }

        $space = StorageSpace::create($data);
        $this->syncNfcTag($space, $data['nfc_uid'] ?? null);

        return $this->ok($this->withImageUrl($space->load('nfcTags'), $storage), 201);
    }

    public function update(Request $request, StorageSpace $space, QiniuStorage $storage)
    {
        $this->authorizeFamily($request->user(), $space->family_id);
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:120'],
            'description' => ['nullable', 'string', 'max:500'],
            'nfc_uid' => ['nullable', 'string', 'max:120'],
            'image' => ['nullable', 'image', 'max:10240'],
        ]);
        try {
            $data = $this->attachImageData($data, $storage, $space->family_id, 'spaces');
        } catch (QiniuUploadException $exception) {
            return $this->qiniuFailed($exception);
        }
        $space->update($data);
        if (array_key_exists('nfc_uid', $data)) {
            $this->syncNfcTag($space, $data['nfc_uid']);
        }

        return $this->ok($this->withImageUrl($space->fresh('nfcTags'), $storage));
    }

    public function destroy(Request $request, StorageSpace $space)
    {
        $this->authorizeFamily($request->user(), $space->family_id);
        if ($space->items()->exists()) {
            return $this->fail('空间内仍有物品，请先移动或删除物品', 422);
        }
        $space->delete();

        return $this->ok();
    }

    private function attachImageData(array $data, QiniuStorage $storage, int $familyId, string $directory): array
    {
        if (! isset($data['image'])) {
            return $data;
        }

        $uploaded = $storage->uploadImage($data['image'], $familyId, $directory);
        unset($data['image']);

        return array_merge($data, [
            'image_key' => $uploaded['key'],
            'image_url' => $uploaded['url'],
            'image_hash' => $uploaded['hash'],
        ]);
    }

    private function withImageUrl(StorageSpace $space, QiniuStorage $storage): StorageSpace
    {
        $space->loadMissing('nfcTags');
        if ($space->image_key !== null) {
            $space->image_url = $storage->url($space->image_key);
        }
        $space->setAttribute('nfc_uid', $space->nfcTags->first()?->uid);

        return $space;
    }

    private function syncNfcTag(StorageSpace $space, ?string $uid): void
    {
        $uid = trim((string) $uid);
        $current = NfcTag::query()->where('space_id', $space->id)->first()
            ?? NfcTag::onlyTrashed()->where('space_id', $space->id)->latest('id')->first();

        if ($uid === '') {
            if ($current && ! $current->trashed()) {
                $current->delete();
            }

            return;
        }

        $sameUid = NfcTag::withTrashed()
            ->where('family_id', $space->family_id)
            ->where('uid', $uid)
            ->first();

        if ($sameUid && $sameUid->space_id !== $space->id && ! $sameUid->trashed()) {
            throw ValidationException::withMessages(['nfc_uid' => 'NFC UID 已绑定其他空间']);
        }

        if ($sameUid && $sameUid->trashed()) {
            if ($current && $current->id !== $sameUid->id && ! $current->trashed()) {
                $current->delete();
            }
            $sameUid->space_id = $space->id;
            $sameUid->save();
            $sameUid->restore();

            return;
        }

        if ($current) {
            $current->uid = $uid;
            $current->family_id = $space->family_id;
            $current->save();
            if ($current->trashed()) {
                $current->restore();
            }

            return;
        }

        $space->nfcTags()->create([
            'family_id' => $space->family_id,
            'uid' => $uid,
        ]);
    }

    private function qiniuFailed(QiniuUploadException $exception)
    {
        return $this->fail(
            '七牛云上传失败，请检查 QINIU_ACCESS_KEY、QINIU_SECRET_KEY、QINIU_BUCKET 和 QINIU_REGION 是否匹配。',
            502,
            [
                'qiniu_status' => $exception->status,
                'qiniu_response' => $exception->responseBody,
            ]
        );
    }
}
