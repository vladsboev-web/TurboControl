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

"$DIR/install.sh"

echo ""
echo "=========================================="
echo " ✅ Готово! / Installation complete!      "
echo "=========================================="
echo " [RU] Значок молнии/листика появился в верхней панели (Menu Bar)."
echo " [EN] Look for the bolt/leaf icon in your top Menu Bar."
echo ""
read -n 1 -s -r -p "Press any key to close this window / Нажмите любую клавишу для закрытия..."
echo ""
