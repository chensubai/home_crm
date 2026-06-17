<?php

use Illuminate\Support\Facades\Artisan;

Artisan::command('app:about', function () {
    $this->info('Operations Home API');
});
