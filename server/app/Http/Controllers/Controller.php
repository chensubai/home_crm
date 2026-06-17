<?php

namespace App\Http\Controllers;

use Illuminate\Routing\Controller as BaseController;

abstract class Controller extends BaseController
{
    protected function ok(mixed $data = null, int $status = 200)
    {
        return response()->json([
            'ok' => true,
            'data' => $data,
        ], $status);
    }
}
