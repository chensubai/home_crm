<?php

namespace App\Http\Controllers;

use App\Exceptions\QiniuUploadException;
use App\Http\Controllers\Concerns\AuthorizesFamilyAccess;
use App\Models\Item;
use App\Models\ItemChange;
use App\Services\QiniuStorage;
use Illuminate\Http\Request;

class ItemController extends Controller
{
    use AuthorizesFamilyAccess;

    public function index(Request $request, QiniuStorage $storage)
    {
        $familyId = (int) $request->query('family_id');
        $this->authorizeFamily($request->user(), $familyId);

        return $this->ok(Item::where('family_id', $familyId)->get()->map(
            fn (Item $item) => $this->withImageUrl($item, $storage)
        ));
    }

    public function store(Request $request, QiniuStorage $storage)
    {
        $data = $request->validate($this->rules(['family_id', 'space_id', 'name', 'quantity']));
        $this->authorizeFamily($request->user(), (int) $data['family_id']);
        try {
            $data = $this->attachImageData($data, $storage, (int) $data['family_id']);
        } catch (QiniuUploadException $exception) {
            return $this->qiniuFailed($exception);
        }

        return $this->ok($this->withImageUrl(Item::create($data), $storage), 201);
    }

    public function update(Request $request, Item $item, QiniuStorage $storage)
    {
        $this->authorizeFamily($request->user(), $item->family_id);
        $data = $request->validate($this->rules([], true));
        try {
            $data = $this->attachImageData($data, $storage, $item->family_id);
        } catch (QiniuUploadException $exception) {
            return $this->qiniuFailed($exception);
        }
        $item->update($data);

        return $this->ok($this->withImageUrl($item->fresh(), $storage));
    }

    public function destroy(Request $request, Item $item)
    {
        $this->authorizeFamily($request->user(), $item->family_id);
        $item->delete();

        return $this->ok();
    }

    public function adjust(Request $request, Item $item, QiniuStorage $storage)
    {
        $this->authorizeFamily($request->user(), $item->family_id);
        $data = $request->validate([
            'delta' => ['required', 'integer'],
            'reason' => ['nullable', 'string', 'max:120'],
        ]);

        $before = $item->quantity;
        $item->increment('quantity', $data['delta']);
        $item->refresh();

        ItemChange::create([
            'family_id' => $item->family_id,
            'item_id' => $item->id,
            'user_id' => $request->user()->id,
            'before_quantity' => $before,
            'after_quantity' => $item->quantity,
            'delta' => $data['delta'],
            'reason' => $data['reason'] ?? null,
        ]);

        return $this->ok($this->withImageUrl($item, $storage));
    }

    private function rules(array $required, bool $partial = false): array
    {
        $mark = fn (string $field) => in_array($field, $required, true) ? 'required' : ($partial ? 'sometimes' : 'nullable');

        return [
            'family_id' => [$mark('family_id'), 'integer', 'exists:families,id'],
            'space_id' => [$mark('space_id'), 'integer', 'exists:storage_spaces,id'],
            'name' => [$mark('name'), 'string', 'max:160'],
            'category' => ['nullable', 'string', 'max:80'],
            'quantity' => [$mark('quantity'), 'integer', 'min:0'],
            'unit' => ['nullable', 'string', 'max:24'],
            'barcode' => ['nullable', 'string', 'max:120'],
            'expires_at' => ['nullable', 'date'],
            'status' => ['nullable', 'in:in_use,idle,expired'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'image' => ['nullable', 'image', 'max:10240'],
        ];
    }

    private function attachImageData(array $data, QiniuStorage $storage, int $familyId): array
    {
        if (! isset($data['image'])) {
            return $data;
        }

        $uploaded = $storage->uploadImage($data['image'], $familyId, 'items');
        unset($data['image']);

        return array_merge($data, [
            'image_key' => $uploaded['key'],
            'image_url' => $uploaded['url'],
            'image_hash' => $uploaded['hash'],
        ]);
    }

    private function withImageUrl(Item $item, QiniuStorage $storage): Item
    {
        if ($item->image_key !== null) {
            $item->image_url = $storage->url($item->image_key);
        }

        return $item;
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
