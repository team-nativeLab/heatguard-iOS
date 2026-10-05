#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
xcodebuild test \
    -project "$project_root/heatguard-iOS.xcodeproj" \
    -scheme heatguard-iOS \
    -destination "${TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17}" \
    CODE_SIGNING_ALLOWED=NO
