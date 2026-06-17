<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->comment('用户账号表，存储家庭成员的登录身份信息');
            $table->id()->comment('用户ID');
            $table->string('phone', 32)->unique()->comment('手机号，作为登录账号');
            $table->string('name', 80)->comment('用户昵称');
            $table->string('remember_token', 100)->nullable()->comment('Laravel 记住登录令牌');
            $table->timestamp('created_at')->nullable()->comment('创建时间');
            $table->timestamp('updated_at')->nullable()->comment('更新时间');
        });

        Schema::create('personal_access_tokens', function (Blueprint $table) {
            $table->comment('Sanctum 访问令牌表，存储移动端 API 登录 token');
            $table->id()->comment('访问令牌ID');
            $table->string('tokenable_type')->comment('令牌所属模型类型');
            $table->unsignedBigInteger('tokenable_id')->comment('令牌所属模型ID');
            $table->string('name')->comment('令牌名称');
            $table->string('token', 64)->unique()->comment('访问令牌哈希值');
            $table->text('abilities')->nullable()->comment('令牌能力范围，JSON 字符串');
            $table->timestamp('last_used_at')->nullable()->comment('最后使用时间');
            $table->timestamp('expires_at')->nullable()->comment('过期时间');
            $table->timestamp('created_at')->nullable()->comment('创建时间');
            $table->timestamp('updated_at')->nullable()->comment('更新时间');
            $table->index(['tokenable_type', 'tokenable_id']);
        });

        Schema::create('sms_codes', function (Blueprint $table) {
            $table->comment('短信验证码表，存储手机号验证码校验记录');
            $table->id()->comment('短信验证码ID');
            $table->string('phone', 32)->index()->comment('接收验证码的手机号');
            $table->string('code_hash')->comment('验证码哈希值');
            $table->timestamp('expires_at')->comment('验证码过期时间');
            $table->timestamp('used_at')->nullable()->comment('验证码使用时间');
            $table->timestamp('created_at')->nullable()->comment('创建时间');
            $table->timestamp('updated_at')->nullable()->comment('更新时间');
        });

        Schema::create('families', function (Blueprint $table) {
            $table->comment('家庭空间表，存储一个家庭共享的数据边界');
            $table->id()->comment('家庭ID');
            $table->string('name', 80)->comment('家庭名称');
            $table->timestamp('created_at')->nullable()->comment('创建时间');
            $table->timestamp('updated_at')->nullable()->comment('更新时间');
            $table->timestamp('deleted_at')->nullable()->comment('软删除时间');
        });

        Schema::create('family_members', function (Blueprint $table) {
            $table->comment('家庭成员表，记录用户在家庭中的成员关系与角色');
            $table->id()->comment('家庭成员关系ID');
            $table->foreignId('family_id')->comment('家庭ID')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->comment('用户ID')->constrained()->cascadeOnDelete();
            $table->string('role', 16)->default('member')->comment('成员角色：owner=拥有者，member=普通成员');
            $table->timestamp('created_at')->nullable()->comment('创建时间');
            $table->timestamp('updated_at')->nullable()->comment('更新时间');
            $table->unique(['family_id', 'user_id']);
        });

        Schema::create('family_invites', function (Blueprint $table) {
            $table->comment('家庭邀请表，存储家庭成员邀请记录');
            $table->id()->comment('邀请ID');
            $table->foreignId('family_id')->comment('家庭ID')->constrained()->cascadeOnDelete();
            $table->string('code', 16)->unique()->comment('邀请码');
            $table->string('phone', 32)->nullable()->comment('被邀请手机号，可为空');
            $table->foreignId('created_by')->comment('邀请创建用户ID')->constrained('users')->cascadeOnDelete();
            $table->timestamp('expires_at')->comment('邀请过期时间');
            $table->timestamp('accepted_at')->nullable()->comment('邀请接受时间');
            $table->timestamp('created_at')->nullable()->comment('创建时间');
            $table->timestamp('updated_at')->nullable()->comment('更新时间');
        });

        Schema::create('storage_spaces', function (Blueprint $table) {
            $table->comment('储物空间表，存储柜子、抽屉、储物间等位置');
            $table->id()->comment('储物空间ID');
            $table->foreignId('family_id')->comment('家庭ID')->constrained()->cascadeOnDelete();
            $table->string('name', 120)->comment('储物空间名称');
            $table->string('description', 500)->nullable()->comment('储物空间描述');
            $table->string('image_key', 500)->nullable()->comment('七牛云空间图片对象 key');
            $table->string('image_url', 1000)->nullable()->comment('空间图片访问地址');
            $table->string('image_hash', 120)->nullable()->comment('七牛云空间图片 hash');
            $table->timestamp('created_at')->nullable()->comment('创建时间');
            $table->timestamp('updated_at')->nullable()->comment('更新时间');
            $table->timestamp('deleted_at')->nullable()->comment('软删除时间');
            $table->index(['family_id', 'updated_at']);
        });

        Schema::create('nfc_tags', function (Blueprint $table) {
            $table->comment('NFC 标签表，存储储物空间绑定的 NFC 标签信息');
            $table->id()->comment('NFC 标签ID');
            $table->foreignId('family_id')->comment('家庭ID')->constrained()->cascadeOnDelete();
            $table->foreignId('space_id')->nullable()->comment('绑定的储物空间ID')->constrained('storage_spaces')->nullOnDelete();
            $table->string('uid', 120)->comment('NFC 标签唯一标识');
            $table->string('label', 120)->nullable()->comment('NFC 标签备注名称');
            $table->timestamp('created_at')->nullable()->comment('创建时间');
            $table->timestamp('updated_at')->nullable()->comment('更新时间');
            $table->timestamp('deleted_at')->nullable()->comment('软删除时间');
            $table->unique(['family_id', 'uid']);
        });

        Schema::create('items', function (Blueprint $table) {
            $table->comment('物品表，存储家庭库存物品清单');
            $table->id()->comment('物品ID');
            $table->foreignId('family_id')->comment('家庭ID')->constrained()->cascadeOnDelete();
            $table->foreignId('space_id')->nullable()->comment('当前存放空间ID')->constrained('storage_spaces')->nullOnDelete();
            $table->string('name', 160)->comment('物品名称');
            $table->string('category', 80)->nullable()->comment('物品分类');
            $table->integer('quantity')->default(0)->comment('库存数量');
            $table->string('unit', 24)->nullable()->comment('数量单位，如个、包、瓶');
            $table->string('barcode', 120)->nullable()->comment('条形码或二维码内容');
            $table->timestamp('expires_at')->nullable()->comment('保质期或过期时间');
            $table->string('status', 16)->default('idle')->comment('物品状态：in_use=使用中，idle=闲置，expired=过期');
            $table->text('notes')->nullable()->comment('物品备注');
            $table->string('image_key', 500)->nullable()->comment('七牛云物品图片对象 key');
            $table->string('image_url', 1000)->nullable()->comment('物品图片访问地址');
            $table->string('image_hash', 120)->nullable()->comment('七牛云物品图片 hash');
            $table->timestamp('created_at')->nullable()->comment('创建时间');
            $table->timestamp('updated_at')->nullable()->comment('更新时间');
            $table->timestamp('deleted_at')->nullable()->comment('软删除时间');
            $table->index(['family_id', 'updated_at']);
            $table->index(['family_id', 'space_id']);
        });

        Schema::create('item_changes', function (Blueprint $table) {
            $table->comment('物品数量变更表，记录库存调整流水');
            $table->id()->comment('变更记录ID');
            $table->foreignId('family_id')->comment('家庭ID')->constrained()->cascadeOnDelete();
            $table->foreignId('item_id')->comment('物品ID')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->comment('操作用户ID')->constrained()->cascadeOnDelete();
            $table->integer('before_quantity')->comment('变更前数量');
            $table->integer('after_quantity')->comment('变更后数量');
            $table->integer('delta')->comment('数量变化值，正数为增加，负数为减少');
            $table->string('reason', 120)->nullable()->comment('变更原因');
            $table->timestamp('created_at')->nullable()->comment('创建时间');
            $table->timestamp('updated_at')->nullable()->comment('更新时间');
        });

        Schema::create('reminders', function (Blueprint $table) {
            $table->comment('提醒表，存储重要日期、周期任务和物品过期提醒');
            $table->id()->comment('提醒ID');
            $table->foreignId('family_id')->comment('家庭ID')->constrained()->cascadeOnDelete();
            $table->foreignId('assignee_id')->nullable()->comment('任务负责人用户ID')->constrained('users')->nullOnDelete();
            $table->string('title', 160)->comment('提醒标题');
            $table->string('kind', 32)->default('important_date')->comment('提醒类型：important_date=重要日期，periodic_task=周期任务，item_expiry=物品过期');
            $table->timestamp('remind_at')->comment('提醒触发时间');
            $table->string('repeat_rule', 16)->default('none')->comment('重复规则：none/daily/weekly/monthly/yearly');
            $table->text('notes')->nullable()->comment('提醒备注');
            $table->timestamp('completed_at')->nullable()->comment('完成时间');
            $table->timestamp('created_at')->nullable()->comment('创建时间');
            $table->timestamp('updated_at')->nullable()->comment('更新时间');
            $table->timestamp('deleted_at')->nullable()->comment('软删除时间');
            $table->index(['family_id', 'updated_at']);
        });

        Schema::create('periodic_tasks', function (Blueprint $table) {
            $table->comment('周期任务表，预留周期性家庭任务的独立扩展数据');
            $table->id()->comment('周期任务ID');
            $table->foreignId('family_id')->comment('家庭ID')->constrained()->cascadeOnDelete();
            $table->foreignId('assignee_id')->nullable()->comment('任务负责人用户ID')->constrained('users')->nullOnDelete();
            $table->string('title', 160)->comment('周期任务标题');
            $table->string('repeat_rule', 16)->default('weekly')->comment('重复规则：daily/weekly/monthly/yearly');
            $table->timestamp('next_due_at')->nullable()->comment('下次截止或提醒时间');
            $table->timestamp('completed_at')->nullable()->comment('最近完成时间');
            $table->timestamp('created_at')->nullable()->comment('创建时间');
            $table->timestamp('updated_at')->nullable()->comment('更新时间');
            $table->timestamp('deleted_at')->nullable()->comment('软删除时间');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('periodic_tasks');
        Schema::dropIfExists('reminders');
        Schema::dropIfExists('item_changes');
        Schema::dropIfExists('items');
        Schema::dropIfExists('nfc_tags');
        Schema::dropIfExists('storage_spaces');
        Schema::dropIfExists('family_invites');
        Schema::dropIfExists('family_members');
        Schema::dropIfExists('families');
        Schema::dropIfExists('sms_codes');
        Schema::dropIfExists('personal_access_tokens');
        Schema::dropIfExists('users');
    }
};
