<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Item extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'family_id',
        'space_id',
        'name',
        'category',
        'quantity',
        'unit',
        'barcode',
        'expires_at',
        'status',
        'notes',
        'image_key',
        'image_url',
        'image_hash',
    ];

    protected $casts = [
        'family_id' => 'integer',
        'space_id' => 'integer',
        'quantity' => 'integer',
        'expires_at' => 'datetime',
    ];
}
