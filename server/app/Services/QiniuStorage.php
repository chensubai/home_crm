<?php

namespace App\Services;

use App\Exceptions\QiniuUploadException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Str;
use Qiniu\Auth;
use Qiniu\Config;
use Qiniu\Region;
use Qiniu\Storage\UploadManager;
use Qiniu\Zone;
use RuntimeException;
use Throwable;

class QiniuStorage
{
    public function uploadImage(UploadedFile $file, int $familyId, string $directory = 'images'): array
    {
        $this->ensureConfigured();

        $key = $this->makeKey($file, $familyId, $directory);
        $auth = $this->auth();
        $uploadToken = $auth->uploadToken((string) config('services.qiniu.bucket'));
        $uploadManager = new UploadManager($this->qiniuConfig());

        try {
            [$payload, $error] = $uploadManager->putFile(
                $uploadToken,
                $key,
                (string) $file->getRealPath()
            );
        } catch (Throwable $exception) {
            throw new QiniuUploadException(0, $exception->getMessage());
        }

        if ($error !== null) {
            throw new QiniuUploadException((int) $error->code(), (string) $error->message());
        }

        $payload ??= [];

        return [
            'key' => $key,
            'hash' => $payload['hash'] ?? null,
            'url' => $this->url($key),
        ];
    }

    public function url(string $key): string
    {
        $baseUrl = $this->publicResourceUrl($key);

        if (! config('services.qiniu.private')) {
            return $baseUrl;
        }

        return $this->auth()->privateDownloadUrl($baseUrl, (int) config('services.qiniu.url_ttl'));
    }

    private function publicResourceUrl(string $key): string
    {
        $domain = rtrim((string) config('services.qiniu.domain'), '/');
        if (! str_starts_with($domain, 'http://') && ! str_starts_with($domain, 'https://')) {
            $domain = 'https://'.$domain;
        }
        $domain = preg_replace('/^http:\/\//', 'https://', $domain);
        $encodedKey = implode('/', array_map('rawurlencode', explode('/', ltrim($key, '/'))));

        return $domain.'/'.$encodedKey;
    }

    private function makeKey(UploadedFile $file, int $familyId, string $directory): string
    {
        $extension = strtolower($file->getClientOriginalExtension() ?: $file->extension() ?: 'jpg');
        $directory = trim($directory, '/');

        return sprintf(
            'families/%d/%s/%s.%s',
            $familyId,
            $directory,
            (string) Str::uuid(),
            $extension
        );
    }

    private function ensureConfigured(): void
    {
        foreach (['access_key', 'secret_key', 'bucket', 'domain'] as $key) {
            if (! config('services.qiniu.'.$key)) {
                throw new RuntimeException('七牛云配置缺失：QINIU_'.strtoupper($key));
            }
        }
    }

    private function auth(): Auth
    {
        return new Auth(
            (string) config('services.qiniu.access_key'),
            (string) config('services.qiniu.secret_key')
        );
    }

    private function qiniuConfig(): Config
    {
        $config = new Config($this->zone());
        $config->useHTTPS = true;

        return $config;
    }

    private function zone(): Region
    {
        return match ((string) config('services.qiniu.region', 'z1')) {
            'z0' => Zone::zonez0(),
            'z2' => Zone::zonez2(),
            'cn-east-2' => Zone::zoneCnEast2(),
            'as0' => Zone::zoneAs0(),
            'na0' => Zone::zoneNa0(),
            default => Zone::zonez1(),
        };
    }
}
