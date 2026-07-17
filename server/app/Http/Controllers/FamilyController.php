<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\AuthorizesFamilyAccess;
use App\Models\Family;
use App\Models\FamilyInvite;
use App\Models\FamilyMember;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class FamilyController extends Controller
{
    use AuthorizesFamilyAccess;

    public function index(Request $request)
    {
        return $this->ok($request->user()->families()->get()->map(
            fn (Family $family) => $this->familyPayload($family, $family->pivot->role)
        ));
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

        return $this->ok($this->familyPayload($family, 'owner'), 201);
    }

    public function update(Request $request, Family $family)
    {
        $this->authorizeFamily($request->user(), $family, 'owner');
        $data = $request->validate([
            'name' => ['required', 'string', 'max:80'],
        ]);
        $family->update($data);

        return $this->ok($this->familyPayload($family->fresh(), 'owner'));
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

        $membership = $invite->family->members()->firstOrCreate(
            ['user_id' => $request->user()->id],
            ['role' => 'member']
        );
        $invite->update(['accepted_at' => now()]);

        return $this->ok($this->familyPayload($invite->family, $membership->role));
    }

    public function members(Request $request, Family $family)
    {
        $this->authorizeFamily($request->user(), $family);

        return $this->ok($family->members()->with('user')->get()->map(
            fn (FamilyMember $member) => [
                'id' => $member->id,
                'family_id' => $member->family_id,
                'user_id' => $member->user_id,
                'name' => $member->user->name,
                'phone' => $member->user->phone,
                'role' => $member->role,
            ]
        ));
    }

    public function removeMember(Request $request, Family $family, FamilyMember $member)
    {
        $this->authorizeFamily($request->user(), $family, 'owner');
        abort_unless($member->family_id === $family->id, 404);

        if ($member->role === 'owner') {
            return $this->fail('不能移除家庭创建人', 422);
        }

        $member->delete();

        return $this->ok();
    }

    private function familyPayload(Family $family, string $role): array
    {
        return [
            'id' => $family->id,
            'name' => $family->name,
            'role' => $role,
        ];
    }
}
