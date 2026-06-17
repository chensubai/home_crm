<?php

namespace App\Http\Controllers\Concerns;

use App\Models\Family;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;

trait AuthorizesFamilyAccess
{
    protected function authorizeFamily(User $user, int|Family $family, ?string $role = null): void
    {
        $familyId = $family instanceof Family ? $family->id : $family;

        $member = $user->familyMemberships()->where('family_id', $familyId)->first();

        if (! $member || ($role && $member->role !== $role)) {
            throw new AuthorizationException('无权访问该家庭数据');
        }
    }
}
