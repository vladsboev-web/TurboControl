#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$DIR")"

echo "1. Gracefully stopping old instances..."
if pgrep -x "TurboControl" >/dev/null 2>&1; then
    osascript -e 'quit app "TurboControl"' 2>/dev/null || true
    for _ in {1..20}; do
        if ! pgrep -x "TurboControl" >/dev/null 2>&1; then break; fi
        sleep 0.1
    done
    if pgrep -x "TurboControl" >/dev/null 2>&1; then
        pkill -x "TurboControl" 2>/dev/null || true
        sleep 0.5
        pkill -9 -x "TurboControl" 2>/dev/null || true
    fi
fi

echo "2. Building app..."
"$PROJECT_DIR/Scripts/build_app.sh"

echo "3. Copying to /Applications/TurboControl.app and setting up helper..."
if id -Gn | grep -qw "admin"; then
    sudo "$PROJECT_DIR/Scripts/setup_helper.sh" --install-app
else
    rm -rf "/Applications/TurboControl.app"
    cp -R "$PROJECT_DIR/build/TurboControl.app" "/Applications/TurboControl.app"
fi

echo "4. Launching new version..."
open "/Applications/TurboControl.app"

echo "SUCCESS"
