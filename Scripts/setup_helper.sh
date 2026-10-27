#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

mkdir -p /usr/local/bin
cp "$SCRIPT_DIR/turbocontrol-helper" /usr/local/bin/turbocontrol-helper
chmod 755 /usr/local/bin/turbocontrol-helper
chown root:wheel /usr/local/bin/turbocontrol-helper

FAN_SRC=""
if [ -f "$PROJECT_DIR/build/turbocontrol-fan" ]; then
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
if [ -d "$PROJECT_DIR/Resources/DisableTurboBoost.kext" ]; then
    KEXT_SRC="$PROJECT_DIR/Resources/DisableTurboBoost.kext"
elif [ -d "/Applications/TurboControl.app/Contents/Resources/DisableTurboBoost.kext" ]; then
    KEXT_SRC="/Applications/TurboControl.app/Contents/Resources/DisableTurboBoost.kext"
fi

if [ -n "$KEXT_SRC" ]; then
    rm -rf /Library/Extensions/DisableTurboBoost.kext
    cp -R "$KEXT_SRC" /Library/Extensions/DisableTurboBoost.kext
    chown -R root:wheel /Library/Extensions/DisableTurboBoost.kext
    chmod -R 755 /Library/Extensions/DisableTurboBoost.kext
fi

# Configure sudoers
mkdir -p /etc/sudoers.d
TMP_SUDOERS=$(mktemp)
trap 'rm -f "$TMP_SUDOERS"' EXIT
echo "%admin ALL=(ALL) NOPASSWD: /usr/local/bin/turbocontrol-helper" > "$TMP_SUDOERS"
chmod 440 "$TMP_SUDOERS"

if visudo -cf "$TMP_SUDOERS"; then
    mv "$TMP_SUDOERS" /etc/sudoers.d/turbocontrol
    chmod 440 /etc/sudoers.d/turbocontrol
    chown root:wheel /etc/sudoers.d/turbocontrol
fi
