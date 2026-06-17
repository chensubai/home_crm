<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Reminder extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'family_id',
        'assignee_id',
        'title',
        'kind',
        'remind_at',
        'repeat_rule',
        'notes',
        'completed_at',
    ];

    protected $casts = [
        'remind_at' => 'datetime',
        'completed_at' => 'datetime',
    ];
}
