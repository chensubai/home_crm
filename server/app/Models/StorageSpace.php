<?php

namespace App\Models;

use App\Models\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class StorageSpace extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'family_id',
        'name',
        'description',
        'image_key',
        'image_url',
        'image_hash',
    ];

    protected $casts = [
        'family_id' => 'integer',
    ];

    public function nfcTags()
    {
        return $this->hasMany(NfcTag::class, 'space_id');
    }

    public function items()
    {
        return $this->hasMany(Item::class, 'space_id');
    }
}
