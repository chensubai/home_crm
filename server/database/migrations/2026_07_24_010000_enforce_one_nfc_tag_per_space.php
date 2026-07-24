<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('nfc_tags')
            ->select('space_id', DB::raw('MAX(id) as keep_id'))
            ->whereNotNull('space_id')
            ->groupBy('space_id')
            ->havingRaw('COUNT(*) > 1')
            ->orderBy('space_id')
            ->each(function (object $tag): void {
                DB::table('nfc_tags')
                    ->where('space_id', $tag->space_id)
                    ->where('id', '<>', $tag->keep_id)
                    ->update(['space_id' => null]);
            });

        Schema::table('nfc_tags', function (Blueprint $table): void {
            $table->unique('space_id', 'nfc_tags_space_id_unique');
        });
    }

    public function down(): void
    {
        Schema::table('nfc_tags', function (Blueprint $table): void {
            $table->dropUnique('nfc_tags_space_id_unique');
        });
    }
};
