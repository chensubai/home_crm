<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('storage_spaces', 'image_key')) {
            Schema::table('storage_spaces', function (Blueprint $table) {
                $table->string('image_key', 500)->nullable()->after('description')->comment('七牛云空间图片对象 key');
                $table->string('image_url', 1000)->nullable()->after('image_key')->comment('空间图片访问地址');
                $table->string('image_hash', 120)->nullable()->after('image_url')->comment('七牛云空间图片 hash');
            });
        }

        if (! Schema::hasColumn('items', 'image_key')) {
            Schema::table('items', function (Blueprint $table) {
                $table->string('image_key', 500)->nullable()->after('notes')->comment('七牛云物品图片对象 key');
                $table->string('image_url', 1000)->nullable()->after('image_key')->comment('物品图片访问地址');
                $table->string('image_hash', 120)->nullable()->after('image_url')->comment('七牛云物品图片 hash');
            });
        }

        Schema::dropIfExists('media_files');
    }

    public function down(): void
    {
        if (Schema::hasColumn('items', 'image_key')) {
            Schema::table('items', function (Blueprint $table) {
                $table->dropColumn(['image_key', 'image_url', 'image_hash']);
            });
        }

        if (Schema::hasColumn('storage_spaces', 'image_key')) {
            Schema::table('storage_spaces', function (Blueprint $table) {
                $table->dropColumn(['image_key', 'image_url', 'image_hash']);
            });
        }
    }
};
