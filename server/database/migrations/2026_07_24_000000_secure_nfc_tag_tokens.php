<?php

use App\Support\NfcToken;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $duplicateTokens = DB::table('nfc_tags')
            ->select('uid')
            ->groupBy('uid')
            ->havingRaw('COUNT(*) > 1')
            ->pluck('uid')
            ->all();
        $duplicates = array_fill_keys($duplicateTokens, true);

        DB::table('nfc_tags')
            ->orderBy('id')
            ->chunkById(1000, function ($tags) use ($duplicates): void {
                foreach ($tags as $tag) {
                    if (NfcToken::isCanonical($tag->uid) && ! isset($duplicates[$tag->uid])) {
                        continue;
                    }

                    do {
                        $token = NfcToken::generate();
                    } while (DB::table('nfc_tags')->where('uid', $token)->exists());

                    DB::table('nfc_tags')->where('id', $tag->id)->update(['uid' => $token]);
                }
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
