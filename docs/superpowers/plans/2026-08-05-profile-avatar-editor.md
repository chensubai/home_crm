# Profile Avatar Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a profile-specific avatar picker with source selection, adjustable square crop, circular preview, and a 500 KB JPEG upload limit.

**Architecture:** Keep profile persistence in `ProfileEditView`. Extract image processing into a pure UIKit helper for testability, then use profile-only SwiftUI views for picking and cropping so the existing 5 MB space/item image flow stays unchanged.

**Tech Stack:** SwiftUI, UIKit, PhotosUI, XCTest.

## Global Constraints

- Avatar uploads must be JPEG data no larger than 512,000 bytes.
- The crop result must be square; the profile preview must be circular.
- Do not alter `ImageInputView` or the existing space/item image upload behavior.

---

### Task 1: Add avatar image processing with tests

**Files:**
- Create: `ios/OperationsHome/Services/AvatarImageProcessor.swift`
- Create: `ios/OperationsHomeTests/AvatarImageProcessorTests.swift`

**Interfaces:**
- Produces: `AvatarImageProcessor.squareCrop(image:cropRect:) -> UIImage?`
- Produces: `AvatarImageProcessor.compressedJPEG(from:) -> Data?`

- [ ] **Step 1: Write failing tests**

```swift
func testCompressedAvatarIsNoLargerThan500KB() throws {
    let image = try XCTUnwrap(UIImage(systemName: "person.crop.circle")?.resized(to: CGSize(width: 2000, height: 1600)))
    let data = try XCTUnwrap(AvatarImageProcessor.compressedJPEG(from: image))
    XCTAssertLessThanOrEqual(data.count, 512_000)
}

func testSquareCropProducesSquareImage() throws {
    let image = try XCTUnwrap(UIImage(systemName: "person.crop.circle")?.resized(to: CGSize(width: 800, height: 600)))
    let result = try XCTUnwrap(AvatarImageProcessor.squareCrop(image: image, cropRect: CGRect(x: 100, y: 0, width: 600, height: 600)))
    XCTAssertEqual(result.size.width, result.size.height)
}
```

- [ ] **Step 2: Run the focused test target and verify it fails**

Run: `xcodebuild test -project ios/OperationsHome.xcodeproj -scheme OperationsHome -only-testing:OperationsHomeTests/AvatarImageProcessorTests`

- [ ] **Step 3: Implement orientation normalization, square crop, and bounded JPEG compression**

```swift
enum AvatarImageProcessor {
    static func squareCrop(image: UIImage, cropRect: CGRect) -> UIImage? { /* render crop */ }
    static func compressedJPEG(from image: UIImage) -> Data? { /* resize and encode <= 512_000 bytes */ }
}
```

- [ ] **Step 4: Run the focused test target and verify it passes**

- [ ] **Step 5: Commit the isolated image processor and tests**

### Task 2: Add source selection and adjustable avatar cropping

**Files:**
- Create: `ios/OperationsHome/Views/AvatarPickerView.swift`
- Create: `ios/OperationsHome/Views/AvatarCropView.swift`
- Modify: `ios/OperationsHome/Views/ProfileEditView.swift`

**Interfaces:**
- Consumes: `AvatarImageProcessor.compressedJPEG(from:) -> Data?`
- Produces: `AvatarPickerView(imageData:existingImageURL:)` bound to the profile form's avatar data.

- [ ] **Step 1: Write a failing view-model test for crop confirmation replacing the draft avatar data**

```swift
func testConfirmedCropStoresCompressedAvatarData() throws {
    let image = try XCTUnwrap(UIImage(systemName: "person.crop.circle"))
    let data = try XCTUnwrap(AvatarImageProcessor.compressedJPEG(from: image))
    XCTAssertLessThanOrEqual(data.count, 512_000)
}
```

- [ ] **Step 2: Run the focused test and verify it fails before the processor exists**

- [ ] **Step 3: Build the picker and crop flow**

```swift
AvatarPickerView(imageData: $avatarData, existingImageURL: existingAvatarURL)
```

Use `confirmationDialog` for source selection. Present a square crop sheet after either source returns an image. Render the final image with `Circle()` clipping in the picker and only assign compressed data after crop confirmation.

- [ ] **Step 4: Replace the current `ImageInputView` call in `ProfileEditView` with `AvatarPickerView` and move it above the phone and nickname rows**

- [ ] **Step 5: Run the focused tests and manually verify photo source, camera source, crop cancellation, circular preview, and 500 KB output**

- [ ] **Step 6: Commit the avatar UI flow and profile integration**
