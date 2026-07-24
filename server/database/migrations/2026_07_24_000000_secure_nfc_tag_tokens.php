<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('nfc_tags')->orderBy('id')->each(function (object $tag): void {
            do {
                $token = Str::random(48);
            } while (DB::table('nfc_tags')->where('uid', $token)->exists());

            DB::table('nfc_tags')->where('id', $tag->id)->update(['uid' => $token]);
        });

        Schema::table('nfc_tags', function (Blueprint $table): void {
            $table->index('family_id', 'nfc_tags_family_id_index');
            $table->dropUnique('nfc_tags_family_id_uid_unique');
            $table->unique('uid', 'nfc_tags_uid_unique');
        });
    }

    public function down(): void
    {
        Schema::table('nfc_tags', function (Blueprint $table): void {
            $table->dropUnique('nfc_tags_uid_unique');
            $table->unique(['family_id', 'uid'], 'nfc_tags_family_id_uid_unique');
            $table->dropIndex('nfc_tags_family_id_index');
        });
    }
};
