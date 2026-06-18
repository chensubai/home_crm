<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
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
}
