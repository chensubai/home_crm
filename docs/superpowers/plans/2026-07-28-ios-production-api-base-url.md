# iOS Production API Base URL Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make both Debug and Release iOS builds use `https://api.homecrm.store/api`.

**Architecture:** Keep `ios/project.yml` as the source of truth for build settings and regenerate the checked-in Xcode project with XcodeGen. Do not change `APIClient` because it already reads `APIBaseURL` from the generated Info.plist.

**Tech Stack:** XcodeGen 2.43.0, Xcode 16.4, Swift 5.10

## Global Constraints

- Debug and Release must both set `API_BASE_URL` to exactly `https://api.homecrm.store/api`.
- Regenerate `ios/OperationsHome.xcodeproj`; do not hand-edit generated project settings.
- Do not change `ios/OperationsHome/Networking/APIClient.swift`.
- Do not add an App Transport Security exception.
- Do not stage or modify `ios/OperationsHome.xcodeproj/project.xcworkspace/xcuserdata/dev.xcuserdatad/UserInterfaceState.xcuserstate`.

---

### Task 1: Point all iOS configurations at the production API

**Files:**
- Modify: `ios/project.yml`
- Regenerate: `ios/OperationsHome.xcodeproj/project.pbxproj`
- Modify: `docs/superpowers/specs/2026-07-28-ios-production-api-base-url-design.md`
- Modify: `docs/superpowers/plans/2026-07-28-ios-production-api-base-url.md`

**Interfaces:**
- Consumes: XcodeGen build setting `API_BASE_URL`
- Produces: Info.plist value `APIBaseURL = https://api.homecrm.store/api` for Debug and Release

- [ ] **Step 1: Run the configuration assertion before changing files**

```bash
for configuration in Debug Release; do
  actual=$(xcodebuild \
    -project ios/OperationsHome.xcodeproj \
    -scheme OperationsHome \
    -configuration "$configuration" \
    -showBuildSettings |
    awk '/API_BASE_URL =/{print $3; exit}')
  test "$actual" = "https://api.homecrm.store/api" || {
    echo "$configuration API_BASE_URL is $actual"
    exit 1
  }
done
```

Expected: FAIL because both configurations currently use `http://api.homecrm.store/api`.

- [ ] **Step 2: Change the XcodeGen source configuration**

In `ios/project.yml`, set:

```yaml
  configs:
    Debug:
      API_BASE_URL: "https://api.homecrm.store/api"
    Release:
      API_BASE_URL: "https://api.homecrm.store/api"
```

- [ ] **Step 3: Regenerate the checked-in Xcode project**

```bash
xcodegen generate --spec ios/project.yml
```

Expected: `ios/OperationsHome.xcodeproj/project.pbxproj` contains the production URL for Debug and Release.

- [ ] **Step 4: Re-run the configuration assertion**

Run the command from Step 1.

Expected: PASS with exit code 0.

- [ ] **Step 5: Run the iOS unit tests**

```bash
xcodebuild test \
  -project ios/OperationsHome.xcodeproj \
  -scheme OperationsHome \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath /tmp/homecrm-ios-api-tests \
  -only-testing:OperationsHomeTests/APIModelsTests
```

Expected: `APIModelsTests` passes with zero failures.

- [ ] **Step 6: Build Debug and Release for the simulator**

```bash
xcodebuild build \
  -project ios/OperationsHome.xcodeproj \
  -scheme OperationsHome \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/homecrm-ios-api-debug \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project ios/OperationsHome.xcodeproj \
  -scheme OperationsHome \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/homecrm-ios-api-release \
  CODE_SIGNING_ALLOWED=NO
```

Expected: both commands end with `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Review and commit only the intended files**

```bash
git diff --check
git diff -- ios/project.yml ios/OperationsHome.xcodeproj/project.pbxproj
git add ios/project.yml ios/OperationsHome.xcodeproj/project.pbxproj docs/superpowers/specs/2026-07-28-ios-production-api-base-url-design.md docs/superpowers/plans/2026-07-28-ios-production-api-base-url.md
git commit -m "chore: use HTTPS for iOS API"
```

Expected: the existing `UserInterfaceState.xcuserstate` modification remains unstaged.
