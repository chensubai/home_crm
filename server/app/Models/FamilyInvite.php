<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class FamilyInvite extends Model
{
    protected $fillable = ['family_id', 'code', 'phone', 'created_by', 'expires_at', 'accepted_at'];

    protected $casts = [
        'expires_at' => 'datetime',
        'accepted_at' => 'datetime',
    ];

    public function family()
    {
        return $this->belongsTo(Family::class);
    }
}
