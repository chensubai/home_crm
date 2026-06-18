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

    protected function fail(string $message, int $status = 400, mixed $data = null)
    {
        return response()->json([
            'ok' => false,
            'message' => $message,
            'data' => $data,
        ], $status);
    }
}
