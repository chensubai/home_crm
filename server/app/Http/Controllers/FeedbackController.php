<?php

namespace App\Http\Controllers;

use App\Models\Feedback;
use Illuminate\Http\Request;

class FeedbackController extends Controller
{
    public function store(Request $request)
    {
        $data = $request->validate([
            'content' => ['required', 'string', 'max:5000'],
        ]);

        return $this->ok(Feedback::create([
            'user_id' => $request->user()->id,
            'content' => $data['content'],
        ]), 201);
    }
}
