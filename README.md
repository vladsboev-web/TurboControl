# ⚡️ TurboControl for macOS (Intel)

<p align="center">
  <b>🇷🇺 <a href="#-русский-описание-и-установка">Русская версия</a></b> &nbsp;|&nbsp; <b>🇬🇧 <a href="#-english-overview--installation">English Version</a></b>
</p>

---

## 🇷🇺 Русский: Описание и установка

**TurboControl** — нативное, ультра-легковесное приложение для верхней строки меню (Menu Bar) macOS на базе процессоров **Intel** (и в режиме «Только мониторинг» для Apple Silicon). Позволяет в один клик отключать **Intel Turbo Boost**, управлять оборотами кулеров, отслеживать температуру, частоту, загрузку и энергопотребление в Ваттах (`W`), управлять системным энергосбережением, «холодным сном», лимитом заряда батареи, процессами/блокировщиками сна и графиками истории.

### ✨ Возможности
- **Управление Intel Turbo Boost в 1 клик:**
  - 🍃 **Отключен (Холодный режим):** Снижает нагрев на 15–25°C, избавляет от шума кулера и продлевает время работы от батареи.
  - ⚡️ **Включен (Макс. частота):** Полная мощность процессора для тяжелых задач.
  - Опционально: отображение температуры CPU в строке меню, запоминание состояния Turbo Boost после сна и перезагрузки, автоскрытие элементов управления Turbo Boost в режиме «Только мониторинг» на Apple Silicon.
- **Быстрое меню по правому клику:** Нажмите правой кнопкой мыши (или `Ctrl + клик`) по иконке в Menu Bar, чтобы увидеть статус и мгновенно переключить Turbo Boost или выйти из программы.
- **Умное управление вентиляторами (Кулерами):**
  - `Авто (Apple)` — стандартный тихий заводской профиль macOS.
  - `Умный (Ранний)` — тихий Авто (0 RPM) ниже 52°C и плавный ранний обдув с 52–55°C (асимметричное сглаживание, держит `< 75°C`, при `≥ 84°C` — 7200 RPM).
  - `Макс` — максимальная продувка (7200 RPM).
  - `Ручной` — точная настройка оборотов ползунком (`1200–7200 RPM`), поддержка до 2 кулеров и обоих форматов SMC (`fpe2` для Pre-T2 и `flt ` для T2), с автосбросом в `Авто` при выходе.
- **Мониторинг в реальном времени:**
  - Температура CPU и GPU (`°C`) с адаптивной цветовой шкалой, загрузка CPU / GPU (`%`), **текущая частота CPU (`GHz`)** (`powermetrics` / `sysctl`), а также **мощность CPU (`W`)** и **общее энергопотребление системы (`W`)** через SMC (`PCPC`/`PC0R`/`PSTR`/`PDTR`) с фоллбэком на IOKit `AppleSmartBattery`.
  - Настраиваемая частота опроса (`4–60 сек`).
- **Питание, энергосбережение и защита батареи:**
  - **Системный Low Power Mode на главной:** быстрый переключатель встроенного режима энергосбережения macOS (показывается, если поддерживается текущей ОС и моделью Mac) с выбором области в Настройках (`Батарея / Сеть / Оба`).
  - **Режим «Холодный сон на батарее» (в Настройках):** отключает `Power Nap` и `tcpkeepalive` при работе от батареи (`pmset -b`), чтобы Mac не просыпался и не грелся в сумке/рюкзаке (при выключении восстанавливаются исходные значения; во сне при закрытой крышке «Локатор» не обновляется).
  - **Лимит заряда батареи (`80–95%`, для Intel Mac):** аппаратно-системная остановка зарядки на выбранном пороге (`BCLM` и `CH0B`/`CH0C` с гистерезисом 2%) **без принудительного разряда**; при выключении опции, выходе из приложения или удалении лимит автоматически сбрасывается на `100%`.
