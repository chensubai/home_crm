<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class PeriodicTask extends Model
{
    use SoftDeletes;

    protected $fillable = ['family_id', 'assignee_id', 'title', 'repeat_rule', 'next_due_at', 'completed_at'];

    protected $casts = [
        'next_due_at' => 'datetime',
        'completed_at' => 'datetime',
    ];
}
