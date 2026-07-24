<?php

use App\Http\Controllers\NfcController;
use Illuminate\Support\Facades\Route;

Route::get('/.well-known/apple-app-site-association', [NfcController::class, 'association']);
