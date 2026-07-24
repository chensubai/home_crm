# 数据模型

## 权限边界

所有家庭数据以 `family_id` 隔离。第一版角色只有：

- `owner`：修改家庭名称、邀请或移除普通成员，并读写家庭业务数据。
- `member`：查看家庭资料和成员，并读写空间、物品和提醒；不能管理家庭资料或成员。

`GET /api/families` 会返回当前用户在每个家庭中的 `role`，iOS 以该字段决定是否展示管理入口。服务端仍会对所有 owner-only 接口再次鉴权。

## 核心实体

- `users`：手机号登录用户；头像使用 `avatar_key`, `avatar_url`, `avatar_hash` 保存七牛云对象信息。
- `families`：家庭空间，当前可维护 `name`。
- `family_members`：家庭成员关系和 `owner/member` 角色；API 删除参数使用该表的 `id`。
- `family_invites`：邀请码、可选手机号、创建人、到期和接受时间。
- `storage_spaces`：柜子、抽屉、储物间等存放空间；图片直接保存在 `image_key`, `image_url`, `image_hash` 字段，不建独立图片表。
- `nfc_tags`：空间绑定的 48 位随机链接 Token，不是由用户录入的物理芯片 UID。Token 由服务端创建并全局唯一；每个空间最多关联一条记录，软删除后可恢复。
- `items`：家庭物品，包含必填存放空间、分类、数量、单位、条码、保质期、状态、备注和图片字段。
- `item_changes`：库存数量调整流水，记录变更前后数量、实际增减值、用户和原因。
- `reminders`：重要日期、周期任务、物品过期提醒；`is_enabled` 控制启停，`repeat_value` 保存每周星期或每月日期号。
- `periodic_tasks`：周期任务独立扩展表，MVP 的实际增删改查和通知由 `reminders` 承担。

## 图片规则

- 用户头像、空间和物品图片都直接保存在所属业务表。
- `*_key` 是七牛云对象 key，`*_hash` 是上传结果 hash，`*_url` 是最近一次访问地址。
- 当七牛云空间为私有空间时，API 返回前会根据 key 重新生成限时签名 URL。
- iOS 优先展示已上传图片；只有图片为空或加载失败时才使用默认头像/封面。

## 提醒规则

- 一次性提醒：`repeat_rule=none`，`remind_at` 同时表示选定日期和时间。
- 每日提醒：`repeat_rule=daily`，使用 `remind_at` 的时分。
- 每周提醒：`repeat_rule=weekly`，`repeat_value` 为星期编号列表；工作日为 `2,3,4,5,6`。
- 每月提醒：`repeat_rule=monthly`，`repeat_value` 为 1-31 的日期号。
- `is_enabled=false`、`completed_at` 非空、软删除或已过期的一次性提醒不会注册 iOS 本地通知。

## 同步规则

- 增量拉取按 `updated_at > since`。
- 删除使用软删除，客户端同步 `deleted_at` 后隐藏本地记录。
- MVP 冲突策略为最后写入优先。
- 库存快捷调整额外写入 `item_changes`，便于后续追踪家庭成员操作。
- 同步载荷包含空间 `nfc_uid`、提醒 `repeat_value/is_enabled` 和业务表图片字段。
- 服务端只接受当前已鉴权家庭内的同步记录，并以事务处理每个 push 批次，避免跨家庭覆盖和部分提交。

## 部署

为 iOS Universal Links 配置以下环境变量：

```env
NFC_PUBLIC_BASE_URL=https://example.com
IOS_TEAM_ID=TEAM123456
IOS_BUNDLE_ID=com.operationshome.OperationsHome
```

应用必须在根路径公开 `GET /.well-known/apple-app-site-association`，并通过 HTTPS 提供该响应。关联文件使用 `IOS_TEAM_ID` 和 `IOS_BUNDLE_ID` 组成 app ID，且仅声明 `/nfc/*` 深链接；`NFC_PUBLIC_BASE_URL` 只有有效 HTTPS 值时才会生成可写入 NFC 标签的链接 URL。
