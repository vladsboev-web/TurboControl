#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

clang -O2 -target x86_64-apple-macos12.0 \
    -c "$PROJECT_DIR/Sources/Bridge/SMCBridge.c" \
    -o "$TMP_DIR/SMCBridge.o" \
    -I "$PROJECT_DIR/Sources/Bridge"

swiftc -O \
    -target x86_64-apple-macos12.0 \
    -import-objc-header "$PROJECT_DIR/Sources/Bridge/TurboControl-Bridging-Header.h" \
    -I "$PROJECT_DIR/Sources/Bridge" \
    "$PROJECT_DIR/Sources/Models/AppSettings.swift" \
    "$PROJECT_DIR/Sources/Models/SystemMetrics.swift" \
    "$PROJECT_DIR/Sources/Services/HelperClient.swift" \
    "$PROJECT_DIR/Sources/Services/LaunchAtLogin.swift" \
    "$PROJECT_DIR/Sources/Services/SMCReader.swift" \
    "$PROJECT_DIR/Sources/Services/UsageReader.swift" \
    "$PROJECT_DIR/Sources/Services/TurboBoostService.swift" \
    "$PROJECT_DIR/Sources/Services/FanControlService.swift" \
    "$PROJECT_DIR/Sources/Services/AutomationService.swift" \
    "$PROJECT_DIR/Tests/TurboControlTests.swift" \
    "$TMP_DIR/SMCBridge.o" \
    -framework Cocoa \
    -framework SwiftUI \
    -framework IOKit \
    -framework ServiceManagement \
    -o "$TMP_DIR/TurboControlTests"

"$TMP_DIR/TurboControlTests"
