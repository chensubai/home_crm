<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SmsCode extends Model
{
    protected $fillable = ['phone', 'code_hash', 'expires_at', 'used_at'];

    protected $casts = [
        'expires_at' => 'datetime',
        'used_at' => 'datetime',
    ];
}
