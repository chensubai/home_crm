<?php

return [
    'qiniu' => [
        'access_key' => env('QINIU_ACCESS_KEY'),
        'secret_key' => env('QINIU_SECRET_KEY'),
        'bucket' => env('QINIU_BUCKET'),
        'domain' => env('QINIU_DOMAIN'),
        'upload_url' => env('QINIU_UPLOAD_URL', 'https://upload.qiniup.com'),
        'private' => (bool) env('QINIU_PRIVATE', false),
        'url_ttl' => (int) env('QINIU_URL_TTL', 3600),
    ],
];
