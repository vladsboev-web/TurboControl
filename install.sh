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

# 3. Copy to /Applications
echo "--> Installing to /Applications/TurboControl.app..."
rm -rf "/Applications/TurboControl.app"
cp -R "$DIR/build/TurboControl.app" "/Applications/TurboControl.app"
xattr -cr "/Applications/TurboControl.app" 2>/dev/null || true

# 4. Install Helper (requires sudo once)
echo "--> Setting up privileged helper (requires root permissions once)..."
sudo "$DIR/Scripts/setup_helper.sh"

# 5. Launch
echo "--> Launching TurboControl..."
open "/Applications/TurboControl.app"

echo "=========================================="
echo "   Installation completed successfully!   "
echo "=========================================="
echo "TurboControl is now running in your Menu Bar."
