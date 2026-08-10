<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use App\Models\Concerns\SerializesDates;

class User extends Authenticatable
{
    use SerializesDates;
    use HasApiTokens;
    use HasFactory;
    use Notifiable;

    protected $fillable = [
        'phone',
        'name',
        'avatar_key',
        'avatar_url',
        'avatar_hash',
    ];

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
