<?php

namespace App\Models;

use App\Models\Model;

class Feedback extends Model
{
    protected $table = 'feedback';

    protected $fillable = ['user_id', 'content', 'status'];
}
