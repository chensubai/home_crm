# API 合约

所有接口返回统一 JSON：

```json
{ "ok": true, "data": {} }
```

认证后接口使用 `Authorization: Bearer <token>`。

## 认证

- `POST /api/auth/sms/send`
  - body: `{ "phone": "13800000000" }`
  - local/mock 环境返回 `data.mock_code = "123456"`。
- `POST /api/auth/sms/verify`
  - body: `{ "phone": "13800000000", "code": "123456", "name": "可选昵称" }`
  - returns: `token`, `user`。
- `POST /api/auth/logout`

## 家庭

- `GET /api/families`
- `POST /api/families`
  - body: `{ "name": "我的家" }`
- `POST /api/families/{id}/invites`
  - owner only。
- `POST /api/invites/{code}/accept`
- `GET /api/families/{id}/members`

## 空间与物品

- `GET /api/spaces?family_id=1`
- `POST /api/spaces`
  - JSON body: `{ "family_id": 1, "name": "客厅柜子", "nfc_uid": "optional" }`
  - 上传图片时使用 `multipart/form-data`，字段：`family_id`, `name`, `description`, `nfc_uid`, `image`。
- `PATCH /api/spaces/{id}`
  - 可用 `multipart/form-data` 上传或替换空间图片，字段：`image`。
- `DELETE /api/spaces/{id}`
- `GET /api/items?family_id=1`
- `POST /api/items`
  - JSON body: `{ "family_id": 1, "space_id": 1, "name": "纸巾", "quantity": 6, "status": "idle" }`
  - 上传图片时使用 `multipart/form-data`，字段：`family_id`, `space_id`, `name`, `quantity`, `status`, `image`。
- `PATCH /api/items/{id}`
  - 可用 `multipart/form-data` 上传或替换物品图片，字段：`image`。
- `DELETE /api/items/{id}`
- `POST /api/items/{id}/adjust`
  - body: `{ "delta": -1, "reason": "取用" }`

## 提醒

- `GET /api/reminders?family_id=1`
- `POST /api/reminders`
  - body: `{ "family_id": 1, "title": "交水电费", "kind": "important_date", "remind_at": "2026-06-17T09:00:00Z", "repeat_rule": "monthly" }`
- `PATCH /api/reminders/{id}`
- `DELETE /api/reminders/{id}`
- `POST /api/reminders/{id}/complete`

## 图片配置

七牛云配置：

```env
QINIU_ACCESS_KEY=
QINIU_SECRET_KEY=
QINIU_BUCKET=
QINIU_DOMAIN=https://cdn.example.com
QINIU_UPLOAD_URL=https://upload.qiniup.com
QINIU_PRIVATE=false
QINIU_URL_TTL=3600
```

## 同步

- `GET /api/sync?family_id=1&since=2026-06-16T00:00:00Z`
  - returns: `cursor`, `spaces`, `items`, `reminders`。
- `POST /api/sync/push`
  - body: `{ "family_id": 1, "spaces": [], "items": [], "reminders": [] }`
