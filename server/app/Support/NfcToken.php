<?php

namespace App\Support;

use Illuminate\Support\Str;

final class NfcToken
{
    public const PREFIX = 'oh_';

    public const RANDOM_LENGTH = 48;

    public static function generate(): string
    {
        return self::PREFIX.Str::random(self::RANDOM_LENGTH);
    }

    public static function isCanonical(?string $token): bool
    {
        if ($token === null || ! str_starts_with($token, self::PREFIX)) {
            return false;
        }

        $random = substr($token, strlen(self::PREFIX));

        return strlen($random) === self::RANDOM_LENGTH && ctype_alnum($random);
    }
}
