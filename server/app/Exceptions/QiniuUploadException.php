<?php

namespace App\Exceptions;

use RuntimeException;

class QiniuUploadException extends RuntimeException
{
    public function __construct(
        public readonly int $status,
        public readonly string $responseBody,
    ) {
        parent::__construct('七牛云上传失败：'.$responseBody, $status);
    }
}
