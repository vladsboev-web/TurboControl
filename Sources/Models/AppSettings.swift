import Foundation
import Combine
import SwiftUI
import Darwin

enum SystemCapabilities {
    static let isIntelMac: Bool = {
        #if arch(arm64)
        return false
        #else
        var arm64: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.optional.arm64", &arm64, &size, nil, 0) == 0, arm64 == 1 {
            return false
        }
        var translated: Int32 = 0
        size = MemoryLayout<Int32>.size
        if sysctlbyname("sysctl.proc_translated", &translated, &size, nil, 0) == 0, translated == 1 {
            return false
        }
        return true
        #endif
    }()
}

enum AppTheme: String, CaseIterable {
    case auto = "auto"
    case light = "light"
    case dark = "dark"
    
    var iconName: String {
        switch self {
        case .auto: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    var next: AppTheme {
        switch self {
        case .auto: return .light
        case .light: return .dark
        case .dark: return .auto
        }
    }
}

enum PowerTurboAction: String, CaseIterable {
    case keep = "keep"
    case enable = "enable"
    case disable = "disable"
}

enum AppTurboRule: String, Codable, CaseIterable {
    case auto = "auto"
    case disable = "disable"
    case enable = "enable"
    
    var next: AppTurboRule {
        switch self {
        case .auto: return .disable
        case .disable: return .enable
        case .enable: return .auto
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case ru = "ru"
    case en = "en"
    
    var displayName: String {
        switch self {
        case .ru: return "Русский"
        case .en: return "English"
        }
    }
    
    var shortBadge: String {
        switch self {
        case .ru: return "RU"
        case .en: return "EN"
        }
    }
}

enum L10n {
    private static var isEn: Bool {
        AppSettings.shared.language == .en
    }
    
    // Header & Footer
    static var settingsTooltip: String { isEn ? "Settings" : "Настройки" }
    static var settingsTitle: String { isEn ? "Settings" : "Настройки" }
    static var quit: String { isEn ? "Quit" : "Выход" }
    static func pollingEvery(_ sec: Double) -> String {
        isEn ? String(format: "Polling every %.0fs", sec) : String(format: "Опрос каждые %.0fc", sec)
    }
    
    // Turbo Boost Widget & Menu
    static var turboDisabledBadge: String { isEn ? "DISABLED" : "ОТКЛЮЧЕН" }
    static var turboEnabledBadge: String { isEn ? "ENABLED" : "ВКЛЮЧЕН" }
    static var turboDisabledSubtitle: String { isEn ? "Cool mode (Battery saving)" : "Холодный режим (Экономия батареи)" }
    static var turboEnabledSubtitle: String { isEn ? "Max frequency (High heat)" : "Максимальная частота (Нагрев)" }
    static var menuTurboStatusDisabled: String { isEn ? "Turbo Boost: Disabled (Cool Mode)" : "Turbo Boost: Отключен (Холодный режим)" }
    static var menuTurboStatusEnabled: String { isEn ? "Turbo Boost: Enabled (Max Freq)" : "Turbo Boost: Включен (Макс. частота)" }
    static var menuEnableTurbo: String { isEn ? "Enable Turbo Boost" : "Включить Turbo Boost" }
    static var menuDisableTurbo: String { isEn ? "Disable Turbo Boost" : "Отключить Turbo Boost" }
    static var errHelperSetupRequired: String { isEn ? "Admin permissions required for setup" : "Требуются права для разовой настройки" }
    static var errSudoersRequired: String { isEn ? "Sudoers setup required" : "Требуется настройка прав sudoers" }
    static var errToggleFailed: String { isEn ? "Failed to switch mode" : "Ошибка переключения" }
    static var errKextApprovalRequired: String { isEn ? "Allow kext in Settings → Privacy & Security" : "Разрешите драйвер в Настройках → Защита" }
    static var errKextRebootRequired: String { isEn ? "Reboot Mac to finish kext activation" : "Перезагрузите Mac для активации драйвера" }
    
    // Metric Cards
    static var cpuTitle: String { isEn ? "Processor (CPU)" : "Процессор (CPU)" }
    static var cpuLoadTitle: String { isEn ? "CPU Load:" : "Нагрузка CPU:" }
    static var gpuTitle: String { isEn ? "Graphics (GPU)" : "Видеочип (GPU)" }
    static var gpuLoadTitle: String { isEn ? "GPU Load:" : "Нагрузка GPU:" }
    static var defaultLoadTitle: String { isEn ? "Load:" : "Нагрузка:" }
    
    // Fan Control Card
    static var fanTitle: String { isEn ? "Cooling Fan" : "Вентилятор (Кулер)" }
    static var fanZeroQuiet: String { isEn ? "0 RPM (Silent)" : "0 RPM (Тихо)" }
    static var fanManualTarget: String { isEn ? "Manual speed:" : "Обороты вручную:" }
    static func fanModeTitle(_ mode: FanMode) -> String {
        switch mode {
        case .auto: return isEn ? "Auto (Apple)" : "Авто (Apple)"
        case .smart: return isEn ? "Smart (Early)" : "Умный (Ранний)"
        case .max: return isEn ? "Max" : "Макс"
        case .manual: return isEn ? "Manual" : "Ручной"
        }
    }
    static func fanModeDesc(_ mode: FanMode) -> String {
        switch mode {
        case .auto: return isEn ? "Quiet Apple profile (up to 90°C)" : "Тихий профиль Apple (до 90°C)"
        case .smart: return isEn ? "Early cooling from 55°C (< 75°C)" : "Ранний обдув с 55°C (держит < 75°C)"
        case .max: return isEn ? "Full blast at 7200 RPM" : "Полная продувка на 7200 RPM"
        case .manual: return isEn ? "Custom manual speed control" : "Ручное управление скоростью"
        }
    }
    
    // Settings View
    static var themeLabel: String { isEn ? "Appearance:" : "Тема:" }
    static func themeTitle(_ theme: AppTheme) -> String {
        switch theme {
        case .auto: return isEn ? "Auto" : "Авто"
        case .light: return isEn ? "Light" : "Светлая"
        case .dark: return isEn ? "Dark" : "Тёмная"
        }
    }
    static var themeTooltip: String { isEn ? "Switch theme (Auto / Light / Dark)" : "Сменить тему (Авто / Светлая / Тёмная)" }
    static var languageLabel: String { isEn ? "Interface language:" : "Язык интерфейса:" }
    static var updateFreqLabel: String { isEn ? "Refresh interval:" : "Частота обновления:" }
    static func secondsBadge(_ sec: Double) -> String {
        isEn ? String(format: "%.0f sec", sec) : String(format: "%.0f сек", sec)
    }
    static var minSecLabel: String { isEn ? "4s" : "4с" }
    static var maxSecLabel: String { isEn ? "60s" : "60с" }
    
    static var autoLaunchTitle: String { isEn ? "Launch at macOS login" : "Автозапуск при старте macOS" }
    static var autoLaunchSub: String { isEn ? "Start utility in background when logging in" : "Запускать утилиту в фоне при входе в систему" }
    
    static var restoreTurboTitle: String { isEn ? "Remember Turbo Boost state" : "Запоминать режим Turbo Boost" }
    static var restoreTurboSub: String { isEn ? "Restore your choice (ON / OFF) after sleep & reboot" : "Сохранять ваш выбор (ВКЛ / ВЫКЛ) после сна и ребута" }
    
    static var showTempTitle: String { isEn ? "Show temperature in Menu Bar" : "Температура в строке меню" }
    static var showTempSub: String { isEn ? "Display CPU °C next to the menu bar icon" : "Показывать °C рядом со значком на панели" }
    
    // Automation Settings
    static var automationSectionTitle: String { isEn ? "Turbo Boost Automation" : "Автоматизация Turbo Boost" }
    static var powerRuleTitle: String { isEn ? "Power source" : "По питанию" }
    static var onACLabel: String { isEn ? "On charger:" : "При зарядке:" }
    static var onBatteryLabel: String { isEn ? "On battery:" : "От аккумулятора:" }
    static func powerActionTitle(_ action: PowerTurboAction) -> String {
        switch action {
        case .keep: return isEn ? "Keep" : "Не менять"
        case .enable: return isEn ? "Enable" : "Включать"
        case .disable: return isEn ? "Disable" : "Выключать"
        }
    }
    static var allowTurboLowBattAC: String {
        isEn ? "Enable on low battery when plugged in" : "Вкл. на низком заряде при зарядке"
    }
    static var tempRuleTitle: String { isEn ? "By CPU temperature" : "По температуре CPU" }
    static var batteryRuleTitle: String { isEn ? "By battery level" : "По уровню заряда" }
    static var advancedSettingsBtn: String { isEn ? "Advanced" : "Расширенная настройка" }
    static var simpleSettingsBtn: String { isEn ? "Simple" : "Обычная" }
    static func tempDisableAt(_ t: Double) -> String {
        isEn ? String(format: "Disable ≥ %.0f°C", t) : String(format: "Выкл ≥ %.0f°C", t)
    }
    static func tempEnableAt(_ t: Double) -> String {
        isEn ? String(format: "Enable ≤ %.0f°C", t) : String(format: "Вкл ≤ %.0f°C", t)
    }
    static func battDisableAt(_ p: Double) -> String {
        isEn ? String(format: "Disable ≤ %.0f%%", p) : String(format: "Выкл ≤ %.0f%%", p)
    }
    static func battEnableAt(_ p: Double) -> String {
        isEn ? String(format: "Enable ≥ %.0f%%", p) : String(format: "Вкл ≥ %.0f%%", p)
    }
    static var minGap10Deg: String { isEn ? "Min 10°C gap" : "Зазор мин. 10°C" }
    static var minGap10Pct: String { isEn ? "Min 10% gap" : "Зазор мин. 10%" }
    
    // Heavy Processes Window
    static var top5BtnTitle: String { isEn ? "Top-5" : "Топ-5" }
    static var top5Tooltip: String { isEn ? "Who's heating the Mac? (Top 5 processes)" : "Кто греет Mac? (Топ-5 процессов)" }
    static var heavyProcessesTitle: String { isEn ? "Who's heating Mac?" : "Кто греет Mac?" }
    static var sortCPU: String { "CPU %" }
    static var sortGPU: String { "GPU" }
    static var sortEnergy: String { isEn ? "Energy" : "Энергия" }
    static var noHeavyProcesses: String { isEn ? "No active user processes" : "Нет активных процессов" }
    static var killProcessTooltip: String { isEn ? "Quit process" : "Завершить процесс" }
    static var turboRuleTooltip: String { isEn ? "Click to change Turbo Boost rule when active" : "Нажми для смены правила Turbo при активности" }
    static func appRuleBadge(_ rule: AppTurboRule) -> String {
        switch rule {
        case .auto: return isEn ? "Auto" : "Авто"
        case .disable: return isEn ? "Off" : "Выкл"
        case .enable: return isEn ? "On" : "Вкл"
        }
    }
    static var heavyProcessesHint: String {
        isEn ? "⚡ applies Turbo rule when app is active" : "⚡ применяет правило Turbo, пока окно активно"
    }
    
    // Helper Update Banner
    static var helperOutdatedTitle: String { isEn ? "System helper update required" : "Требуется обновить системный хелпер" }
    static var helperUpdateBtn: String { isEn ? "Update" : "Обновить" }
    
    // Apple Silicon Monitor-Only Alert
    static var appleSiliconAlertTitle: String {
        isEn ? "Apple Silicon Mac Detected" : "Обнаружен Mac на Apple Silicon"
    }
    static var appleSiliconAlertMessage: String {
        isEn
        ? "Intel Turbo Boost control is only supported on Intel-based Macs. You can continue in Monitor Only mode (Turbo Boost controls will be hidden)."
        : "Управление Intel Turbo Boost поддерживается только на Mac с процессорами Intel. Вы можете продолжить в режиме «Только мониторинг» (элементы управления Turbo Boost будут скрыты)."
    }
    static var continueMonitorOnlyBtn: String {
        isEn ? "Continue (Monitor Only)" : "Продолжить (только мониторинг)"
    }
    static var menuMonitorOnlyStatus: String {
        isEn ? "Monitor Only (Apple Silicon)" : "Только мониторинг (Apple Silicon)"
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    enum Keys {
        static let updateInterval = "updateInterval"
        static let autoLaunchAtLogin = "autoLaunchAtLogin"
        static let restoreLastTurboState = "restoreLastTurboState"
        static let showTempInMenuBar = "showTempInMenuBar"
        static let userChosenTurboDisabled = "userChosenTurboDisabled"
        static let language = "appLanguage"
        static let theme = "appTheme"
        static let onACPowerAction = "onACPowerAction"
        static let onBatteryPowerAction = "onBatteryPowerAction"
        static let allowTurboOnLowBatteryWhenPluggedIn = "allowTurboOnLowBatteryWhenPluggedIn"
        static let autoTempEnabled = "autoTempEnabled"
        static let autoTempDisableThreshold = "autoTempDisableThreshold"
        static let autoTempEnableThreshold = "autoTempEnableThreshold"
        static let autoTempAdvanced = "autoTempAdvanced"
        static let autoBatteryEnabled = "autoBatteryEnabled"
        static let autoBatteryDisableThreshold = "autoBatteryDisableThreshold"
        static let autoBatteryEnableThreshold = "autoBatteryEnableThreshold"
        static let autoBatteryAdvanced = "autoBatteryAdvanced"
        static let appTurboRules = "appTurboRules"
    }
    
    @Published var onACPowerAction: PowerTurboAction {
        didSet { defaults.set(onACPowerAction.rawValue, forKey: Keys.onACPowerAction) }
    }
    @Published var onBatteryPowerAction: PowerTurboAction {
        didSet { defaults.set(onBatteryPowerAction.rawValue, forKey: Keys.onBatteryPowerAction) }
    }
    @Published var allowTurboOnLowBatteryWhenPluggedIn: Bool {
        didSet { defaults.set(allowTurboOnLowBatteryWhenPluggedIn, forKey: Keys.allowTurboOnLowBatteryWhenPluggedIn) }
    }
    
    @Published var autoTempEnabled: Bool {
        didSet { defaults.set(autoTempEnabled, forKey: Keys.autoTempEnabled) }
    }
    @Published var autoTempDisableThreshold: Double {
        didSet {
            let clamped = max(85.0, min(100.0, autoTempDisableThreshold))
            if clamped != autoTempDisableThreshold {
                autoTempDisableThreshold = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.autoTempDisableThreshold)
            if !autoTempAdvanced {
                autoTempEnableThreshold = clamped - 10.0
            } else if autoTempEnableThreshold > clamped - 10.0 {
                autoTempEnableThreshold = clamped - 10.0
            }
        }
    }
    @Published var autoTempEnableThreshold: Double {
        didSet {
            let maxAllowed = autoTempDisableThreshold - 10.0
            let clamped = max(50.0, min(maxAllowed, autoTempEnableThreshold))
            if clamped != autoTempEnableThreshold {
                autoTempEnableThreshold = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.autoTempEnableThreshold)
        }
    }
    @Published var autoTempAdvanced: Bool {
        didSet {
            defaults.set(autoTempAdvanced, forKey: Keys.autoTempAdvanced)
            if !autoTempAdvanced {
                autoTempEnableThreshold = autoTempDisableThreshold - 10.0
            }
        }
    }
    
    @Published var autoBatteryEnabled: Bool {
        didSet { defaults.set(autoBatteryEnabled, forKey: Keys.autoBatteryEnabled) }
    }
    @Published var autoBatteryDisableThreshold: Double {
        didSet {
            let clamped = max(10.0, min(30.0, autoBatteryDisableThreshold))
            if clamped != autoBatteryDisableThreshold {
                autoBatteryDisableThreshold = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.autoBatteryDisableThreshold)
            if !autoBatteryAdvanced {
                autoBatteryEnableThreshold = clamped + 10.0
            } else if autoBatteryEnableThreshold < clamped + 10.0 {
                autoBatteryEnableThreshold = clamped + 10.0
            }
        }
    }
    @Published var autoBatteryEnableThreshold: Double {
        didSet {
            let minAllowed = autoBatteryDisableThreshold + 10.0
            let clamped = max(minAllowed, min(80.0, autoBatteryEnableThreshold))
            if clamped != autoBatteryEnableThreshold {
                autoBatteryEnableThreshold = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.autoBatteryEnableThreshold)
        }
    }
    @Published var autoBatteryAdvanced: Bool {
        didSet {
            defaults.set(autoBatteryAdvanced, forKey: Keys.autoBatteryAdvanced)
            if !autoBatteryAdvanced {
                autoBatteryEnableThreshold = autoBatteryDisableThreshold + 10.0
            }
        }
    }
    
    @Published var appTurboRules: [String: AppTurboRule] {
        didSet {
            if let data = try? JSONEncoder().encode(appTurboRules) {
                defaults.set(data, forKey: Keys.appTurboRules)
            }
        }
    }
    
    var isPowerAutomationActive: Bool {
        onACPowerAction != .keep || onBatteryPowerAction != .keep
    }
    
    @Published var theme: AppTheme {
        didSet {
            defaults.set(theme.rawValue, forKey: Keys.theme)
            NotificationCenter.default.post(name: .appThemeChanged, object: nil)
        }
    }
    
    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            NotificationCenter.default.post(name: .menuBarDisplayChanged, object: nil)
        }
    }
    
    @Published var updateInterval: Double {
        didSet {
            defaults.set(updateInterval, forKey: Keys.updateInterval)
            NotificationCenter.default.post(name: .updateIntervalChanged, object: nil)
        }
    }
    
    @Published var autoLaunchAtLogin: Bool {
        didSet {
            defaults.set(autoLaunchAtLogin, forKey: Keys.autoLaunchAtLogin)
            LaunchAtLogin.setLaunchAtLogin(enabled: autoLaunchAtLogin)
        }
    }
    
    @Published var restoreLastTurboState: Bool {
        didSet {
            defaults.set(restoreLastTurboState, forKey: Keys.restoreLastTurboState)
        }
    }
    
    @Published var showTempInMenuBar: Bool {
        didSet {
            defaults.set(showTempInMenuBar, forKey: Keys.showTempInMenuBar)
            NotificationCenter.default.post(name: .menuBarDisplayChanged, object: nil)
        }
    }
    
    var userChosenTurboDisabled: Bool {
        get {
            defaults.bool(forKey: Keys.userChosenTurboDisabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.userChosenTurboDisabled)
        }
    }
    
    private init() {
        if let savedTheme = defaults.string(forKey: Keys.theme),
           let parsedTheme = AppTheme(rawValue: savedTheme) {
            self.theme = parsedTheme
        } else {
            self.theme = .auto
        }
        
        if let savedLang = defaults.string(forKey: Keys.language),
           let lang = AppLanguage(rawValue: savedLang) {
            self.language = lang
        } else {
            self.language = .ru
        }
        
        let savedInterval = defaults.double(forKey: Keys.updateInterval)
        self.updateInterval = savedInterval >= 4.0 ? savedInterval : 5.0
        
        if defaults.object(forKey: Keys.autoLaunchAtLogin) != nil {
            self.autoLaunchAtLogin = defaults.bool(forKey: Keys.autoLaunchAtLogin)
        } else {
            self.autoLaunchAtLogin = true
        }
        
        if defaults.object(forKey: Keys.restoreLastTurboState) != nil {
            self.restoreLastTurboState = defaults.bool(forKey: Keys.restoreLastTurboState)
        } else {
            self.restoreLastTurboState = true
        }
        
        if defaults.object(forKey: Keys.showTempInMenuBar) != nil {
            self.showTempInMenuBar = defaults.bool(forKey: Keys.showTempInMenuBar)
        } else {
            self.showTempInMenuBar = true
        }
        
        if let acRaw = defaults.string(forKey: Keys.onACPowerAction),
           let ac = PowerTurboAction(rawValue: acRaw) {
            self.onACPowerAction = ac
        } else {
            self.onACPowerAction = .keep
        }
        
        if let battRaw = defaults.string(forKey: Keys.onBatteryPowerAction),
           let batt = PowerTurboAction(rawValue: battRaw) {
            self.onBatteryPowerAction = batt
        } else {
            self.onBatteryPowerAction = .keep
        }
        
        self.allowTurboOnLowBatteryWhenPluggedIn = defaults.bool(forKey: Keys.allowTurboOnLowBatteryWhenPluggedIn)
        self.autoTempEnabled = defaults.bool(forKey: Keys.autoTempEnabled)
        let savedTempDisable = defaults.double(forKey: Keys.autoTempDisableThreshold)
        let initTempDisable = (savedTempDisable >= 85.0 && savedTempDisable <= 100.0) ? savedTempDisable : 90.0
        self.autoTempDisableThreshold = initTempDisable
        let savedTempEnable = defaults.double(forKey: Keys.autoTempEnableThreshold)
        let initTempEnable = (savedTempEnable >= 50.0 && savedTempEnable <= initTempDisable - 10.0) ? savedTempEnable : (initTempDisable - 10.0)
        self.autoTempEnableThreshold = initTempEnable
        self.autoTempAdvanced = defaults.bool(forKey: Keys.autoTempAdvanced)
        
        self.autoBatteryEnabled = defaults.bool(forKey: Keys.autoBatteryEnabled)
        let savedBattDisable = defaults.double(forKey: Keys.autoBatteryDisableThreshold)
        let initBattDisable = (savedBattDisable >= 10.0 && savedBattDisable <= 30.0) ? savedBattDisable : 20.0
        self.autoBatteryDisableThreshold = initBattDisable
        let savedBattEnable = defaults.double(forKey: Keys.autoBatteryEnableThreshold)
        let initBattEnable = (savedBattEnable >= initBattDisable + 10.0 && savedBattEnable <= 80.0) ? savedBattEnable : (initBattDisable + 10.0)
        self.autoBatteryEnableThreshold = initBattEnable
        self.autoBatteryAdvanced = defaults.bool(forKey: Keys.autoBatteryAdvanced)
        
        if let data = defaults.data(forKey: Keys.appTurboRules),
           let decoded = try? JSONDecoder().decode([String: AppTurboRule].self, from: data) {
            self.appTurboRules = decoded
        } else {
            self.appTurboRules = [:]
        }
    }
}

extension Notification.Name {
    static let updateIntervalChanged = Notification.Name("updateIntervalChanged")
    static let menuBarDisplayChanged = Notification.Name("menuBarDisplayChanged")
    static let appThemeChanged = Notification.Name("appThemeChanged")
}
