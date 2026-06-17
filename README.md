# 运营小家

家庭物品管理与生活提醒的 iOS MVP。仓库包含 SwiftUI iOS 客户端、Laravel/MySQL API 服务和产品/API 文档。

## 本地后端

```bash
cp server/.env.example server/.env
docker compose up --build
docker compose exec api php artisan migrate
docker compose run --rm --no-deps api ./vendor/bin/phpunit
```

API 默认地址是 `http://localhost:8080/api`。开发环境短信验证码固定返回 `123456`。
首次启动时，API 容器会在 `server/vendor` 不存在时自动执行 `composer install`，所以宿主机目录也会看到 vendor 文件。

## iOS

`ios/OperationsHome.xcodeproj` 可以直接用 Xcode 打开：

```bash
open ios/OperationsHome.xcodeproj
```

`ios/` 也保留了 XcodeGen 描述工程，后续如需重新生成：

```bash
cd ios
xcodegen generate
open OperationsHome.xcodeproj
```

打开工程后运行 `OperationsHome` target。模拟器访问本机 Docker API 使用 `http://localhost:8080/api`。

## MVP 范围

- 手机号验证码登录。
- 家庭创建、家庭成员邀请的后端能力。
- 储物空间、NFC 标签字段、物品清单、数量调整。
- 重要日期/周期任务/物品过期提醒数据模型。
- iOS 本地通知调度。
- 条形码/二维码扫描录入。
- SwiftData 本地缓存和增量同步拉取。

## 后续

- 接真实短信服务。
- 接 Core NFC 扫描和标签绑定流程。
- 完成离线变更队列的批量 push UI。
- 接入 APNs 服务端推送。
