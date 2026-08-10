<?php

namespace App\Models;

use App\Models\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Reminder extends Model
{
    use SoftDeletes;

    protected $attributes = [
        'is_enabled' => true,
    ];

    protected $fillable = [
        'family_id',
        'item_id',
        'assignee_id',
        'title',
        'kind',
        'remind_at',
        'repeat_rule',
        'repeat_value',
        'is_enabled',
        'notes',
        'completed_at',
    ];

    protected $casts = [
        'family_id' => 'integer',
        'item_id' => 'integer',
        'assignee_id' => 'integer',
        'remind_at' => 'datetime',
        'is_enabled' => 'boolean',
        'completed_at' => 'datetime',
    ];

}