- **Автоматизация Turbo Boost (в Настройках):**
  - **По питанию:** отдельные правила при зарядке (`Включать / Не менять`) и от аккумулятора (`Выключать / Не менять`), плюс опция включения на низком заряде при подключении к сети.
  - **По температуре CPU:** отключение при нагреве (`85–100°C`) и обратное включение при остывании (гистерезис ≥ 10°C, обычный и расширенный режим от `50°C`).
  - **По уровню заряда:** отключение при низком заряде (`10–30%`) и включение при зарядке (гистерезис ≥ 10%, обычный и расширенный режим до `80%`).
- **Вкладка «Процессы» (ранее «Топ-5»):**
  - Показывает 5 самых нагруженных пользовательских приложений (без системных демонов) с сортировкой по `CPU %`, `GPU` или `Энергии`, кнопкой завершения процесса и правилом `⚡ Авто / Выкл / Вкл` для активного окна.
  - **Детектор «Что не даёт Mac уснуть» (режим «Сон»):** читает `pmset -g assertions` (без `sudo`), показывает процессы, блокирующие сон экрана или системы, причину блокировки и позволяет безопасно завершить пользовательские процессы (критичные системные демоны защищены).
- **Вкладка «Графики» (включается в Настройках):**
  - Отдельный тумблер в Настройках и выбор частоты записи (`30 сек – 5 мин`); при выключении вкладка скрывается и фоновый сбор останавливается.
  - 4 мини-графика истории (до 120 точек): **Температура CPU (`°C`)**, **Частота CPU (`GHz`)**, **Обороты кулера (`RPM`)** и **Общее потребление (`W`)** с текущим, минимальным и максимальным значениями.
- **Современный интерфейс, права и полноэкранный режим:**
  - Полупрозрачный стиль, плавное fade-появление, переключатель темы (`Авто / Светлая / Тёмная`), два языка (`RU / EN`), автозапуск при входе в macOS и полноэкранная плавающая панель (`388×548`), не обрезаемая строкой меню.
  - Пароль администратора вводится **только один раз** при установке; поддерживаются аккаунты администратора и обычные аккаунты; при обновлении приложения автоматически проверяется актуальность `/Library/PrivilegedHelperTools/turbocontrol-helper` с предложением обновить его в 1 клик.

---

### 🚀 Простая установка

Вам не нужно ничего настраивать вручную. Выберите самый удобный способ:

#### Способ А: Установка через Homebrew (Самый быстрый)
```bash
brew install --cask vladsboev-web/tap/turbocontrol
```

#### Способ Б: Установка двойным кликом (Без использования командной строки)
1. **Скачайте проект:** На странице GitHub нажмите зеленую кнопку **`<> Code`** → **`Download ZIP`** и распакуйте архив (например, в «Загрузки»).
2. Откройте распакованную папку `TurboControl` и **дважды кликните** по файлу **`Install TurboControl.command`**.
   > 💡 *Если macOS покажет окно «Не удается открыть файл, так как не удалось проверить разработчика»:* нажмите **«Готово» (или ОК)**, затем кликните по файлу `Install TurboControl.command` **правой кнопкой мыши**, зажав клавишу **`Control`**, выберите **«Открыть»** → **«Открыть»**.
3. Откроется окно Терминала, программа сама соберется и попросит ввести `Password:`.
   - **Введите пароль от вашего Mac** и нажмите `Enter`.
   - ⚠️ *При вводе пароля в Терминале буквы и звездочки НЕ отображаются — это стандартная защита macOS. Просто наберите пароль вслепую и нажмите `Enter`.*
4. Готово! Приложение автоматически установится в «Программы» (`/Applications/TurboControl.app`) и запустится — в правом верхнем углу экрана возле часов появится значок ⚡️ или 🍃.

#### Способ В: Установка одной командой через сборку из Git
1. Откройте **Терминал** (`Cmd + Пробел` → напишите `Терминал` → `Enter`).
2. Скопируйте и вставьте следующую команду:
   ```bash
   git clone https://github.com/vladsboev-web/TurboControl.git ~/Downloads/TurboControl && cd ~/Downloads/TurboControl && ./install.sh
   ```
