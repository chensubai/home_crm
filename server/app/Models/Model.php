<?php

namespace App\Models;

use App\Models\Concerns\SerializesDates;
use Illuminate\Database\Eloquent\Model as EloquentModel;

abstract class Model extends EloquentModel
{
    use SerializesDates;
}
