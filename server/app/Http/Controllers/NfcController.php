<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\AuthorizesFamilyAccess;
use App\Models\NfcTag;
use App\Models\StorageSpace;
use App\Support\NfcToken;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class NfcController extends Controller
{
    use AuthorizesFamilyAccess;

    public function association()
    {
        $appId = sprintf(
            '%s.%s',
            (string) config('nfc.ios_team_id'),
            (string) config('nfc.ios_bundle_id')
        );

        return response()->json([
            'applinks' => [
                'details' => [[
                    'appIDs' => [$appId],
                    'components' => [[
                        '/' => '/nfc/*',
                        'comment' => '方寸 NFC 空间链接',
                    ]],
                ]],
            ],
        ], 200, ['Content-Type' => 'application/json']);
    }

    public function createToken(Request $request, StorageSpace $space)
    {
        $this->authorizeFamily($request->user(), $space->family_id);
        $tag = DB::transaction(function () use ($space): NfcTag {
            $space = StorageSpace::query()->lockForUpdate()->findOrFail($space->id);
            $tag = NfcTag::withTrashed()
                ->where('space_id', $space->id)
                ->lockForUpdate()
                ->latest('id')
                ->first();

            if (! $tag || ! NfcToken::isCanonical($tag->uid)) {
                do {
                    $token = NfcToken::generate();
                } while (NfcTag::withTrashed()->where('uid', $token)->exists());

                $tag ??= new NfcTag([
                    'family_id' => $space->family_id,
                    'space_id' => $space->id,
                ]);
                $tag->uid = $token;
                $tag->save();
            }

            if ($tag->trashed()) {
                $tag->restore();
            }
            $space->touch();

            return $tag;
        });

        $baseUrl = (string) config('nfc.public_base_url');
        $urlParts = parse_url($baseUrl);
        $url = filter_var($baseUrl, FILTER_VALIDATE_URL)
            && is_array($urlParts)
            && strtolower((string) ($urlParts['scheme'] ?? '')) === 'https'
            && ($urlParts['host'] ?? '') !== ''
            && in_array($urlParts['path'] ?? '', ['', '/'], true)
            && ! array_key_exists('user', $urlParts)
            && ! array_key_exists('pass', $urlParts)
            && ! array_key_exists('query', $urlParts)
            && ! array_key_exists('fragment', $urlParts)
            ? rtrim($baseUrl, '/')."/nfc/{$tag->uid}"
            : null;

        return $this->ok(['token' => $tag->uid, 'url' => $url]);
    }

    public function resolve(Request $request, string $token)
    {
        $tag = NfcTag::query()
            ->with('space')
            ->where('uid', $token)
            ->firstOrFail();
        abort_if($tag->space === null, 404);

        $this->authorizeFamily($request->user(), $tag->space->family_id);

        return $this->ok([
            'space_id' => $tag->space->id,
            'family_id' => $tag->space->family_id,
            'space_name' => $tag->space->name,
        ]);
    }
}
