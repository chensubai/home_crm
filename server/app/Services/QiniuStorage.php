<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use RuntimeException;

class QiniuStorage
{
    public function uploadImage(UploadedFile $file, int $familyId, string $directory = 'images'): array
    {
        $this->ensureConfigured();

        $key = $this->makeKey($file, $familyId, $directory);
        $response = Http::attach(
            'file',
            file_get_contents($file->getRealPath()),
            $file->getClientOriginalName()
        )->post((string) config('services.qiniu.upload_url'), [
            'token' => $this->uploadToken($key),
            'key' => $key,
        ]);

        if (! $response->successful()) {
            throw new RuntimeException('七牛云上传失败：'.$response->body());
        }

        $payload = $response->json();

        return [
            'key' => $key,
            'hash' => $payload['hash'] ?? null,
            'url' => $this->url($key),
        ];
    }

    public function url(string $key): string
    {
        $domain = rtrim((string) config('services.qiniu.domain'), '/');
        $baseUrl = $domain.'/'.str_replace('%2F', '/', rawurlencode($key));

        if (! config('services.qiniu.private')) {
            return $baseUrl;
        }

        $deadline = now()->addSeconds((int) config('services.qiniu.url_ttl'))->timestamp;
        $downloadUrl = $baseUrl.(str_contains($baseUrl, '?') ? '&' : '?').'e='.$deadline;
        $token = config('services.qiniu.access_key').':'.$this->base64UrlSafe(
            hash_hmac('sha1', $downloadUrl, (string) config('services.qiniu.secret_key'), true)
        );

        return $downloadUrl.'&token='.$token;
    }

    private function uploadToken(string $key): string
    {
        $policy = $this->base64UrlSafe(json_encode([
            'scope' => config('services.qiniu.bucket').':'.$key,
            'deadline' => now()->addHour()->timestamp,
            'mimeLimit' => 'image/*',
        ], JSON_UNESCAPED_SLASHES));

        $sign = $this->base64UrlSafe(hash_hmac('sha1', $policy, (string) config('services.qiniu.secret_key'), true));

        return config('services.qiniu.access_key').':'.$sign.':'.$policy;
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

    private function base64UrlSafe(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
