<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\FamilyController;
use App\Http\Controllers\ItemController;
use App\Http\Controllers\NfcController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\ReminderController;
use App\Http\Controllers\SpaceController;
use App\Http\Controllers\SyncController;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => [
    'ok' => true,
    'name' => '方寸 API',
]);

Route::post('/auth/sms/send', [AuthController::class, 'sendSms']);
Route::post('/auth/sms/verify', [AuthController::class, 'verifySms']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::get('/auth/me', [ProfileController::class, 'show']);
    Route::patch('/profile', [ProfileController::class, 'update']);

    Route::get('/families', [FamilyController::class, 'index']);
    Route::post('/families', [FamilyController::class, 'store']);
    Route::patch('/families/{family}', [FamilyController::class, 'update']);
    Route::post('/families/{family}/invites', [FamilyController::class, 'invite']);
    Route::post('/invites/{code}/accept', [FamilyController::class, 'acceptInvite']);
    Route::get('/families/{family}/members', [FamilyController::class, 'members']);
    Route::delete('/families/{family}/members/{member}', [FamilyController::class, 'removeMember']);

    Route::apiResource('/spaces', SpaceController::class)->except(['show']);
    Route::post('/spaces/{space}/nfc-token', [NfcController::class, 'createToken']);
    Route::get('/nfc/{token}', [NfcController::class, 'resolve']);
    Route::apiResource('/items', ItemController::class)->except(['show']);
    Route::post('/items/{item}/adjust', [ItemController::class, 'adjust']);

    Route::apiResource('/reminders', ReminderController::class)->except(['show']);
    Route::post('/reminders/{reminder}/complete', [ReminderController::class, 'complete']);

    Route::get('/sync', [SyncController::class, 'pull']);
    Route::post('/sync/push', [SyncController::class, 'push']);
});