3. Введите пароль от Mac (вслепую) и нажмите `Enter`.

---

### ⚠️ Важное примечание для macOS (Разрешение расширения ядра `.kext`)
Для управления регистром процессора Intel (`MSR_IA32_MISC_ENABLE`) используется проверенный драйвер `DisableTurboBoost.kext`.
- Если при первом отключении Turbo Boost macOS покажет уведомление **«Системное расширение заблокировано» (System Extension Blocked)**:
  1. Откройте **Системные настройки** → **Конфиденциальность и безопасность** (Privacy & Security).
  2. Прокрутите вниз и нажмите кнопку **«Разрешить» (Allow)** напротив системного ПО.
  3. Перезагрузите Mac по запросу системы — после этого всё будет работать в один клик.

### 🗑 Удаление (Uninstall)
Через скрипт деинсталляции из папки проекта:
```bash
./uninstall.sh
```
Если устанавливали через Homebrew:
```bash
brew uninstall --cask turbocontrol
```
Или вручную:
```bash
pkill -x TurboControl
sudo /Library/PrivilegedHelperTools/turbocontrol-fan auto 2>/dev/null || true
sudo /Library/PrivilegedHelperTools/turbocontrol-fan charge-inhibit 0 2>/dev/null || true
sudo /Library/PrivilegedHelperTools/turbocontrol-fan charge-limit 100 2>/dev/null || true
sudo /sbin/kextunload -b com.rugarciap.DisableTurboBoost 2>/dev/null || true
sudo rm -rf /Applications/TurboControl.app /Library/PrivilegedHelperTools/turbocontrol-helper /Library/PrivilegedHelperTools/turbocontrol-fan /usr/local/bin/turbocontrol-helper /usr/local/bin/turbocontrol-fan /etc/sudoers.d/turbocontrol /Library/Extensions/DisableTurboBoost.kext
```

### 📄 Лицензия

[MIT](LICENSE)

---
---

## 🇬🇧 English: Overview & Installation

**TurboControl** is a native, ultra-lightweight macOS Menu Bar utility for **Intel-based Macs** (with a Monitor Only fallback on Apple Silicon). It lets you toggle **Intel Turbo Boost** in one click, control cooling fan speeds (RPM), monitor real-time CPU & GPU temperatures, loads, frequencies, and power wattage (`W`), manage macOS Low Power Mode, cold sleep on battery, battery charge limits (`80–95%`), sleep-blocking processes, and performance history charts.

### ✨ Features
- **One-Click Intel Turbo Boost Toggle:**
  - 🍃 **Disabled (Cool Mode):** Drops CPU temps by 15–25°C, keeps fans silent, and significantly extends battery life.
  - ⚡️ **Enabled (Max Frequency):** Unleashes full Turbo Boost clock speeds for heavy workloads.
  - Optional CPU °C readout in the Menu Bar, automatic state restoration after sleep/reboot, and Monitor Only mode on Apple Silicon (hiding Intel-only controls).
- **Right-Click Quick Menu:** Right-click (or `Ctrl + Click`) the Menu Bar icon to check status, immediately toggle Turbo Boost, or quit the app without opening the main window.
- **Smart Fan Control:**
  - `Auto (Apple)` — Factory default macOS thermal curve.
  - `Smart (Early)` — Silent Auto (`0 RPM`) below 52°C, proactive cooling from 52–55°C with asymmetric smoothing to keep temps `< 75°C` (`7200 RPM` at `≥ 84°C`).
  - `Max` — Full blast at 7200 RPM.
  - `Manual` — Custom target RPM via slider (`1200–7200 RPM`), supporting up to 2 fans and both Pre-T2 (`fpe2`) and T2 (`flt `) SMC formats, resetting to Auto on quit.
