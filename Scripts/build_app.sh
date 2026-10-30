#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/TurboControl.app"

echo "==> Building TurboControl for macOS (x86_64)..."

mkdir -p "$BUILD_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 1. Compile C SMCBridge
echo "--> Compiling SMCBridge.c..."
clang -O2 -target x86_64-apple-macos12.0 -c "$PROJECT_DIR/Sources/Bridge/SMCBridge.c" \
    -o "$BUILD_DIR/SMCBridge.o" \
    -I "$PROJECT_DIR/Sources/Bridge"

# 2. Compile turbocontrol-fan binary
echo "--> Compiling turbocontrol-fan..."
clang -O2 -target x86_64-apple-macos12.0 "$PROJECT_DIR/Sources/Bridge/smc_fan_writer.c" \
    -o "$BUILD_DIR/turbocontrol-fan" \
    -framework IOKit
chmod +x "$BUILD_DIR/turbocontrol-fan"

# 3. Compile Swift Sources
echo "--> Compiling Swift sources..."
swiftc -O \
    -target x86_64-apple-macos12.0 \
    -import-objc-header "$PROJECT_DIR/Sources/Bridge/TurboControl-Bridging-Header.h" \
    -I "$PROJECT_DIR/Sources/Bridge" \
    "$PROJECT_DIR/Sources/main.swift" \
    "$PROJECT_DIR/Sources/AppDelegate.swift" \
    "$PROJECT_DIR/Sources/Models/AppSettings.swift" \
    "$PROJECT_DIR/Sources/Models/SystemMetrics.swift" \
    "$PROJECT_DIR/Sources/Services/LaunchAtLogin.swift" \
    "$PROJECT_DIR/Sources/Services/SMCReader.swift" \
    "$PROJECT_DIR/Sources/Services/UsageReader.swift" \
    "$PROJECT_DIR/Sources/Services/TurboBoostService.swift" \
    "$PROJECT_DIR/Sources/Services/FanControlService.swift" \
    "$PROJECT_DIR/Sources/Views/MetricCardView.swift" \
    "$PROJECT_DIR/Sources/Views/FanControlCardView.swift" \
    "$PROJECT_DIR/Sources/Views/SettingsView.swift" \
    "$PROJECT_DIR/Sources/Views/MainPopoverView.swift" \
    "$BUILD_DIR/SMCBridge.o" \
    -framework Cocoa \
    -framework SwiftUI \
    -framework IOKit \
    -framework ServiceManagement \
    -o "$APP_DIR/Contents/MacOS/TurboControl"

# 4. Copy Bundle Resources
echo "--> Copying Info.plist and resources..."
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
echo "APPL????" > "$APP_DIR/Contents/PkgInfo"

if [ -d "$PROJECT_DIR/Resources/DisableTurboBoost.kext" ]; then
    cp -R "$PROJECT_DIR/Resources/DisableTurboBoost.kext" "$APP_DIR/Contents/Resources/DisableTurboBoost.kext"
fi
if [ -f "$PROJECT_DIR/Scripts/turbocontrol-helper" ]; then
    cp "$PROJECT_DIR/Scripts/turbocontrol-helper" "$APP_DIR/Contents/Resources/turbocontrol-helper"
fi
if [ -f "$BUILD_DIR/turbocontrol-fan" ]; then
    cp "$BUILD_DIR/turbocontrol-fan" "$APP_DIR/Contents/Resources/turbocontrol-fan"
fi
if [ -f "$PROJECT_DIR/Scripts/setup_helper.sh" ]; then
    cp "$PROJECT_DIR/Scripts/setup_helper.sh" "$APP_DIR/Contents/Resources/setup_helper.sh"
fi
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# 5. Ad-hoc Code Sign (sign Mach-O binaries explicitly to keep legacy DisableTurboBoost.kext unsigned for Apple's SHA-1 whitelist)
echo "--> Signing TurboControl.app..."
codesign --force --sign - "$APP_DIR/Contents/Resources/turbocontrol-fan"
codesign --force --sign - "$APP_DIR"

echo "==> Build complete: $APP_DIR"
