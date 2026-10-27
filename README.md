# ⚡️ TurboControl for macOS (Intel)

<p align="center">
  <b>🇷🇺 <a href="#-русский-описание-и-установка">Русская версия</a></b> &nbsp;|&nbsp; <b>🇬🇧 <a href="#-english-overview--installation">English Version</a></b>
</p>

---

## 🇷🇺 Русский: Описание и установка

**TurboControl** — нативное, ультра-легковесное приложение для верхней строки меню (Menu Bar) macOS на базе процессоров **Intel**. Позволяет в один клик отключать и включать **Intel Turbo Boost**, управлять оборотами кулера (вентилятора) и отслеживать температуру и нагрузку CPU / GPU в реальном времени.

### ✨ Возможности
- **Управление Intel Turbo Boost в 1 клик:**
  - 🍃 **Отключен (Холодный режим):** Снижает нагрев на 15–25°C, избавляет от шума кулера и продлевает время работы от батареи.
  - ⚡️ **Включен (Макс. частота):** Полная мощность процессора для тяжелых задач.
- **Быстрое меню по правому клику:** Нажмите правой кнопкой мыши по иконке в верхней панели (Menu Bar), чтобы мгновенно переключить Turbo Boost или выйти из программы.
- **Умное управление вентилятором (Кулером):**
  - `Авто (Apple)` — стандартный тихий заводской профиль macOS.
  - `Умный (Ранний)` — плавный ранний обдув с 50–55°C, удерживающий ноутбук холодным (< 75°C) до начала троттлинга.
  - `Макс` — максимальная продувка (7200 RPM).
  - `Ручной` — точная настройка оборотов ползунком (1200–7200 RPM).
- **Мониторинг в реальном времени:** Температура (°C) и загрузка (%) процессора (CPU) и графики (GPU) с адаптивной контрастной цветовой шкалой.
- **Работа без пароля:** Пароль администратора вводится **только один раз** при установке. Дальше переключение Turbo Boost и кулера работает мгновенно и без запросов пароля.
- **Два языка интерфейса (RU / EN):** Переключение между русским и английским языком прямо в шапке окна (кнопка `RU`/`EN`) или в настройках.
- **Полноэкранный режим без обрезания окна:** Специальная плавающая панель не уезжает за край экрана, когда в полноэкранном режиме прячется верхнее меню macOS.

---

### 🚀 Простая установка «для чайников» (в 3 шага)

Вам не нужно ничего настраивать вручную. Выберите самый удобный способ:

#### Способ А: Установка двойным кликом (Самый простой)
1. **Скачайте проект:** На странице GitHub нажмите зеленую кнопку **`<> Code`** → **`Download ZIP`** и распакуйте архив (например, в «Загрузки»).
2. Откройте распакованную папку `TurboControl` и **дважды кликните** по файлу **`Install TurboControl.command`**.
   > 💡 *Если macOS покажет окно «Не удается открыть файл, так как не удалось проверить разработчика»:* нажмите **«Готово» (или ОК)**, затем кликните по файлу `Install TurboControl.command` **правой кнопкой мыши**, зажав клавишу **`Control`**, выберите **«Открыть»** → **«Открыть»**.
3. Откроется окно Терминала, программа сама соберется и попросит ввести `Password:`.
   - **Введите пароль от вашего Mac** и нажмите `Enter`.
   - ⚠️ *При вводе пароля в Терминале буквы и звездочки НЕ отображаются — это стандартная защита macOS. Просто наберите пароль вслепую и нажмите `Enter`.*
4. Готово! Приложение автоматически установится в «Программы» (`/Applications/TurboControl.app`) и запустится — в правом верхнем углу экрана возле часов появится значок ⚡️ или 🍃.

#### Способ Б: Установка одной командой через Терминал
1. Откройте **Терминал** (`Cmd + Пробел` → напишите `Терминал` → `Enter`).
2. Скопируйте и вставьте следующую команду (или перетащите папку проекта в Терминал):
   ```bash
   git clone https://github.com/vladsboev-web/TurboControl.git ~/Downloads/TurboControl && cd ~/Downloads/TurboControl && ./install.sh
   ```
   *(Если вы уже скачали папку вручную, просто перейдите в неё и запустите `./install.sh`)*.
3. Введите пароль от Mac (вслепую) и нажмите `Enter`.

---

### ⚠️ Важное примечание для macOS (Разрешение расширения ядра `.kext`)
Для управления регистром процессора Intel (`MSR_IA32_MISC_ENABLE`) используется проверенный драйвер `DisableTurboBoost.kext`.
- Если при первом отключении Turbo Boost macOS покажет уведомление **«Системное расширение заблокировано» (System Extension Blocked)**:
  1. Откройте **Системные настройки** → **Конфиденциальность и безопасность** (Privacy & Security).
  2. Прокрутите вниз и нажмите кнопку **«Разрешить» (Allow)** напротив системного ПО.
  3. Перезагрузите Mac по запросу системы — после этого всё будет работать в один клик.

### 🗑 Удаление (Uninstall)
Чтобы полностью удалить приложение и вернуть стандартные настройки:
```bash
pkill -f TurboControl
sudo /sbin/kextunload -b com.rugarciap.DisableTurboBoost 2>/dev/null || true
sudo rm -rf /Applications/TurboControl.app /usr/local/bin/turbocontrol-helper /usr/local/bin/turbocontrol-fan /etc/sudoers.d/turbocontrol /Library/Extensions/DisableTurboBoost.kext
```

