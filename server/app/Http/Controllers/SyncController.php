<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\AuthorizesFamilyAccess;
use App\Models\Item;
use App\Models\Reminder;
use App\Models\StorageSpace;
use App\Services\QiniuStorage;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SyncController extends Controller
{
    use AuthorizesFamilyAccess;

    public function pull(Request $request, QiniuStorage $storage)
    {
        $data = $request->validate([
            'family_id' => ['required', 'integer', 'exists:families,id'],
            'since' => ['nullable', 'date'],
        ]);
        $this->authorizeFamily($request->user(), (int) $data['family_id']);

        $since = isset($data['since']) ? Carbon::parse($data['since']) : Carbon::createFromTimestamp(0);
        $familyId = (int) $data['family_id'];

        return $this->ok([
            'cursor' => now()->utc()->toJSON(),
            'spaces' => StorageSpace::withTrashed()->with('nfcTags')->where('family_id', $familyId)->where('updated_at', '>', $since)->get()->map(
                fn (StorageSpace $space) => $this->withImageUrl($space, $storage)
            ),
            'items' => Item::withTrashed()->where('family_id', $familyId)->where('updated_at', '>', $since)->get()->map(
                fn (Item $item) => $this->withImageUrl($item, $storage)
            ),
            'reminders' => Reminder::withTrashed()->where('family_id', $familyId)->where('updated_at', '>', $since)->get(),
        ]);
    }

    public function push(Request $request)
    {
        $data = $request->validate([
            'family_id' => ['required', 'integer', 'exists:families,id'],
            'spaces' => ['array'],
            'spaces.*' => ['array'],
            'items' => ['array'],
            'items.*' => ['array'],
            'reminders' => ['array'],
            'reminders.*' => ['array'],
        ]);
        $familyId = (int) $data['family_id'];
        $this->authorizeFamily($request->user(), $familyId);

        DB::transaction(function () use ($data, $familyId): void {
            foreach ($data['spaces'] ?? [] as $index => $space) {
                $this->syncRecord(
                    StorageSpace::class,
                    $familyId,
                    $space,
                    ['name', 'description', 'image_key', 'image_url', 'image_hash', 'deleted_at', 'updated_at'],
                    "spaces.{$index}.id"
                );
            }

            foreach ($data['items'] ?? [] as $index => $item) {
                $hasSpaceId = array_key_exists('space_id', $item);
                if ((! isset($item['id']) && ! $hasSpaceId) || ($hasSpaceId && $item['space_id'] === null)) {
                    throw ValidationException::withMessages([
                        "items.{$index}.space_id" => '存放空间不能为空',
                    ]);
                }

                if ($hasSpaceId) {
                    $spaceExists = StorageSpace::query()
                        ->whereKey((int) $item['space_id'])
                        ->where('family_id', $familyId)
                        ->exists();
                    if (! $spaceExists) {
                        throw ValidationException::withMessages([
                            "items.{$index}.space_id" => '存放空间不属于当前家庭',
                        ]);
                    }
                }

                $this->syncRecord(
                    Item::class,
                    $familyId,
                    $item,
                    ['space_id', 'name', 'category', 'quantity', 'unit', 'barcode', 'expires_at', 'status', 'notes', 'image_key', 'image_url', 'image_hash', 'deleted_at', 'updated_at'],
                    "items.{$index}.id"
                );
            }

            foreach ($data['reminders'] ?? [] as $index => $reminder) {
                $this->syncRecord(
                    Reminder::class,
                    $familyId,
                    $reminder,
                    ['assignee_id', 'title', 'kind', 'remind_at', 'repeat_rule', 'repeat_value', 'is_enabled', 'notes', 'completed_at', 'deleted_at', 'updated_at'],
                    "reminders.{$index}.id"
                );
            }
        });

        return $this->pull($request, app(QiniuStorage::class));
    }

    private function syncRecord(string $modelClass, int $familyId, array $payload, array $fields, string $idField): void
    {
        if (isset($payload['id'])) {
            $record = $modelClass::withTrashed()
                ->whereKey((int) $payload['id'])
                ->where('family_id', $familyId)
                ->first();

            if (! $record) {
                throw ValidationException::withMessages([
                    $idField => '同步记录不属于当前家庭',
                ]);
            }
        } else {
            $record = new $modelClass;
        }

        $attributes = collect($payload)->only($fields)->all();
        $attributes['family_id'] = $familyId;
        $record->forceFill($attributes)->save();
    }

    private function withImageUrl(StorageSpace|Item $record, QiniuStorage $storage): StorageSpace|Item
    {
        if ($record->image_key !== null) {
            $record->image_url = $storage->url($record->image_key);
        }
        if ($record instanceof StorageSpace) {
            $record->setAttribute('nfc_uid', $record->nfcTags->first()?->uid);
        }

        return $record;
    }
}
