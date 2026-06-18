<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\AuthorizesFamilyAccess;
use App\Models\Item;
use App\Models\Reminder;
use App\Models\StorageSpace;
use App\Services\QiniuStorage;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

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
            'spaces' => StorageSpace::withTrashed()->where('family_id', $familyId)->where('updated_at', '>', $since)->get()->map(
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
            'items' => ['array'],
            'reminders' => ['array'],
        ]);
        $this->authorizeFamily($request->user(), (int) $data['family_id']);

        foreach ($data['spaces'] ?? [] as $space) {
            StorageSpace::withTrashed()->updateOrCreate(
                ['id' => $space['id'] ?? null],
                collect($space)->only(['family_id', 'name', 'description', 'image_key', 'image_url', 'image_hash', 'deleted_at', 'updated_at'])->all()
            );
        }

        foreach ($data['items'] ?? [] as $item) {
            Item::withTrashed()->updateOrCreate(
                ['id' => $item['id'] ?? null],
                collect($item)->only(['family_id', 'space_id', 'name', 'category', 'quantity', 'unit', 'barcode', 'expires_at', 'status', 'notes', 'image_key', 'image_url', 'image_hash', 'deleted_at', 'updated_at'])->all()
            );
        }

        foreach ($data['reminders'] ?? [] as $reminder) {
            Reminder::withTrashed()->updateOrCreate(
                ['id' => $reminder['id'] ?? null],
                collect($reminder)->only(['family_id', 'assignee_id', 'title', 'kind', 'remind_at', 'repeat_rule', 'notes', 'completed_at', 'deleted_at', 'updated_at'])->all()
            );
        }

        return $this->pull($request, app(QiniuStorage::class));
    }

    private function withImageUrl(StorageSpace|Item $record, QiniuStorage $storage): StorageSpace|Item
    {
        if ($record->image_key !== null) {
            $record->image_url = $storage->url($record->image_key);
        }

        return $record;
    }
}