### 📄 Лицензия

[MIT](LICENSE)

---
---

## 🇬🇧 English: Overview & Installation

**TurboControl** is a native, ultra-lightweight macOS Menu Bar utility for **Intel-based Macs**. It lets you toggle **Intel Turbo Boost** in one click, control cooling fan speeds (RPM), and monitor real-time CPU & GPU temperatures and load.

### ✨ Features
- **One-Click Intel Turbo Boost Toggle:**
  - 🍃 **Disabled (Cool Mode):** Drops CPU temps by 15–25°C, keeps fans silent, and significantly extends battery life.
  - ⚡️ **Enabled (Max Frequency):** Unleashes full Turbo Boost clock speeds for heavy workloads.
- **Right-Click Quick Menu:** Right-click (or `Ctrl + Click`) the Menu Bar icon to immediately toggle Turbo Boost or quit the app without opening the main window.
- **Smart Fan Control:**
  - `Auto (Apple)` — Factory default macOS thermal curve.
  - `Smart (Early)` — Proactive cooling starting at 50–55°C to keep temperatures below 75°C before thermal throttling occurs.
  - `Max` — Full blast at 7200 RPM.
  - `Manual` — Custom target RPM via slider (1200–7200 RPM).
- **Real-Time Sensor Monitoring:** Live CPU & GPU temperatures (°C) and utilization (%) with high-contrast adaptive color indicators for both Light and Dark macOS themes.
- **Passwordless Operation:** You only enter your administrator password **once** during installation. All future Turbo Boost and fan adjustments happen instantly with zero password prompts.
- **Bilingual UI (EN / RU):** Switch between English and Russian anytime using the `RU`/`EN` pill in the header or inside Settings.
- **Fullscreen-Safe Floating Window:** Never gets clipped at the top of the screen when the macOS Menu Bar auto-hides in fullscreen apps.

---

### 🚀 Beginner-Friendly Installation (Step-by-Step)

Requirements: **Intel-based Mac**, **macOS 12.0 Monterey or newer**, and Command Line Tools (`xcode-select --install` if not installed).

#### Option A: Double-Click Installer (Easiest)
1. **Download the project:** Click the green **`<> Code`** button on GitHub → **`Download ZIP`**, then unzip the downloaded folder.
2. Open the `TurboControl` folder and **double-click** **`Install TurboControl.command`**.
   > 💡 *If macOS says the file cannot be opened because the developer is unidentified:* click **Done/OK**, then **Right-Click** (or `Control + Click`) on `Install TurboControl.command` and choose **Open** → **Open**.
3. A Terminal window will open, build the app, and ask for `Password:`.
   - **Type your Mac login password** and press `Enter`.
   - ⚠️ *Note: Nothing will appear on screen while you type your password (no stars or letters) — this is normal macOS security. Just type it and hit `Enter`.*
4. Done! **TurboControl** is now installed in `/Applications/TurboControl.app` and running in your top-right Menu Bar (⚡️ / 🍃 icon).

#### Option B: One-Line Terminal Install
1. Open **Terminal** (`Cmd + Space` → type `Terminal` → `Enter`).
2. Run:
   ```bash
   git clone https://github.com/vladsboev-web/TurboControl.git ~/Downloads/TurboControl && cd ~/Downloads/TurboControl && ./install.sh
   ```
   *(Or navigate to your downloaded folder with `cd` and run `./install.sh`)*.
3. Enter your Mac password when prompted and press `Enter`.

---

### ⚠️ Note on macOS Kernel Extension (`.kext`) Approval
Disabling Intel Turbo Boost requires toggling the `MSR_IA32_MISC_ENABLE` CPU register via `DisableTurboBoost.kext`.
- If macOS shows a **"System Extension Blocked"** prompt the first time you disable Turbo Boost:
  1. Open **System Settings** → **Privacy & Security**.
  2. Scroll down to the Security section and click **Allow**.
  3. Restart your Mac if prompted — after that, Turbo Boost will toggle seamlessly in one click.

### 🛠 Manual Build & Project Structure
```text
TurboControl/
├── Install TurboControl.command  # Double-click installer for beginners
├── install.sh                    # CLI build & installation script
├── Resources/                    # AppIcon.icns, Info.plist, DisableTurboBoost.kext
├── Scripts/                      # Build script & privileged helper setup
└── Sources/
    ├── Bridge/                   # IOKit AppleSMC C bridge & fan writer
    ├── Models/                   # AppSettings, localization (RU/EN), SystemMetrics
    ├── Services/                 # SMCReader, UsageReader, TurboBoostService, FanControlService
    └── Views/                    # SwiftUI views & custom floating panel
```

To build `.app` bundle manually without installing:
```bash
./Scripts/build_app.sh
```

### 🗑 Uninstall
To completely remove TurboControl and restore default Apple fan & CPU settings:
```bash
pkill -f TurboControl
sudo /sbin/kextunload -b com.rugarciap.DisableTurboBoost 2>/dev/null || true
sudo rm -rf /Applications/TurboControl.app /usr/local/bin/turbocontrol-helper /usr/local/bin/turbocontrol-fan /etc/sudoers.d/turbocontrol /Library/Extensions/DisableTurboBoost.kext
```

---

### 📄 License

[MIT](LICENSE)
