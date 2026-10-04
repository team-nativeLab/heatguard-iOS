#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_directory=$(mktemp -d /private/tmp/heatguard-notification-tests.XXXXXX)
mkdir -p "$test_directory/Sources/HeatGuardNotificationCore" "$test_directory/Tests/HeatGuardNotificationCoreTests"
for source in Network/HGAPIClient.swift Network/HGAPIPath.swift Auth/HGAuthenticationService.swift Extensions/Date+HGFormatting.swift Emergency/HGEmergencyCallService.swift Notifications/HGNotificationService.swift; do
    ln -s "$project_root/heatguard-iOS/Core/$source" "$test_directory/Sources/HeatGuardNotificationCore/$(basename "$source")"
done
cp "$project_root/Tests/Notifications/NotificationRoutingTests.swift" "$test_directory/Tests/HeatGuardNotificationCoreTests/"
cp "$project_root/Tests/Network/AuthenticationErrorTests.swift" "$test_directory/Tests/HeatGuardNotificationCoreTests/"
cat > "$test_directory/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "HeatGuardNotificationTests", platforms: [.macOS(.v14)], targets: [.target(name: "HeatGuardNotificationCore"), .testTarget(name: "HeatGuardNotificationCoreTests", dependencies: ["HeatGuardNotificationCore"])], swiftLanguageModes: [.v5])
PACKAGE
swift test --package-path "$test_directory"
