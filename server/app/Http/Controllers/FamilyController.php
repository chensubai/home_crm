<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\AuthorizesFamilyAccess;
use App\Models\Family;
use App\Models\FamilyInvite;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class FamilyController extends Controller
{
    use AuthorizesFamilyAccess;

    public function index(Request $request)
    {
        return $this->ok($request->user()->families()->with('members.user')->get());
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:80'],
        ]);

        $family = Family::create($data);
        $family->members()->create([
            'user_id' => $request->user()->id,
            'role' => 'owner',
        ]);

        return $this->ok($family->load('members.user'), 201);
    }

    public function invite(Request $request, Family $family)
    {
        $this->authorizeFamily($request->user(), $family, 'owner');

        $data = $request->validate([
            'phone' => ['nullable', 'string', 'max:32'],
        ]);

        $invite = $family->invites()->create([
            'code' => Str::upper(Str::random(8)),
            'phone' => $data['phone'] ?? null,
            'created_by' => $request->user()->id,
            'expires_at' => now()->addDays(7),
        ]);

        return $this->ok($invite, 201);
    }

    public function acceptInvite(Request $request, string $code)
    {
        $invite = FamilyInvite::query()
            ->where('code', Str::upper($code))
            ->whereNull('accepted_at')
            ->where('expires_at', '>', now())
            ->first();

        if (! $invite) {
            throw ValidationException::withMessages(['code' => '邀请不存在或已过期']);
        }

        $invite->family->members()->firstOrCreate(
            ['user_id' => $request->user()->id],
            ['role' => 'member']
        );
        $invite->update(['accepted_at' => now()]);

        return $this->ok($invite->family->load('members.user'));
    }

    public function members(Request $request, Family $family)
    {
        $this->authorizeFamily($request->user(), $family);

        return $this->ok($family->members()->with('user')->get());
    }
}
