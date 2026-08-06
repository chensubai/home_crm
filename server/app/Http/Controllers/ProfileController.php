<?php

namespace App\Http\Controllers;

use App\Exceptions\QiniuUploadException;
use App\Models\User;
use App\Services\QiniuStorage;
use Illuminate\Http\Request;

class ProfileController extends Controller
{
    public function show(Request $request, QiniuStorage $storage)
    {
        return $this->ok($this->withAvatarUrl($request->user(), $storage));
    }

    public function update(Request $request, QiniuStorage $storage)
    {
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:80'],
            'avatar' => ['nullable', 'image', 'max:10240'],
        ]);

        if (isset($data['avatar'])) {
            try {
                $uploaded = $storage->uploadAvatar($data['avatar'], $request->user()->id);
                $storage->uploadThumbnail($data['avatar'], $uploaded['key']);
            } catch (QiniuUploadException $exception) {
                return $this->fail(
                    '七牛云头像上传失败，请检查七牛云配置。',
                    502,
                    [
                        'qiniu_status' => $exception->status,
                        'qiniu_response' => $exception->responseBody,
                    ]
                );
            }

            unset($data['avatar']);
            $data = array_merge($data, [
                'avatar_key' => $uploaded['key'],
                'avatar_url' => $uploaded['url'],
                'avatar_hash' => $uploaded['hash'],
            ]);
        }

        $request->user()->update($data);

        return $this->ok($this->withAvatarUrl($request->user()->fresh(), $storage));
    }

    private function withAvatarUrl(User $user, QiniuStorage $storage): User
    {
        if ($user->avatar_key !== null) {
            $user->avatar_url = $storage->url($user->avatar_key);
            $user->setAttribute('avatar_thumbnail_url', $storage->thumbnailUrl($user->avatar_key));
        }

        return $user;
    }
}
