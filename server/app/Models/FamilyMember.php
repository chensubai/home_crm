<?php

namespace App\Models;

use App\Models\Model;

class FamilyMember extends Model
{
    protected $fillable = ['family_id', 'user_id', 'role'];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function family()
    {
        return $this->belongsTo(Family::class);
    }
}
