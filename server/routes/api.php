<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\FamilyController;
use App\Http\Controllers\ItemController;
use App\Http\Controllers\ReminderController;
use App\Http\Controllers\SpaceController;
use App\Http\Controllers\SyncController;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => [
    'ok' => true,
    'name' => '运营小家 API',
]);

Route::post('/auth/sms/send', [AuthController::class, 'sendSms']);
Route::post('/auth/sms/verify', [AuthController::class, 'verifySms']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    Route::get('/families', [FamilyController::class, 'index']);
    Route::post('/families', [FamilyController::class, 'store']);
    Route::post('/families/{family}/invites', [FamilyController::class, 'invite']);
    Route::post('/invites/{code}/accept', [FamilyController::class, 'acceptInvite']);
    Route::get('/families/{family}/members', [FamilyController::class, 'members']);

    Route::apiResource('/spaces', SpaceController::class)->except(['show']);
    Route::apiResource('/items', ItemController::class)->except(['show']);
    Route::post('/items/{item}/adjust', [ItemController::class, 'adjust']);

    Route::apiResource('/reminders', ReminderController::class)->except(['show']);
    Route::post('/reminders/{reminder}/complete', [ReminderController::class, 'complete']);

    Route::get('/sync', [SyncController::class, 'pull']);
    Route::post('/sync/push', [SyncController::class, 'push']);
});
