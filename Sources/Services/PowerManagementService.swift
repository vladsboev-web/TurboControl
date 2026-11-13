import Foundation
import Cocoa
import Combine

final class PowerManagementService: ObservableObject {
    static let shared = PowerManagementService()
    
    @Published private(set) var isLowPowerModeSupported: Bool = false
    @Published private(set) var isLowPowerModeEnabled: Bool = false
    @Published private(set) var isLowPowerEnabledForScope: Bool = false
    @Published var isTogglingLowPower: Bool = false
    
    @Published private(set) var isChargeLimitSupported: Bool = false
    @Published private(set) var isChargeInhibited: Bool = false
    @Published var statusMessage: String? = nil
    
    private let queue = DispatchQueue(label: "com.turbocontrol.powerMgmt", qos: .utility)
    private let usage = UsageReader.shared
    private let smc = SMCReader.shared
    private var cancellables = Set<AnyCancellable>()
    private var lastAppliedChargeLimit: Int?
    private var lastAppliedInhibit: Bool?
    
    private init() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        queue.async { [weak self] in
            guard let self = self else { return }
            let lpmSupported = self.usage.isLowPowerModeSupported()
            let chargeSupported = SystemCapabilities.isIntelMac && self.smc.supportsChargeLimit()
            let inhibited = self.smc.isChargeInhibited() ?? false
            let scopeState = self.queryScopeLowPowerState(scope: AppSettings.shared.lowPowerScope)
            
            DispatchQueue.main.async {
                self.isLowPowerModeSupported = lpmSupported
                self.isChargeLimitSupported = chargeSupported
                self.isChargeInhibited = inhibited
                self.isLowPowerEnabledForScope = scopeState
                self.applyStoredPowerPreferencesOnStartup()
            }
        }
        
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLowPowerState()
            }
            .store(in: &cancellables)
        
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self?.refreshLowPowerState()
                    self?.syncChargeLimit(forceReapply: true)
                }
            }
            .store(in: &cancellables)
        
        AppSettings.shared.$lowPowerScope
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLowPowerState()
            }
            .store(in: &cancellables)
        
        AppSettings.shared.$coldSleepOnBattery
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.applyColdSleep(enabled: enabled)
            }
            .store(in: &cancellables)
        
        AppSettings.shared.$chargeLimitEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                if enabled {
                    self?.syncChargeLimit(forceReapply: true)
                } else {
                    self?.resetChargeLimit()
                }
            }
            .store(in: &cancellables)
        
        AppSettings.shared.$chargeLimitPercentage
            .dropFirst()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard AppSettings.shared.chargeLimitEnabled else { return }
                self?.syncChargeLimit(forceReapply: true)
            }
            .store(in: &cancellables)
        
        AutomationService.shared.$batteryPercentage
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncChargeLimit(forceReapply: false)
            }
            .store(in: &cancellables)
        
        AutomationService.shared.$isPluggedIn
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLowPowerState()
                self?.syncChargeLimit(forceReapply: false)
            }
            .store(in: &cancellables)
    }
    
    private func applyStoredPowerPreferencesOnStartup() {
        if AppSettings.shared.coldSleepOnBattery {
            applyColdSleep(enabled: true)
        }
        if AppSettings.shared.chargeLimitEnabled {
            syncChargeLimit(forceReapply: true)
        }
    }
    
    func refreshLowPowerState() {
        let live = ProcessInfo.processInfo.isLowPowerModeEnabled
        isLowPowerModeEnabled = live
        let scope = AppSettings.shared.lowPowerScope
        queue.async { [weak self] in
            guard let self = self else { return }
            let scopeState = self.queryScopeLowPowerState(scope: scope)
            DispatchQueue.main.async {
                self.isLowPowerEnabledForScope = scopeState
                self.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }
    
    func setLowPowerMode(enabled: Bool, scope: LowPowerScope? = nil) {
        guard isLowPowerModeSupported, !isTogglingLowPower else { return }
        let targetScope = scope ?? AppSettings.shared.lowPowerScope
        isTogglingLowPower = true
        statusMessage = nil
        
        queue.async { [weak self] in
            guard let self = self else { return }
            let result = HelperClient.run(["lowpowermode", targetScope.rawValue, enabled ? "1" : "0"], timeout: 8.0)
            let updatedScopeState = self.queryScopeLowPowerState(scope: targetScope)
            
            DispatchQueue.main.async {
                self.isTogglingLowPower = false
                self.isLowPowerEnabledForScope = result.succeeded ? enabled : updatedScopeState
                self.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                if !result.succeeded {
                    self.statusMessage = L10n.errToggleFailed
                }
            }
        }
    }
    
    func applyColdSleep(enabled: Bool) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if enabled {
                let current = self.readBatterySleepSettings()
                DispatchQueue.main.async {
                    if AppSettings.shared.savedBatteryPowerNap == nil {
                        AppSettings.shared.savedBatteryPowerNap = current.powernap ?? 1
                    }
                    if AppSettings.shared.savedBatteryTcpKeepAlive == nil {
                        AppSettings.shared.savedBatteryTcpKeepAlive = current.tcpkeepalive ?? 1
                    }
                }
                _ = HelperClient.run(["cold_sleep", "0", "0"], timeout: 8.0)
            } else {
                let nap = AppSettings.shared.savedBatteryPowerNap ?? 1
                let tcp = AppSettings.shared.savedBatteryTcpKeepAlive ?? 1
                let result = HelperClient.run(["cold_sleep", "\(nap)", "\(tcp)"], timeout: 8.0)
                if result.succeeded {
                    DispatchQueue.main.async {
                        AppSettings.shared.savedBatteryPowerNap = nil
                        AppSettings.shared.savedBatteryTcpKeepAlive = nil
                    }
                }
            }
        }
    }
    
    func syncChargeLimit(forceReapply: Bool) {
        guard SystemCapabilities.isIntelMac, isChargeLimitSupported, AppSettings.shared.chargeLimitEnabled else { return }
        let limit = AppSettings.shared.chargeLimitPercentage
        let pct = AutomationService.shared.batteryPercentage
        let plugged = AutomationService.shared.isPluggedIn
        
        queue.async { [weak self] in
            guard let self = self else { return }
            if forceReapply || self.lastAppliedChargeLimit != limit {
                let res = HelperClient.run(["charge_limit", "\(limit)"], timeout: 8.0)
                if res.succeeded {
                    self.lastAppliedChargeLimit = limit
                }
            }
            
            var desiredInhibit = self.lastAppliedInhibit ?? (self.smc.isChargeInhibited() ?? false)
            if plugged {
                if pct >= limit {
                    desiredInhibit = true
                } else if pct <= max(0, limit - 2) {
                    desiredInhibit = false
                }
            } else {
                desiredInhibit = false
            }
            
            if forceReapply || self.lastAppliedInhibit != desiredInhibit {
                let res = HelperClient.run(["charge_inhibit", desiredInhibit ? "1" : "0"], timeout: 8.0)
                if res.succeeded {
                    self.lastAppliedInhibit = desiredInhibit
                    DispatchQueue.main.async {
                        self.isChargeInhibited = desiredInhibit
                    }
                }
            }
        }
    }
    
    func resetChargeLimit(waitUntilDone: Bool = false) {
        guard SystemCapabilities.isIntelMac else { return }
        let work = { [weak self] in
            guard let self = self else { return }
            _ = HelperClient.run(["charge_inhibit", "0"], timeout: 6.0)
            _ = HelperClient.run(["charge_limit", "100"], timeout: 6.0)
            self.lastAppliedChargeLimit = nil
            self.lastAppliedInhibit = false
            if !waitUntilDone {
                DispatchQueue.main.async {
                    self.isChargeInhibited = false
                }
            }
        }
        if waitUntilDone {
            queue.sync(execute: work)
        } else {
            queue.async(execute: work)
        }
    }
    
    private func readPmsetCustomOutput() -> String? {
        let result = ProcessRunner.run("/usr/bin/pmset", arguments: ["-g", "custom"], timeout: 5.0)
        return result.stdout.isEmpty ? nil : result.stdout
    }
    
    private func parsePmsetSections() -> (battery: [String: Int], ac: [String: Int]) {
        guard let output = readPmsetCustomOutput() else { return ([:], [:]) }
        var battery: [String: Int] = [:]
        var ac: [String: Int] = [:]
        var section = ""
        
        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("Battery Power:") {
                section = "battery"
                continue
            } else if line.hasPrefix("AC Power:") {
                section = "ac"
                continue
            }
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if parts.count >= 2, let val = Int(parts[1]) {
                let key = String(parts[0])
                if section == "battery" { battery[key] = val }
                else if section == "ac" { ac[key] = val }
            }
        }
        return (battery, ac)
    }
    
    private func queryScopeLowPowerState(scope: LowPowerScope) -> Bool {
        let sections = parsePmsetSections()
        switch scope {
        case .battery:
            return (sections.battery["lowpowermode"] ?? 0) == 1
        case .ac:
            return (sections.ac["lowpowermode"] ?? 0) == 1
        case .both:
            let b = (sections.battery["lowpowermode"] ?? 0) == 1
            let a = (sections.ac["lowpowermode"] ?? 0) == 1
            return b && a
        }
    }
    
    private func readBatterySleepSettings() -> (powernap: Int?, tcpkeepalive: Int?) {
        let sections = parsePmsetSections()
        return (sections.battery["powernap"], sections.battery["tcpkeepalive"])
    }
}
