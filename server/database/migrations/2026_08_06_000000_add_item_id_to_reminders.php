<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('reminders', function (Blueprint $table): void {
            $table->foreignId('item_id')->nullable()->after('family_id')->constrained('items')->nullOnDelete();
            $table->unique('item_id');
        });
    }

    public function down(): void
    {
        Schema::table('reminders', function (Blueprint $table): void {
            $table->dropUnique(['item_id']);
            $table->dropConstrainedForeignId('item_id');
        });
    }
};
