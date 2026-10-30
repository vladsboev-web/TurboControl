#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "    TurboControl Easy Installer           "
echo "    Простая установка TurboControl        "
echo "=========================================="
echo ""
echo "[RU] Сейчас приложение соберется и установится в /Applications."
echo "     В конце потребуется один раз ввести пароль от Mac (при вводе символы не отображаются — это нормально, просто введите пароль и нажмите Enter)."
echo ""
echo "[EN] Building and installing TurboControl to /Applications."
echo "     You will be asked for your Mac password once at the end (characters won't be shown while typing — just type it and press Enter)."
echo ""

# 1. Stop running instance if any
pkill -9 -f "TurboControl" 2>/dev/null || true

# 2. Build
"$DIR/Scripts/build_app.sh"

# 3. Copy to /Applications & Install Helper (supports both Admin and Standard macOS accounts)
echo "--> Installing to /Applications/TurboControl.app and setting up passwordless helper..."
if id -Gn | grep -qw "admin"; then
    rm -rf "/Applications/TurboControl.app"
    cp -R "$DIR/build/TurboControl.app" "/Applications/TurboControl.app"
    xattr -cr "/Applications/TurboControl.app" 2>/dev/null || true
    sudo "$DIR/Scripts/setup_helper.sh"
else
    echo "    [RU] Обнаружена обычная учетная запись (не админ) — введите имя и пароль администратора в появившемся окне macOS."
    echo "    [EN] Standard user account detected — please enter Administrator username and password in the macOS prompt."
    ESCAPED_SCRIPT=$(printf '%s' "$DIR/Scripts/setup_helper.sh" | sed 's/\\/\\\\/g; s/"/\\"/g')
    osascript -e "do shell script \"\\\"$ESCAPED_SCRIPT\\\" --install-app\" with administrator privileges"
fi

# 5. Launch app
echo "--> Launching TurboControl..."
open "/Applications/TurboControl.app"

echo ""
echo "=========================================="
echo " ✅ Готово! / Installation complete!      "
echo "=========================================="
echo " [RU] Значок молнии/листика появился в верхней панели (Menu Bar)."
echo " [EN] Look for the bolt/leaf icon in your top Menu Bar."
echo ""
read -n 1 -s -r -p "Press any key to close this window / Нажмите любую клавишу для закрытия..."
echo ""
