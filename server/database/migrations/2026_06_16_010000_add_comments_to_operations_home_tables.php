<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    private array $tableComments = [
        'users' => '用户账号表，存储家庭成员的登录身份信息',
        'personal_access_tokens' => 'Sanctum 访问令牌表，存储移动端 API 登录 token',
        'sms_codes' => '短信验证码表，存储手机号验证码校验记录',
        'families' => '家庭空间表，存储一个家庭共享的数据边界',
        'family_members' => '家庭成员表，记录用户在家庭中的成员关系与角色',
        'family_invites' => '家庭邀请表，存储家庭成员邀请记录',
        'storage_spaces' => '储物空间表，存储柜子、抽屉、储物间等位置',
        'nfc_tags' => 'NFC 标签表，存储储物空间绑定的 NFC 标签信息',
        'items' => '物品表，存储家庭库存物品清单',
        'item_changes' => '物品数量变更表，记录库存调整流水',
        'reminders' => '提醒表，存储重要日期、周期任务和物品过期提醒',
        'periodic_tasks' => '周期任务表，预留周期性家庭任务的独立扩展数据',
    ];

    private array $columnComments = [
        'users' => [
            'id' => '用户ID',
            'phone' => '手机号，作为登录账号',
            'name' => '用户昵称',
            'remember_token' => 'Laravel 记住登录令牌',
            'created_at' => '创建时间',
            'updated_at' => '更新时间',
        ],
        'personal_access_tokens' => [
            'id' => '访问令牌ID',
            'tokenable_type' => '令牌所属模型类型',
            'tokenable_id' => '令牌所属模型ID',
            'name' => '令牌名称',
            'token' => '访问令牌哈希值',
            'abilities' => '令牌能力范围，JSON 字符串',
            'last_used_at' => '最后使用时间',
            'expires_at' => '过期时间',
            'created_at' => '创建时间',
            'updated_at' => '更新时间',
        ],
        'sms_codes' => [
            'id' => '短信验证码ID',
            'phone' => '接收验证码的手机号',
            'code_hash' => '验证码哈希值',
            'expires_at' => '验证码过期时间',
            'used_at' => '验证码使用时间',
            'created_at' => '创建时间',
            'updated_at' => '更新时间',
        ],
        'families' => [
            'id' => '家庭ID',
            'name' => '家庭名称',
            'created_at' => '创建时间',
            'updated_at' => '更新时间',
            'deleted_at' => '软删除时间',
        ],
        'family_members' => [
            'id' => '家庭成员关系ID',
            'family_id' => '家庭ID',
            'user_id' => '用户ID',
            'role' => '成员角色：owner=拥有者，member=普通成员',
            'created_at' => '创建时间',
            'updated_at' => '更新时间',
        ],
        'family_invites' => [
            'id' => '邀请ID',
            'family_id' => '家庭ID',
            'code' => '邀请码',
            'phone' => '被邀请手机号，可为空',
            'created_by' => '邀请创建用户ID',
            'expires_at' => '邀请过期时间',
            'accepted_at' => '邀请接受时间',
            'created_at' => '创建时间',
            'updated_at' => '更新时间',
        ],
        'storage_spaces' => [
            'id' => '储物空间ID',
            'family_id' => '家庭ID',
            'name' => '储物空间名称',
            'description' => '储物空间描述',
            'image_key' => '七牛云空间图片对象 key',
            'image_url' => '空间图片访问地址',
            'image_hash' => '七牛云空间图片 hash',
            'created_at' => '创建时间',
            'updated_at' => '更新时间',
            'deleted_at' => '软删除时间',
        ],
        'nfc_tags' => [
            'id' => 'NFC 标签ID',
            'family_id' => '家庭ID',
            'space_id' => '绑定的储物空间ID',
            'uid' => 'NFC 标签唯一标识',
            'label' => 'NFC 标签备注名称',
            'created_at' => '创建时间',
            'updated_at' => '更新时间',
            'deleted_at' => '软删除时间',
        ],
        'items' => [
            'id' => '物品ID',
            'family_id' => '家庭ID',
            'space_id' => '当前存放空间ID',
            'name' => '物品名称',
            'category' => '物品分类',
            'quantity' => '库存数量',
            'unit' => '数量单位，如个、包、瓶',
            'barcode' => '条形码或二维码内容',
            'expires_at' => '保质期或过期时间',
            'status' => '物品状态：in_use=使用中，idle=闲置，expired=过期',
            'notes' => '物品备注',
            'image_key' => '七牛云物品图片对象 key',
            'image_url' => '物品图片访问地址',
            'image_hash' => '七牛云物品图片 hash',
            'created_at' => '创建时间',
            'updated_at' => '更新时间',
            'deleted_at' => '软删除时间',
        ],
        'item_changes' => [
            'id' => '变更记录ID',
            'family_id' => '家庭ID',
            'item_id' => '物品ID',
            'user_id' => '操作用户ID',
            'before_quantity' => '变更前数量',
            'after_quantity' => '变更后数量',
            'delta' => '数量变化值，正数为增加，负数为减少',
            'reason' => '变更原因',
            'created_at' => '创建时间',
            'updated_at' => '更新时间',
        ],
        'reminders' => [
            'id' => '提醒ID',
            'family_id' => '家庭ID',
            'assignee_id' => '任务负责人用户ID',
            'title' => '提醒标题',
            'kind' => '提醒类型：important_date=重要日期，periodic_task=周期任务，item_expiry=物品过期',
            'remind_at' => '提醒触发时间',
            'repeat_rule' => '重复规则：none/daily/weekly/monthly/yearly',
            'notes' => '提醒备注',
            'completed_at' => '完成时间',
            'created_at' => '创建时间',
            'updated_at' => '更新时间',
            'deleted_at' => '软删除时间',
        ],
        'periodic_tasks' => [
            'id' => '周期任务ID',
            'family_id' => '家庭ID',
            'assignee_id' => '任务负责人用户ID',
            'title' => '周期任务标题',
            'repeat_rule' => '重复规则：daily/weekly/monthly/yearly',
            'next_due_at' => '下次截止或提醒时间',
            'completed_at' => '最近完成时间',
            'created_at' => '创建时间',
            'updated_at' => '更新时间',
            'deleted_at' => '软删除时间',
        ],
    ];

    public function up(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        foreach ($this->tableComments as $table => $comment) {
            DB::statement(sprintf(
                'ALTER TABLE %s COMMENT = %s',
                $this->identifier($table),
                $this->literal($comment)
            ));
        }

        foreach ($this->columnComments as $table => $columns) {
            foreach ($columns as $column => $comment) {
                $definition = $this->currentColumnDefinition($table, $column);

                if ($definition === null) {
                    continue;
                }

                DB::statement(sprintf(
                    'ALTER TABLE %s MODIFY COLUMN %s %s COMMENT %s',
                    $this->identifier($table),
                    $this->identifier($column),
                    $definition,
                    $this->literal($comment)
                ));
            }
        }
    }

    public function down(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        foreach ($this->tableComments as $table => $comment) {
            DB::statement(sprintf('ALTER TABLE %s COMMENT = %s', $this->identifier($table), $this->literal('')));
        }

        foreach ($this->columnComments as $table => $columns) {
            foreach (array_keys($columns) as $column) {
                $definition = $this->currentColumnDefinition($table, $column);

                if ($definition === null) {
                    continue;
                }

                DB::statement(sprintf(
                    'ALTER TABLE %s MODIFY COLUMN %s %s COMMENT %s',
                    $this->identifier($table),
                    $this->identifier($column),
                    $definition,
                    $this->literal('')
                ));
            }
        }
    }

    private function currentColumnDefinition(string $table, string $column): ?string
    {
        $schema = DB::getDatabaseName();
        $row = DB::selectOne(
            'SELECT COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA
             FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?',
            [$schema, $table, $column]
        );

        if ($row === null) {
            return null;
        }

        $definition = $row->COLUMN_TYPE;
        $definition .= $row->IS_NULLABLE === 'YES' ? ' NULL' : ' NOT NULL';

        if ($row->COLUMN_DEFAULT !== null) {
            $default = (string) $row->COLUMN_DEFAULT;
            $definition .= ' DEFAULT '.$this->defaultValue($default);
        }

        if ($row->EXTRA !== '') {
            $definition .= ' '.$row->EXTRA;
        }

        return $definition;
    }

    private function defaultValue(string $value): string
    {
        $upper = strtoupper($value);

        if ($upper === 'CURRENT_TIMESTAMP' || str_starts_with($upper, 'CURRENT_TIMESTAMP(')) {
            return $value;
        }

        return $this->literal($value);
    }

    private function identifier(string $value): string
    {
        return '`'.str_replace('`', '``', $value).'`';
    }

    private function literal(string $value): string
    {
        return "'".str_replace("'", "''", $value)."'";
    }
};
