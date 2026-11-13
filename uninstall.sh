#!/bin/bash
set -e

echo "=========================================="
echo "      TurboControl Uninstaller            "
echo "=========================================="

# 1. Gracefully stop TurboControl so fans return to Apple Auto
echo "--> Stopping TurboControl..."
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

# 2. Remove legacy LaunchAgent plist if present
TARGET_HOME="$HOME"
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    TARGET_HOME=$(eval echo "~$SUDO_USER")
fi
rm -f "$TARGET_HOME/Library/LaunchAgents/com.turbocontrol.app.launchagent.plist"

# 3. Privileged cleanup
CLEANUP_CMD='
if [ -x /Library/PrivilegedHelperTools/turbocontrol-fan ]; then
    /Library/PrivilegedHelperTools/turbocontrol-fan auto >/dev/null 2>&1 || true
fi
/sbin/kextunload -b com.rugarciap.DisableTurboBoost 2>/dev/null || /usr/bin/kmutil unload -b com.rugarciap.DisableTurboBoost 2>/dev/null || true
rm -rf \
    /Applications/TurboControl.app \
    /Library/PrivilegedHelperTools/turbocontrol-helper \
    /Library/PrivilegedHelperTools/turbocontrol-fan \
    /usr/local/bin/turbocontrol-helper \
    /usr/local/bin/turbocontrol-fan \
    /etc/sudoers.d/turbocontrol \
    /Library/Extensions/DisableTurboBoost.kext
'

echo "--> Removing app, helper binaries, sudoers rule and kext..."
if [ "$(id -u)" -eq 0 ]; then
    bash -c "$CLEANUP_CMD"
elif id -Gn | grep -qw "admin"; then
    sudo bash -c "$CLEANUP_CMD"
else
    ESCAPED_CMD=$(printf '%s' "$CLEANUP_CMD" | sed 's/\\/\\\\/g; s/"/\\"/g')
    osascript -e "do shell script \"$ESCAPED_CMD\" with administrator privileges"
fi

echo "=========================================="
echo "   TurboControl uninstalled cleanly!      "
echo "=========================================="
