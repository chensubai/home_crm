# 空间与物品图片裁剪实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为空间和物品提供统一的拍照/相册、指定比例裁剪和不超过 500KB 的图片上传流程。

**Architecture:** 在 `ImageInputView.swift` 内将现有图片输入替换为单一的可配置组件，调用方仅提供裁剪比例和预览样式。裁剪结果以 JPEG 数据回写原有表单绑定值，保留空间、物品页面现有保存请求。空间卡片改用 4:3 封面比例，使显示与上传裁剪一致。

**Tech Stack:** SwiftUI、PhotosUI、UIKit、XCTest。

## Global Constraints

- 空间裁剪和展示比例为 4:3 横向。
- 物品裁剪比例为 1:1。
- 所有空间与物品上传的 JPEG 数据必须不超过 512,000 字节。
- 相册只允许选择一张图片，并且每次打开均重新选择。
- 选择来源、拍摄、图片读取失败的交互与头像选择保持一致。

---

### Task 1: 可配置的图片裁剪与压缩工具

**Files:**
- Modify: `ios/OperationsHome/Views/ImageInputView.swift`
- Test: `ios/OperationsHomeTests/APIModelsTests.swift`

**Interfaces:**
- Consumes: `UIImage`、目标裁剪比例 `CGFloat`。
- Produces: `ImageCropProcessor.croppedImage(image:aspectRatio:cropRect:) -> UIImage?` 与 `ImageCropProcessor.compressedJPEG(from:) -> Data?`。

- [ ] **Step 1: Write the failing test**

```swift
func testImageCropProcessorProducesConfiguredAspectRatios() throws {
    let source = testImage(size: CGSize(width: 1200, height: 900))
    let spaceCrop = try XCTUnwrap(ImageCropProcessor.centerCrop(image: source, aspectRatio: 4 / 3))
    let itemCrop = try XCTUnwrap(ImageCropProcessor.centerCrop(image: source, aspectRatio: 1))
    XCTAssertEqual(spaceCrop.size.width / spaceCrop.size.height, 4 / 3, accuracy: 0.01)
    XCTAssertEqual(itemCrop.size.width, itemCrop.size.height, accuracy: 0.01)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme OperationsHome -only-testing:OperationsHomeTests/APIModelsTests`

Expected: test does not compile because `ImageCropProcessor` is undefined.

- [ ] **Step 3: Write minimal implementation**

Implement normalized image conversion, pixel-safe crop conversion, and progressive JPEG compression that returns only data at or below 512,000 bytes.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme OperationsHome -only-testing:OperationsHomeTests/APIModelsTests`

Expected: aspect-ratio and 500KB compression tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/OperationsHome/Views/ImageInputView.swift ios/OperationsHomeTests/APIModelsTests.swift
git commit -m "feat: add configurable image crop processing"
```

### Task 2: 统一空间与物品图片选择界面

**Files:**
- Modify: `ios/OperationsHome/Views/ImageInputView.swift`

**Interfaces:**
- Consumes: `@Binding var imageData: Data?`、已有图片 URL、`aspectRatio: CGFloat`。
- Produces: `ImageInputView(imageData:existingImageURL:aspectRatio:)`，拍照或相册选择后展示裁剪页并回写压缩 JPEG。

- [ ] **Step 1: Write the failing test**

```swift
func testImageInputConfigurationUsesSpaceAndItemCropRatios() {
    XCTAssertEqual(ImageCropAspect.space.ratio, 4 / 3)
    XCTAssertEqual(ImageCropAspect.item.ratio, 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme OperationsHome -only-testing:OperationsHomeTests/APIModelsTests`

Expected: test does not compile because `ImageCropAspect` is undefined.

- [ ] **Step 3: Write minimal implementation**

Replace the inline buttons with the avatar-equivalent source sheet. Load one selected photo with `Transferable` plus data fallback, then present a fixed-ratio black crop canvas. Apply the selected ratio to the clipping shape and crop math; reset the selected item after each selection.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme OperationsHome -only-testing:OperationsHomeTests/APIModelsTests`

Expected: configuration tests and existing image compression tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/OperationsHome/Views/ImageInputView.swift ios/OperationsHomeTests/APIModelsTests.swift
git commit -m "feat: unify image selection and cropping"
```

### Task 3: 接入页面和空间首页比例

**Files:**
- Modify: `ios/OperationsHome/Views/SpacesView.swift`
- Modify: `ios/OperationsHome/Views/ItemsView.swift`

**Interfaces:**
- Consumes: `ImageCropAspect.space` 与 `ImageCropAspect.item`。
- Produces: 空间编辑使用 4:3 裁剪，物品编辑使用 1:1 裁剪，空间首页封面使用 4:3。

- [ ] **Step 1: Write the failing test**

```swift
func testSpaceAndItemImageCropRatiosAreStable() {
    XCTAssertEqual(ImageCropAspect.space.ratio, 4 / 3)
    XCTAssertEqual(ImageCropAspect.item.ratio, 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme OperationsHome -only-testing:OperationsHomeTests/APIModelsTests`

Expected: test passes only after Task 2; this step protects the public configuration before view integration.

- [ ] **Step 3: Write minimal implementation**

Pass `.space` to `SpaceEditView` and `.item` to `ItemEditView`. Change `SpaceCardView.coverImage` from a fixed height to `aspectRatio(4 / 3, contentMode: .fit)` while retaining `scaledToFill()` and rounded clipping.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme OperationsHome -only-testing:OperationsHomeTests/APIModelsTests`

Expected: all image processor tests pass and affected Swift files compile.

- [ ] **Step 5: Commit**

```bash
git add ios/OperationsHome/Views/SpacesView.swift ios/OperationsHome/Views/ItemsView.swift
git commit -m "feat: crop space and item images for display"
```

## Verification

- Run `swiftc -parse` for modified Swift files and `git diff --check`.
- On an iPhone, select and photograph both a space and an item image; verify each crop ratio and that output uploads are no larger than 500KB.
- Verify saving and cancelling each form keeps its existing submission behavior.
