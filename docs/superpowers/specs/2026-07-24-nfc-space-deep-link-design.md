# 运营小家 NFC 空间贴纸设计

## 目标

用户创建储物空间后，可以把该空间的链接写入 NFC 贴纸。支持后台 NFC
读取的 iPhone 感应贴纸并点击系统提示后，直接打开运营小家并进入对应空间的
物品列表。

当前没有正式公网域名，因此本轮先完成 NFC 写入、链接解析、权限校验和页面跳转
能力，并将域名与 Apple Team ID 配置化。正式域名和 HTTPS 就绪后，再部署
Universal Link 关联文件完成真机后台唤起验收。

## 用户流程

### 新增空间

1. 用户填写空间名称、位置和图片并保存。
2. 服务端创建空间成功后，App 为该空间创建随机 NFC Token。
3. App 自动展示 NFC 写入页。
4. 用户点击写入按钮并将 iPhone 靠近可写入的 NDEF NFC 贴纸。
5. 写入成功后展示成功状态并关闭页面。
6. 用户可以跳过写入，之后从编辑空间页重新进入 NFC 写入页。

### 编辑空间

空间编辑页不再展示可手动输入的 `NFC UID` 文本框，改为“NFC 贴纸”区域：

- 未绑定时显示“写入 NFC 贴纸”。
- 已绑定时显示“重新写入 NFC 贴纸”。
- 重新写入沿用该空间当前 Token，旧贴纸仍然可以使用。

本轮不提供“让旧贴纸立即失效”的操作。若未来需要作废旧贴纸，再增加 Token
轮换能力。

### 感应贴纸

贴纸保存一个 NDEF URI：

```text
https://<NFC_PUBLIC_DOMAIN>/nfc/<token>
```

用户点击 iOS 的 NFC 系统提示后：

- 已登录：App 解析 Token，向服务端查询空间，验证权限后切换到空间 Tab，并
  进入该空间的物品列表。
- 未登录：App 保存待处理 Token，登录完成后继续解析和跳转。
- 空间不属于当前用户家庭：显示“你没有权限访问这个空间”。
- Token 无效或空间已删除：显示“该 NFC 贴纸已失效”。
- 网络不可用：保留待处理 Token，提示联网后重试，不进入未验证的空间。

## iOS 设计

### NFC 写入服务

新增独立 `NFCWriter`，封装 `NFCNDEFReaderSession`：

- 检查设备是否支持 NFC。
- 创建 URI 类型的 NDEF Payload。
- 检查贴纸是否支持 NDEF 以及是否可写。
- 写入 Universal Link。
- 将 Core NFC 错误转换为用户可理解的状态。

通过协议隔离 Core NFC 具体实现，使 URL 生成和写入结果处理可以使用假实现进行
单元测试。模拟器不启动 Core NFC Session，而是明确显示“请使用支持 NFC 的
iPhone 写入贴纸”。

### 深链路由

新增 App 级路由状态，接收 SwiftUI 的 Universal Link 回调并解析
`/nfc/<token>`。路由状态由登录页和主页共同使用：

- 登录前保存待处理 Token。
- 登录后调用解析接口。
- 解析成功后选中目标家庭，拉取同步数据并设置待打开空间。
- `SpacesView` 接收待打开空间并压入 `ItemsView`。
- 完成跳转后清除待处理状态，避免重复进入。

开发环境额外注册 `operationshome://nfc/<token>`，仅用于模拟器执行
`simctl openurl` 验证路由。NFC 贴纸始终写入 HTTPS Universal Link，不写入
自定义 Scheme。

### 页面样式

NFC 写入页沿用 App 当前浅色背景和玻璃材质：

- 顶部使用统一的圆形取消图标。
- 中部使用 NFC 波纹图标和简短状态。
- 主操作使用绿色圆形 NFC 图标按钮。
- 写入中、成功、失败分别提供清晰视觉状态。
- 不显示 Token、UID 或完整技术链接。

