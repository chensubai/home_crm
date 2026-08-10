<?php

namespace App\Models;

use App\Models\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Family extends Model
{
    use SoftDeletes;

    protected $fillable = ['name'];

    public function members()
    {
        return $this->hasMany(FamilyMember::class);
    }

    public function invites()
    {
        return $this->hasMany(FamilyInvite::class);
    }
}
