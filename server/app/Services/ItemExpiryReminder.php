<?php

namespace App\Services;

use App\Models\Item;
use App\Models\Reminder;

class ItemExpiryReminder
{
    public function sync(Item $item): void
    {
        $reminder = Reminder::withTrashed()->where('item_id', $item->id)->first();

        if ($item->expires_at === null || $item->deleted_at !== null) {
            $reminder?->delete();
            return;
        }

        $attributes = [
            'family_id' => $item->family_id,
            'title' => "{$item->name}还有两天过期",
            'kind' => 'item_expiry',
            'remind_at' => $item->expires_at,
            'repeat_rule' => 'none',
            'is_enabled' => true,
            'completed_at' => null,
            'deleted_at' => null,
        ];

        if ($reminder) {
            $reminder->restore();
            $reminder->update($attributes);
            return;
        }

        Reminder::create($attributes + ['item_id' => $item->id]);
    }
}
