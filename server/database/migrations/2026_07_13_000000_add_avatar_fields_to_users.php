<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('users', 'avatar_key')) {
            Schema::table('users', function (Blueprint $table) {
                $table->string('avatar_key', 500)->nullable()->after('name')->comment('七牛云用户头像对象 key');
                $table->string('avatar_url', 1000)->nullable()->after('avatar_key')->comment('用户头像访问地址');
                $table->string('avatar_hash', 120)->nullable()->after('avatar_url')->comment('七牛云用户头像 hash');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('users', 'avatar_key')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn(['avatar_key', 'avatar_url', 'avatar_hash']);
            });
        }
    }
};
