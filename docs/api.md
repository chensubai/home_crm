# API 合约

所有接口返回统一 JSON：

```json
{ "ok": true, "data": {} }
```

失败响应使用相同外层结构，并返回 `message`；表单校验失败时还会返回 `errors`。认证后接口使用 `Authorization: Bearer <token>`。

访问 `GET /api` 可用于检查服务是否正常，成功时返回 API 名称。

## 认证

- `POST /api/auth/sms/send`
  - body: `{ "phone": "13800000000" }`
  - local/mock 环境返回 `data.mock_code = "123456"`。
- `POST /api/auth/sms/verify`
  - body: `{ "phone": "13800000000", "code": "123456", "name": "可选昵称" }`
  - returns: `token`, `user`。
- `POST /api/auth/logout`

## 个人资料

- `GET /api/auth/me`
  - returns: `id`, `phone`, `name`, `avatar_key`, `avatar_url`, `avatar_hash`。
- `PATCH /api/profile`
  - 普通请求字段：`name`。
  - 上传头像时使用 `multipart/form-data`，字段：`name`, `avatar`。
  - 图片服务端上限为 10 MB；iOS 上传前会压缩到 5 MB 以内。
  - 私有七牛云空间返回的 `avatar_url` 是带有效期签名的读取地址。

## 家庭

- `GET /api/families`
  - 每个家庭返回当前用户的 `role`：`owner` 或 `member`。
- `POST /api/families`
  - body: `{ "name": "我的家" }`
- `PATCH /api/families/{id}`
  - owner only。
  - body: `{ "name": "新家庭名称" }`
- `POST /api/families/{id}/invites`
  - owner only。
  - body: `{ "phone": "可选手机号" }`
  - returns: 8 位邀请码和 `expires_at`，有效期 7 天。
- `POST /api/invites/{code}/accept`
- `GET /api/families/{id}/members`
  - owner/member 均可查看。
  - 返回家庭成员关系 `id`、用户 `user_id`、昵称、手机号和角色。
- `DELETE /api/families/{id}/members/{member_id}`
  - owner only；`member_id` 是家庭成员关系 ID，不是用户 ID。
  - 不允许移除家庭创建人。

## 空间与物品

- `GET /api/spaces?family_id=1`
- `POST /api/spaces`
  - JSON body: `{ "family_id": 1, "name": "客厅柜子", "nfc_uid": "optional" }`
  - 上传图片时使用 `multipart/form-data`，字段：`family_id`, `name`, `description`, `nfc_uid`, `image`。
- `PATCH /api/spaces/{id}`
  - 可修改 `name`, `description`, `nfc_uid`，并用 `image` 上传或替换空间图片。
  - iOS 图片更新使用 `POST` + multipart 字段 `_method=PATCH`，兼容 PHP 对 multipart PATCH 的解析。
- `DELETE /api/spaces/{id}`
  - 空间内仍有物品时返回 422，必须先移动或删除这些物品。
  - 删除使用软删除。
- `GET /api/items?family_id=1`
- `POST /api/items`
  - `space_id` 必填，且空间必须属于同一家庭。
  - JSON body: `{ "family_id": 1, "space_id": 1, "name": "纸巾", "quantity": 6, "status": "idle" }`
  - 可选字段：`category`, `unit`, `barcode`, `expires_at`, `notes`。
  - 上传图片时使用 `multipart/form-data`，字段同上并增加 `image`。
- `PATCH /api/items/{id}`
  - 支持修改物品全部录入字段和存放空间。
  - iOS 图片更新同样使用 `POST` + `_method=PATCH`。
- `DELETE /api/items/{id}`
  - 删除使用软删除。
- `POST /api/items/{id}/adjust`
  - body: `{ "delta": -1, "reason": "取用" }`
  - 数量调整在事务中加锁，最低为 0，并写入实际变动值到 `item_changes`。

空间和物品的图片服务端上限为 10 MB，iOS 拍照或选图后会压缩到 5 MB 以内。私有空间的 `image_url` 为服务端动态生成的签名读取地址；没有图片时 `image_url` 为空，由 iOS 展示默认封面。

## 提醒

- `GET /api/reminders?family_id=1`
- `POST /api/reminders`
  - body: `{ "family_id": 1, "title": "交水电费", "kind": "important_date", "remind_at": "2026-06-17T09:00:00Z", "repeat_rule": "none", "is_enabled": true }`
  - `kind`: `important_date`, `periodic_task`, `item_expiry`。
  - `repeat_rule`: `none`, `daily`, `weekly`, `monthly`, `yearly`。
  - `repeat_value`: 每周存星期编号逗号列表，例如 `2,3,4,5,6`；每月存日期号，例如 `15`。
  - 一次性提醒使用具体日期和时间，`repeat_rule=none`；周期任务只在 `remind_at` 使用时间部分，并通过重复规则决定触发日期。
- `PATCH /api/reminders/{id}`
  - 可更新上述字段；只传 `{ "is_enabled": false }` 可停用提醒而不删除记录。
- `DELETE /api/reminders/{id}`
- `POST /api/reminders/{id}/complete`

iOS 每次同步或编辑后都会先移除该提醒已有的本地通知，再按最新启停、完成和重复状态重新注册；停用、完成、删除或已过期的一次性提醒不会继续触发。

## 图片配置

七牛云配置：

```env
QINIU_ACCESS_KEY=
QINIU_SECRET_KEY=
QINIU_BUCKET=
QINIU_DOMAIN=https://cdn.example.com
QINIU_REGION=z1
QINIU_PRIVATE=true
QINIU_URL_TTL=3600
```

华北-河北使用 `QINIU_REGION=z1`。AK/SK 属于七牛云账号密钥，不随单个空间变化；`QINIU_BUCKET`、区域和访问域名必须与目标空间匹配。上传使用官方 `qiniu/php-sdk`，私有空间读取由服务端签名。

## 同步

- `GET /api/sync?family_id=1&since=2026-06-16T00:00:00Z`
  - returns: `cursor`, `spaces`, `items`, `reminders`。
- `POST /api/sync/push`
  - body: `{ "family_id": 1, "spaces": [], "items": [], "reminders": [] }`
  - 顶层 `family_id` 必须是当前用户已加入的家庭；子记录的 `family_id` 不被信任，服务端统一写入已鉴权家庭。
  - 带 `id` 的子记录必须已经属于该家庭；同步新增物品必须提供 `space_id`，且空间必须属于同一家庭，否则返回 422。
  - 一个 push 批次在同一数据库事务中处理；任一记录校验失败时整批回滚。
