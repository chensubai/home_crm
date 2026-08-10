<?php

namespace App\Models\Concerns;

use DateTimeInterface;

trait SerializesDates
{
    public function serializeDate(DateTimeInterface $date): string
    {
        return $date->format('Y-m-d H:i:s');
    }
}
