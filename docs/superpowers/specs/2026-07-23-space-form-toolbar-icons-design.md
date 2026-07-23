# 空间表单工具栏图标设计

## 范围

仅修改 `SpaceFormView` 的导航栏操作按钮，覆盖新增空间和编辑空间弹窗。

## 设计

- 左侧取消按钮仅显示圆形 SF Symbol `xmark.circle.fill`。
- 右侧保存按钮仅显示圆形 SF Symbol `checkmark.circle.fill`。
- 两个图标统一使用 `24pt semibold`，增强在浅色弹窗导航栏中的识别度。
- 分别保留“取消”和“保存”无障碍标签，保证 VoiceOver 可识别。
- 保存按钮沿用现有禁用条件，名称为空或未选择家庭时不可点击。
- 不修改表单布局、接口调用、图片上传或其他新增/编辑页面。

## 验收

- 点击空间页右上角加号后，弹窗顶部不再显示“取消”“保存”文字。
- 点击 `xmark.circle.fill` 可关闭弹窗。
- 点击 `checkmark.circle.fill` 可保存空间。
- 保存条件不满足时，`checkmark.circle.fill` 保持禁用。
