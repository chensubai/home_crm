# 部署说明

## iOS API 地址

`APIClient()` 从 Info.plist 的 `APIBaseURL` 读取服务地址，该值由
`ios/project.yml` 中的 `API_BASE_URL` build setting 注入。Debug 默认使用
`http://localhost:8080/api`；发布前必须在 `ios/project.yml` 的 Release 配置中
把 `API_BASE_URL` 设置为生产 API 的完整地址，然后运行：

```bash
xcodegen generate --spec ios/project.yml
```

Release 未配置有效地址时，App 不会回退到 localhost，而会提示需要设置
`API_BASE_URL`。

## NFC 正式域名激活

在真实生产域名已经确定并可提供 HTTPS 服务后，按以下步骤启用 NFC Universal Links：

1. 设置 `NFC_PUBLIC_BASE_URL=https://实际域名`、`IOS_TEAM_ID` 和 `IOS_BUNDLE_ID`。
2. 确认 `https://实际域名/.well-known/apple-app-site-association` 返回 HTTP `200`、`Content-Type: application/json`，且没有重定向。
3. 先在 `ios/project.yml` 的 `OperationsHome` target 下，将 `com.apple.developer.associated-domains` 加入 `entitlements.properties`，值为 `applinks:实际域名`。不要只在 Xcode 中手动添加，否则下次生成工程会擦除该配置。
4. 运行 `xcodegen generate --spec ios/project.yml` 重新生成工程，并使用与 `IOS_TEAM_ID` 匹配的 Apple Team 签名。
5. 重新安装 App，让 iOS 获取关联文件。
6. 使用 iPhone XS 或更新机型及可写入的 NDEF 标签进行验证。

仅设置 `NFC_PUBLIC_BASE_URL` 不足以启用 Universal Links；AASA 文件、Associated Domains entitlement 和签名 Apple Team 必须全部匹配。

在真实域名尚未确定前，Associated Domains 配置应保持延后，不要为临时或占位域名添加 entitlement。待真实域名、AASA 服务和签名配置就绪后，再完成上述完整清单。
