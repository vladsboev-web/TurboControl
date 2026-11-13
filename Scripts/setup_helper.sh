#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# If built app exists in project build folder and /Applications/TurboControl.app is not yet updated by caller, install it when requested
if [ "$1" = "--install-app" ] && [ -d "$PROJECT_DIR/build/TurboControl.app" ] && [ ! -L "$PROJECT_DIR/build/TurboControl.app" ]; then
    rm -rf "/Applications/TurboControl.app"
    cp -R "$PROJECT_DIR/build/TurboControl.app" "/Applications/TurboControl.app"
    xattr -cr "/Applications/TurboControl.app" 2>/dev/null || true
fi

# Ensure /Applications/TurboControl.app is securely owned by root:wheel to prevent privilege escalation
if [ -d "/Applications/TurboControl.app" ] && [ ! -L "/Applications/TurboControl.app" ]; then
    chown -R root:wheel "/Applications/TurboControl.app"
    chmod -R 755 "/Applications/TurboControl.app"
fi

HELPER_DIR="/Library/PrivilegedHelperTools"
HELPER_PATH="$HELPER_DIR/turbocontrol-helper"
FAN_PATH="$HELPER_DIR/turbocontrol-fan"

if [ ! -d "$HELPER_DIR" ]; then
    mkdir -p "$HELPER_DIR"
    chown root:wheel "$HELPER_DIR"
    chmod 1755 "$HELPER_DIR"
fi

# Remove legacy binaries from user-writable /usr/local/bin
rm -f /usr/local/bin/turbocontrol-helper /usr/local/bin/turbocontrol-fan

if [ -f "$SCRIPT_DIR/turbocontrol-helper" ] && [ ! -L "$SCRIPT_DIR/turbocontrol-helper" ]; then
    cp "$SCRIPT_DIR/turbocontrol-helper" "$HELPER_PATH"
    chmod 755 "$HELPER_PATH"
    chown root:wheel "$HELPER_PATH"
fi

FAN_SRC=""
for candidate in \
    "$SCRIPT_DIR/turbocontrol-fan" \
    "/Applications/TurboControl.app/Contents/Resources/turbocontrol-fan" \
    "$PROJECT_DIR/build/TurboControl.app/Contents/Resources/turbocontrol-fan" \
    "$PROJECT_DIR/build/turbocontrol-fan"; do
    if [ -f "$candidate" ] && [ ! -L "$candidate" ]; then
        FAN_SRC="$candidate"
        break
    fi
done

if [ -n "$FAN_SRC" ]; then
    cp "$FAN_SRC" "$FAN_PATH"
    chmod 755 "$FAN_PATH"
    chown root:wheel "$FAN_PATH"
fi

# Copy kext
KEXT_SRC=""
for candidate in \
    "$SCRIPT_DIR/DisableTurboBoost.kext" \
    "/Applications/TurboControl.app/Contents/Resources/DisableTurboBoost.kext" \
    "$PROJECT_DIR/build/TurboControl.app/Contents/Resources/DisableTurboBoost.kext" \
    "$PROJECT_DIR/Resources/DisableTurboBoost.kext"; do
    if [ -d "$candidate" ] && [ ! -L "$candidate" ]; then
        KEXT_SRC="$candidate"
        break
    fi
done

if [ -n "$KEXT_SRC" ]; then
    rm -rf /Library/Extensions/DisableTurboBoost.kext
    cp -R "$KEXT_SRC" /Library/Extensions/DisableTurboBoost.kext
    xattr -cr /Library/Extensions/DisableTurboBoost.kext 2>/dev/null || true
    chown -R root:wheel /Library/Extensions/DisableTurboBoost.kext
    chmod -R 755 /Library/Extensions/DisableTurboBoost.kext
fi

# Configure sudoers: restrict to %admin (plus the invoking standard console user if non-admin) and whitelist exact commands
TARGET_USER="$SUDO_USER"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    TARGET_USER=$(/usr/bin/stat -f '%Su' /dev/console 2>/dev/null || true)
fi

mkdir -p /etc/sudoers.d
TMP_SUDOERS=$(mktemp)
trap 'rm -f "$TMP_SUDOERS"' EXIT

cat > "$TMP_SUDOERS" <<EOF
Cmnd_Alias TURBOCONTROL_CMDS = \
    $HELPER_PATH status, \
    $HELPER_PATH disable, \
    $HELPER_PATH enable, \
    $HELPER_PATH fan auto, \
    $HELPER_PATH fan manual [0-9][0-9][0-9], \
    $HELPER_PATH fan manual [0-9][0-9][0-9][0-9], \
    $HELPER_PATH cpu_freq

%admin ALL=(root) NOPASSWD: TURBOCONTROL_CMDS
EOF

if [ -n "$TARGET_USER" ] && [[ "$TARGET_USER" =~ ^[a-zA-Z0-9._-]+$ ]] && [ "$TARGET_USER" != "root" ] && [ "$TARGET_USER" != "loginwindow" ] && [[ "$TARGET_USER" != _* ]]; then
    if ! id -Gn "$TARGET_USER" 2>/dev/null | grep -qw "admin"; then
        echo "$TARGET_USER ALL=(root) NOPASSWD: TURBOCONTROL_CMDS" >> "$TMP_SUDOERS"
    fi
fi

chmod 440 "$TMP_SUDOERS"

if visudo -cf "$TMP_SUDOERS"; then
    mv "$TMP_SUDOERS" /etc/sudoers.d/turbocontrol
    chmod 440 /etc/sudoers.d/turbocontrol
    chown root:wheel /etc/sudoers.d/turbocontrol
fi
