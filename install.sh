#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "      TurboControl Installation           "
echo "=========================================="

# 1. Stop running instance if any
pkill -9 -f "TurboControl" 2>/dev/null || true

# 2. Build
"$DIR/Scripts/build_app.sh"

# 3. Copy to /Applications & Install Helper (supports both Admin and Standard macOS accounts)
echo "--> Installing to /Applications/TurboControl.app and setting up privileged helper..."
if id -Gn | grep -qw "admin"; then
    rm -rf "/Applications/TurboControl.app"
    cp -R "$DIR/build/TurboControl.app" "/Applications/TurboControl.app"
    xattr -cr "/Applications/TurboControl.app" 2>/dev/null || true
    sudo "$DIR/Scripts/setup_helper.sh"
else
    echo "    (Standard user account detected — requesting Administrator credentials via macOS dialog...)"
    ESCAPED_SCRIPT=$(printf '%s' "$DIR/Scripts/setup_helper.sh" | sed 's/\\/\\\\/g; s/"/\\"/g')
    osascript -e "do shell script \"\\\"$ESCAPED_SCRIPT\\\" --install-app\" with administrator privileges"
fi

# 5. Launch
echo "--> Launching TurboControl..."
open "/Applications/TurboControl.app"

echo "=========================================="
echo "   Installation completed successfully!   "
echo "=========================================="
echo "TurboControl is now running in your Menu Bar."