- **Real-Time Sensor & Power Monitoring:**
  - Live CPU & GPU temperatures (°C), utilization (%), **real-time CPU frequency (`GHz`)** via `powermetrics` / `sysctl`, plus **CPU power (`W`)** and **system total power (`W`)** via SMC (`PCPC`/`PC0R`/`PSTR`/`PDTR`) with IOKit `AppleSmartBattery` fallback.
  - Configurable polling interval (`4–60s`).
- **Power, Low Power Mode & Battery Protection:**
  - **System Low Power Mode on Main Screen:** One-click toggle (shown only when supported by the current macOS/Mac) with scope selection in Settings (`Battery / Charger / Both`).
  - **Cold Sleep on Battery (in Settings):** Disables `Power Nap` and `tcpkeepalive` while on battery (`pmset -b`) to prevent background wakeups and overheating inside a bag (restores previous values when disabled; Find My will not update while lid is closed).
  - **Battery Charge Limit (`80–95%`, Intel Macs):** Stops charging at the chosen threshold without forced discharge (`BCLM` and `CH0B`/`CH0C` with 2% hysteresis), automatically resetting to `100%` when disabled, on quit, and on uninstall.
- **Turbo Boost Automation (in Settings):**
  - **Power Source Rules:** Independent actions on charger (`Enable / Keep`) and on battery (`Disable / Keep`), plus an option to allow Turbo on low battery when plugged in.
  - **CPU Temperature Rules:** Disable Turbo Boost when heating up (`85–100°C`) and re-enable on cooldown (mandatory ≥ 10°C hysteresis gap; Simple / Advanced down to `50°C`).
  - **Battery Level Rules:** Disable on low battery (`10–30%`) and re-enable when charged (mandatory ≥ 10% hysteresis gap; Simple / Advanced up to `80%`).
- **Processes Tab (formerly Top-5):**
  - Displays the top 5 user applications (filtering out macOS system daemons) sorted by `CPU %`, `GPU`, or `Energy`, with one-click Quit and per-app `⚡ Auto / Off / On` Turbo rules when active.
  - **Sleep Blockers Detector (`Sleep` mode):** Parses `pmset -g assertions` (no `sudo` needed) to list processes preventing display or system sleep (`Display / System / Background / Sleep`), assertion reason, and safe Quit for non-critical user apps.
- **History Charts Tab (optional in Settings):**
  - Controlled by a toggle and sampling interval slider (`30s – 5m`) in Settings; when disabled, the tab is hidden and background collection stops.
  - 4 native SwiftUI sparkline charts (up to 120 samples): **CPU Temp (`°C`)**, **CPU Frequency (`GHz`)**, **Fan Speed (`RPM`)**, and **System Power (`W`)** with current, min, and max readouts.
- **Modern UI, Passwordless Helper & Fullscreen Support:**
  - Translucent glass design, `Auto / Light / Dark` themes, `EN / RU` localization, Launch at Login, and a fullscreen-safe floating panel (`388×548`) that never gets clipped when the Menu Bar auto-hides.
  - Admin password is entered **only once** during installation (supports both Admin and Standard accounts); the app automatically checks `/Library/PrivilegedHelperTools/turbocontrol-helper` version on updates and prompts for a one-click update.

---

### 🚀 Easy Installation

Requirements: **Intel-based Mac**, **macOS 12.0 Monterey or newer**.

#### Option A: Install via Homebrew (Fastest)
```bash
brew install --cask vladsboev-web/tap/turbocontrol
```

#### Option B: Double-Click Installer (No Terminal Knowledge Required)
1. **Download the project:** Click the green **`<> Code`** button on GitHub → **`Download ZIP`**, then unzip the downloaded folder.
2. Open the `TurboControl` folder and **double-click** **`Install TurboControl.command`**.
   > 💡 *If macOS says the file cannot be opened because the developer is unidentified:* click **Done/OK**, then **Right-Click** (or `Control + Click`) on `Install TurboControl.command` and choose **Open** → **Open**.
3. A Terminal window will open, build the app, and ask for `Password:`.
   - **Type your Mac login password** and press `Enter`.
   - ⚠️ *Note: Nothing will appear on screen while you type your password (no stars or letters) — this is normal macOS security. Just type it and hit `Enter`.*
