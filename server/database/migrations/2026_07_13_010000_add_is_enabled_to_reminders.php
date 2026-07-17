<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('reminders', 'is_enabled')) {
            Schema::table('reminders', function (Blueprint $table) {
                $table->boolean('is_enabled')->default(true)->after('repeat_value')->comment('提醒是否启用：1=启用，0=停用');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('reminders', 'is_enabled')) {
            Schema::table('reminders', function (Blueprint $table) {
                $table->dropColumn('is_enabled');
            });
        }
    }
};
