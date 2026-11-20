# HeatGuard iOS — project map

Last reviewed: 2026-11-20
Repository: `heatguard-iOS.xcodeproj` (Swift 5, SwiftUI, single app + XCTest target).

## Structure

- `heatguard-iOS/App/HeatGuardApp.swift`: app entry point, intro/session restoration, auth/team routing, deep-link handling.
- `heatguard-iOS/Core/Network/`: `HGAPIClient`, API configuration/path/error/envelope, auth-aware `URLSession` requests and session-expiry notification.
- `heatguard-iOS/Core/Auth/`: authentication/session state, Keychain access token store, profile-photo presigned upload.
- `heatguard-iOS/Core/Records/`: record history/upload, draft persistence/isolation, save outcomes/errors.
- Other `Core` domains: Checklist, Dashboard/weather, DesignSystem, Emergency, Extensions/date formatting, Inquiry, Notifications.
- `heatguard-iOS/Presentation/Components/`: shared SwiftUI controls/layout/keyboard/camera/photo components.
- `heatguard-iOS/Presentation/Features/`: feature screens grouped by domain (Home, Login, Checklist, records, profile, notifications, emergency, inquiry, onboarding/team flow, withdrawal, etc.).
- `heatguard-iOS/Assets.xcassets/`, `Resources/Fonts/`: image/vector assets and Pretendard fonts; `PrivacyInfo.xcprivacy` declares privacy manifest.
- `Configuration/`: Info.plist and entitlements. API base URL currently configured in Info.plist.
- `Tests/`: XCTest suites grouped by Network/Auth, Records, UI, Checklist, Notifications, Emergency, Formatting.
- `Documentation/`: feature/parity notes and screenshots. `scripts/test-notifications.sh` runs the unit-test scheme; `.github/workflows/ios-build.yml` runs SwiftLint and simulator build/tests.

## Architecture conventions evidenced in source

SwiftUI views are composed in Presentation and call domain-specific service structs in Core. `HGAPIClient` centralizes API JSON, auth headers, decoding/errors and session-expiry signaling. Presigned S3 upload services use a separate URLSession request for object transfer. Record drafts use Application Support files and owner-scoped directories; session tokens are held in Keychain and session metadata in UserDefaults. Xcode project has `heatguard-iOS` and `heatguard-iOSTests` targets, scheme `heatguard-iOS`.

## Analysis caveats / checks

The codebase-memory graph includes a large `worktrees/` directory and had partial Swift parsing in several test files; use the main checkout source and direct text/build verification for current claims. The current checkout has substantial pre-existing modified and untracked content; do not assume its changes are disposable. Simulator deployment target is 27.0. Tests must use a concrete iOS 27 simulator destination, not `generic/platform=iOS Simulator`.