4. Done! **TurboControl** is now installed in `/Applications/TurboControl.app` and running in your top-right Menu Bar (⚡️ / 🍃 icon).

#### Option C: Build & Install from Source via Terminal
1. Open **Terminal** (`Cmd + Space` → type `Terminal` → `Enter`).
2. Run:
   ```bash
   git clone https://github.com/vladsboev-web/TurboControl.git ~/Downloads/TurboControl && cd ~/Downloads/TurboControl && ./install.sh
   ```
3. Enter your Mac password when prompted and press `Enter`.

---

### ⚠️ Note on macOS Kernel Extension (`.kext`) Approval
Disabling Intel Turbo Boost requires toggling the `MSR_IA32_MISC_ENABLE` CPU register via `DisableTurboBoost.kext`.
- If macOS shows a **"System Extension Blocked"** prompt the first time you disable Turbo Boost:
  1. Open **System Settings** → **Privacy & Security**.
  2. Scroll down to the Security section and click **Allow**.
  3. Restart your Mac if prompted — after that, Turbo Boost will toggle seamlessly in one click.

### 🛠 Manual Build, Deploy & Project Structure
```text
TurboControl/
├── Install TurboControl.command  # Double-click installer for beginners
├── install.sh                    # CLI build & installation script
├── uninstall.sh                  # Clean uninstaller (resets fan & charge limit)
├── Resources/                    # AppIcon.icns, Info.plist, DisableTurboBoost.kext
├── Scripts/                      # Build, deploy & privileged helper scripts (turbocontrol-helper, setup_helper.sh)
└── Sources/
    ├── AppDelegate.swift         # Status item, floating panel & lifecycle
    ├── Bridge/                   # IOKit AppleSMC C bridge (SMCBridge.c/.h, smc_common.h, smc_fan_writer.c)
    ├── Models/                   # AppSettings, L10n (RU/EN), SystemMetrics & chart history buffer
    ├── Services/                 # SMCReader, UsageReader, TurboBoostService, FanControlService, PowerManagementService, AutomationService, ProcessMonitorService, HelperClient
    └── Views/                    # SwiftUI views (MainPopoverView, MetricCardView, FanControlCardView, HeavyProcessesView, ChartsView, SettingsView)
```

To build `.app` bundle manually without installing:
```bash
./Scripts/build_app.sh
```

To rebuild, deploy to `/Applications/TurboControl.app`, and restart the app:
```bash
./Scripts/rebuild_and_deploy.sh
```

If `/Library/PrivilegedHelperTools/turbocontrol-helper` was updated (for example, after adding new helper commands like `cpu_freq`, `lowpowermode`, `cold_sleep`, `charge_limit`, or `charge_inhibit`), either click **Update** on the in-app banner or run once:
```bash
sudo /Applications/TurboControl.app/Contents/Resources/setup_helper.sh
```

### 🗑 Uninstall
Using the uninstall script from the project folder:
```bash
./uninstall.sh
```
If installed via Homebrew:
```bash
brew uninstall --cask turbocontrol
```
Or manually:
```bash
pkill -x TurboControl
sudo /Library/PrivilegedHelperTools/turbocontrol-fan auto 2>/dev/null || true
sudo /Library/PrivilegedHelperTools/turbocontrol-fan charge-inhibit 0 2>/dev/null || true
sudo /Library/PrivilegedHelperTools/turbocontrol-fan charge-limit 100 2>/dev/null || true
sudo /sbin/kextunload -b com.rugarciap.DisableTurboBoost 2>/dev/null || true
sudo rm -rf /Applications/TurboControl.app /Library/PrivilegedHelperTools/turbocontrol-helper /Library/PrivilegedHelperTools/turbocontrol-fan /usr/local/bin/turbocontrol-helper /usr/local/bin/turbocontrol-fan /etc/sudoers.d/turbocontrol /Library/Extensions/DisableTurboBoost.kext
```

---

### 📄 License

[MIT](LICENSE)
