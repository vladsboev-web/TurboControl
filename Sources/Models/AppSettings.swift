import Foundation
import Combine

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
        case .auto: return isEn ? "Default quiet Apple profile (heats up to 90°C)" : "Заводской тихий профиль Apple (нагрев до 90°C)"
        case .smart: return isEn ? "Early cooling from 55°C (keeps temp < 75°C)" : "Ранний обдув с 55°C (удерживает температуру < 75°C)"
        case .max: return isEn ? "Full blast at 7200 RPM" : "Полная продувка на 7200 RPM"
        case .manual: return isEn ? "Custom manual speed control" : "Ручное управление скоростью"
        }
    }
    
    // Settings View
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
    }
}

extension Notification.Name {
    static let updateIntervalChanged = Notification.Name("updateIntervalChanged")
    static let menuBarDisplayChanged = Notification.Name("menuBarDisplayChanged")
}
