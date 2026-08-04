<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('feedback', function (Blueprint $table) {
            $table->comment('用户反馈表，记录用户提交的产品意见和问题');
            $table->id()->comment('反馈ID');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete()->comment('提交用户ID');
            $table->text('content')->comment('反馈内容');
            $table->string('status', 16)->default('pending')->comment('处理状态：pending=待处理，resolved=已处理');
            $table->timestamp('created_at')->nullable();
            $table->timestamp('updated_at')->nullable();
            $table->index(['user_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('feedback');
    }
};
