<?php

return [
    'qiniu' => [
        'access_key' => env('QINIU_ACCESS_KEY'),
        'secret_key' => env('QINIU_SECRET_KEY'),
        'bucket' => env('QINIU_BUCKET'),
        'domain' => env('QINIU_DOMAIN'),
        'region' => env('QINIU_REGION', 'z1'),
        'private' => filter_var(env('QINIU_PRIVATE', false), FILTER_VALIDATE_BOOL),
        'url_ttl' => (int) env('QINIU_URL_TTL', 3600),
    ],
];