## 服务端设计

继续使用现有 `nfc_tags` 表，不新增 NFC 业务表。现有 `uid` 字段保存不可预测的
随机 Token，作为贴纸链接标识，而不是物理芯片 UID。

新增鉴权接口：

```text
POST /api/spaces/{space}/nfc-token
GET  /api/nfc/{token}
```

`POST /spaces/{space}/nfc-token`：

- 要求当前用户属于空间所在家庭。
- 空间已有有效 Token 时直接返回，不重复生成。
- 没有 Token 时生成足够随机的 Token 并写入 `nfc_tags.uid`。
- 返回 Token 和根据配置生成的 HTTPS 链接。

`GET /nfc/{token}`：

- 要求 Sanctum 登录。
- 查找有效且未软删除的标签与空间。
- 验证当前用户属于空间所在家庭。
- 返回空间 ID、家庭 ID 和空间名称。
- 对无效 Token 返回 404，对无权限用户返回 403。

新增公开 AASA 响应：

```text
GET /.well-known/apple-app-site-association
```

响应使用 `application/json`，不跳转，内容由 `IOS_TEAM_ID`、
`IOS_BUNDLE_ID` 和 `/nfc/*` 路径规则生成。该路由在正式 HTTPS 域名部署后供
Apple 验证。

## 配置

服务端新增：

```text
NFC_PUBLIC_BASE_URL=https://example.com
IOS_TEAM_ID=<Apple Team ID>
IOS_BUNDLE_ID=com.operationshome.OperationsHome
```

iOS 构建配置新增 Associated Domains：

```text
applinks:<NFC_PUBLIC_DOMAIN>
```

在没有正式域名的开发阶段，不承诺真机后台 NFC 唤起。可以验证：

- 后端 Token 创建与解析。
- NFC NDEF URI 生成。
- 自定义 Scheme 路由和登录后续跳转。
- 真机前台写入 NFC 贴纸。

## 安全与错误处理

- Token 使用密码学安全随机值，不使用可枚举的空间 ID。
- NFC 链接不携带家庭名称、空间名称、手机号或鉴权信息。
- 服务端是权限判断的唯一可信来源，App 不凭本地缓存直接放行。
- 重复请求创建 Token 必须幂等。
- 标签写入失败不会删除已生成的 Token，用户可以直接重试。
- 空间软删除后，解析接口不再返回该空间。
- 切换账号后，原待处理 Token 必须重新经过当前账号权限验证。

## 测试与验收

### 服务端

- 家庭成员可以为所属空间创建 Token。
- 非家庭成员不能创建或解析 Token。
- 重复创建返回同一个 Token。
- Token 唯一且不能绑定多个空间。
- 无效 Token、软删除标签和软删除空间返回 404。
- AASA 响应格式、App ID 和 `/nfc/*` 路径正确。

### iOS

- URL 生成器只生成配置域名下的 `/nfc/<token>`。
- Universal Link 和开发 Scheme 都能解析相同 Token。
- 未登录时保存待处理 Token，登录后继续处理。
- 有权限时切换家庭并进入目标空间物品列表。
- 无权限、失效和网络错误展示对应提示。
- 不支持 NFC 的设备不会启动 Session。
- 写入成功、用户取消、只读标签和容量不足均有明确反馈。

### 最终真机验收

正式域名与签名能力就绪后，在 iPhone XS 或更新机型完成：

1. 新建空间并写入一张可写 NDEF NFC 贴纸。
2. 退出 App 或将 App 放入后台。
3. 保持 iPhone 已解锁并感应贴纸。
4. 点击系统 NFC 提示。
5. App 打开并进入正确空间的物品列表。

## 不在本轮范围

- Android NFC。
- NFC 标签批量写入。
- 标签轮换和旧贴纸作废。
- 未安装 App 时的完整 Web 空间页面。
- 通过 NFC 直接修改库存。
