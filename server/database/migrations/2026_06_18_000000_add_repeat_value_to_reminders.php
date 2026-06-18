<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reminders', function (Blueprint $table) {
            $table->string('repeat_value', 64)->nullable()->after('repeat_rule')->comment('重复规则附加值：weekly存星期编号逗号列表，monthly存每月日期号');
        });
    }

    public function down(): void
    {
        Schema::table('reminders', function (Blueprint $table) {
            $table->dropColumn('repeat_value');
        });
    }
};
