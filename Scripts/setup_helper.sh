#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# If built app exists in project build folder and /Applications/TurboControl.app is not yet updated by caller, install it when requested
if [ "$1" = "--install-app" ] && [ -d "$PROJECT_DIR/build/TurboControl.app" ]; then
    rm -rf "/Applications/TurboControl.app"
    cp -R "$PROJECT_DIR/build/TurboControl.app" "/Applications/TurboControl.app"
    xattr -cr "/Applications/TurboControl.app" 2>/dev/null || true
    if [ -n "$SUDO_USER" ]; then
        chown -R "$SUDO_USER":admin "/Applications/TurboControl.app" 2>/dev/null || true
    fi
fi

mkdir -p /usr/local/bin
cp "$SCRIPT_DIR/turbocontrol-helper" /usr/local/bin/turbocontrol-helper
chmod 755 /usr/local/bin/turbocontrol-helper
chown root:wheel /usr/local/bin/turbocontrol-helper

FAN_SRC=""
if [ -f "$SCRIPT_DIR/turbocontrol-fan" ]; then
    FAN_SRC="$SCRIPT_DIR/turbocontrol-fan"
elif [ -f "$PROJECT_DIR/build/turbocontrol-fan" ]; then
    FAN_SRC="$PROJECT_DIR/build/turbocontrol-fan"
elif [ -f "/Applications/TurboControl.app/Contents/Resources/turbocontrol-fan" ]; then
    FAN_SRC="/Applications/TurboControl.app/Contents/Resources/turbocontrol-fan"
elif [ -f "$PROJECT_DIR/Resources/turbocontrol-fan" ]; then
    FAN_SRC="$PROJECT_DIR/Resources/turbocontrol-fan"
fi

if [ -n "$FAN_SRC" ]; then
    cp "$FAN_SRC" /usr/local/bin/turbocontrol-fan
    chmod 755 /usr/local/bin/turbocontrol-fan
    chown root:wheel /usr/local/bin/turbocontrol-fan
fi

# Copy kext
KEXT_SRC=""
if [ -d "$SCRIPT_DIR/DisableTurboBoost.kext" ]; then
    KEXT_SRC="$SCRIPT_DIR/DisableTurboBoost.kext"
elif [ -d "$PROJECT_DIR/Resources/DisableTurboBoost.kext" ]; then
    KEXT_SRC="$PROJECT_DIR/Resources/DisableTurboBoost.kext"
elif [ -d "/Applications/TurboControl.app/Contents/Resources/DisableTurboBoost.kext" ]; then
    KEXT_SRC="/Applications/TurboControl.app/Contents/Resources/DisableTurboBoost.kext"
fi

if [ -n "$KEXT_SRC" ]; then
    rm -rf /Library/Extensions/DisableTurboBoost.kext
    cp -R "$KEXT_SRC" /Library/Extensions/DisableTurboBoost.kext
    xattr -cr /Library/Extensions/DisableTurboBoost.kext 2>/dev/null || true
    chown -R root:wheel /Library/Extensions/DisableTurboBoost.kext
    chmod -R 755 /Library/Extensions/DisableTurboBoost.kext
fi

# Configure sudoers (allow all local users so non-admin standard accounts work after one-time admin setup)
mkdir -p /etc/sudoers.d
TMP_SUDOERS=$(mktemp)
trap 'rm -f "$TMP_SUDOERS"' EXIT
echo "ALL ALL=(ALL) NOPASSWD: /usr/local/bin/turbocontrol-helper" > "$TMP_SUDOERS"
chmod 440 "$TMP_SUDOERS"

if visudo -cf "$TMP_SUDOERS"; then
    mv "$TMP_SUDOERS" /etc/sudoers.d/turbocontrol
    chmod 440 /etc/sudoers.d/turbocontrol
    chown root:wheel /etc/sudoers.d/turbocontrol
fi
