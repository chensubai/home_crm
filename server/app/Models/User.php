<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens;
    use HasFactory;
    use Notifiable;

    protected $fillable = ['phone', 'name'];

    protected $hidden = ['remember_token'];

    public function families()
    {
        return $this->belongsToMany(Family::class, 'family_members')->withPivot('role')->withTimestamps();
    }

    public function familyMemberships()
    {
        return $this->hasMany(FamilyMember::class);
    }
}
