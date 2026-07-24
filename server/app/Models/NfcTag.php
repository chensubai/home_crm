<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class NfcTag extends Model
{
    use SoftDeletes;

    protected $fillable = ['family_id', 'space_id', 'uid', 'label'];

    public function space(): BelongsTo
    {
        return $this->belongsTo(StorageSpace::class, 'space_id');
    }
}
