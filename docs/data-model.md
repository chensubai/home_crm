# 数据模型

## 权限边界

所有家庭数据以 `family_id` 隔离。第一版角色只有：

- `owner`：创建家庭、邀请成员、读写家庭数据。
- `member`：读写家庭数据。

## 核心实体

- `users`：手机号登录用户。
- `families`：家庭空间。
- `family_members`：家庭成员和角色。
- `family_invites`：邀请链接/邀请码。
- `storage_spaces`：柜子、抽屉、储物间等存放空间。
- `nfc_tags`：空间绑定的 NFC UID，第一版只存储和展示。
- `items`：家庭物品，包含分类、数量、位置、条码、保质期和状态。
- `item_changes`：库存数量调整记录。
- `reminders`：重要日期、周期任务、物品过期提醒。
- `periodic_tasks`：周期任务扩展表，MVP 可由 `reminders` 承担展示和通知。

## 同步规则

- 增量拉取按 `updated_at > since`。
- 删除使用软删除，客户端同步 `deleted_at` 后隐藏本地记录。
- MVP 冲突策略为最后写入优先。
- 库存快捷调整额外写入 `item_changes`，便于后续追踪家庭成员操作。
