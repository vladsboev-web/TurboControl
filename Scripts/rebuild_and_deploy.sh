#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$DIR")"

echo "1. Killing old instances..."
pkill -9 -f "TurboControl" 2>/dev/null || true
sleep 1

echo "2. Building app..."
"$PROJECT_DIR/Scripts/build_app.sh"

echo "3. Copying to /Applications/TurboControl.app..."
rm -rf "/Applications/TurboControl.app"
cp -R "$PROJECT_DIR/build/TurboControl.app" "/Applications/TurboControl.app"

echo "4. Launching new version..."
open "/Applications/TurboControl.app"

echo "SUCCESS"
