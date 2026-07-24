# 部署说明

## NFC 正式域名激活

在真实生产域名已经确定并可提供 HTTPS 服务后，按以下步骤启用 NFC Universal Links：

1. 设置 `NFC_PUBLIC_BASE_URL=https://实际域名`、`IOS_TEAM_ID` 和 `IOS_BUNDLE_ID`。
2. 确认 `https://实际域名/.well-known/apple-app-site-association` 返回 HTTP `200`、`Content-Type: application/json`，且没有重定向。
3. 在 iOS target 的 Associated Domains capability 中添加 `applinks:实际域名`。
4. 重新生成 Xcode 工程，并使用与 `IOS_TEAM_ID` 匹配的 Apple Team 签名。
5. 重新安装 App，让 iOS 获取关联文件。
6. 使用 iPhone XS 或更新机型及可写入的 NDEF 标签进行验证。

仅设置 `NFC_PUBLIC_BASE_URL` 不足以启用 Universal Links；AASA 文件、Associated Domains entitlement 和签名 Apple Team 必须全部匹配。

在真实域名尚未确定前，Associated Domains 配置应保持延后，不要为临时或占位域名添加 entitlement。待真实域名、AASA 服务和签名配置就绪后，再完成上述完整清单。
