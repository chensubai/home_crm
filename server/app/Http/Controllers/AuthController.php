<?php

namespace App\Http\Controllers;

use App\Models\SmsCode;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function sendSms(Request $request)
    {
        $data = $request->validate([
            'phone' => ['required', 'string', 'max:32'],
        ]);

        $code = app()->environment('production') ? (string) random_int(100000, 999999) : '123456';

        SmsCode::create([
            'phone' => $data['phone'],
            'code_hash' => Hash::make($code),
            'expires_at' => now()->addMinutes(10),
        ]);

        return $this->ok([
            'expires_in' => 600,
            'mock_code' => app()->environment('production') ? null : $code,
        ]);
    }

    public function verifySms(Request $request)
    {
        $data = $request->validate([
            'phone' => ['required', 'string', 'max:32'],
            'code' => ['required', 'string', 'size:6'],
            'name' => ['nullable', 'string', 'max:80'],
        ]);

        $sms = SmsCode::query()
            ->where('phone', $data['phone'])
            ->whereNull('used_at')
            ->where('expires_at', '>', now())
            ->latest()
            ->first();

        if (! $sms || ! Hash::check($data['code'], $sms->code_hash)) {
            throw ValidationException::withMessages(['code' => '验证码无效或已过期']);
        }

        $sms->update(['used_at' => now()]);

        $user = User::firstOrCreate(
            ['phone' => $data['phone']],
            ['name' => $data['name'] ?? '家庭成员']
        );

        $token = $user->createToken('ios-'.Str::uuid())->plainTextToken;

        return $this->ok([
            'token' => $token,
            'user' => $user,
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();

        return $this->ok();
    }
}
