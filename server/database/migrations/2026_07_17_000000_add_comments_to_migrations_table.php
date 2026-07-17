<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        DB::statement("ALTER TABLE `migrations` COMMENT = '数据库迁移记录表，保存已执行迁移及批次'");

        Schema::table('migrations', function (Blueprint $table): void {
            $table->unsignedInteger('id')->autoIncrement()->comment('迁移记录ID')->change();
            $table->string('migration')->comment('迁移文件名称')->change();
            $table->integer('batch')->comment('迁移执行批次')->change();
        });
    }

    public function down(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        DB::statement("ALTER TABLE `migrations` COMMENT = ''");

        Schema::table('migrations', function (Blueprint $table): void {
            $table->unsignedInteger('id')->autoIncrement()->comment('')->change();
            $table->string('migration')->comment('')->change();
            $table->integer('batch')->comment('')->change();
        });
    }
};
