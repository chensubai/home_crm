# iOS 线上 API 基地址设计

## 目标

让 iOS 应用的 Debug 与 Release 构建都访问
`https://api.homecrm.store/api`，不再使用 HTTP、本地地址或空配置。

## 实现

- 在 `ios/project.yml` 中将 Debug 和 Release 的 `API_BASE_URL` 都设为线上地址。
- 使用 XcodeGen 重新生成 `ios/OperationsHome.xcodeproj`，确保当前 Xcode 工程立即生效。
- 保留 `APIClient` 现有的配置读取和错误处理逻辑，不增加新的运行时分支。
- 线上服务已经支持有效 HTTPS 证书，因此不添加 App Transport Security 例外。

## 验证

- 检查生成后的 Debug 与 Release build setting 都为线上地址。
- 运行 iOS 单元测试。
- 分别构建 Debug 与 Release 模拟器版本。
