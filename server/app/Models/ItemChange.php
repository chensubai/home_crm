<?php

namespace App\Models;

use App\Models\Model;

class ItemChange extends Model
{
    protected $fillable = [
        'family_id',
        'item_id',
        'user_id',
        'before_quantity',
        'after_quantity',
        'delta',
        'reason',
    ];
}
