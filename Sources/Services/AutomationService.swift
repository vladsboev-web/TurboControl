import Foundation
import Cocoa
import Combine
import IOKit.ps

final class AutomationService: ObservableObject {
    static let shared = AutomationService()
    
    @Published private(set) var isPluggedIn: Bool = true
    @Published private(set) var batteryPercentage: Int = 100
    
    private var powerRunLoopSource: CFRunLoopSource?
    private var lastPluggedIn: Bool?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        refreshPowerState(triggerTransition: false)
        setupPowerObserver()
        setupWorkspaceObserver()
        setupTemperatureObserver()
    }
    
    private func setupPowerObserver() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx = ctx else { return }
            let service = Unmanaged<AutomationService>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async {
                service.refreshPowerState(triggerTransition: true)
            }
        }, context)?.takeRetainedValue() {
            powerRunLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
    
    private func setupWorkspaceObserver() {
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.evaluateRules(reason: .appChanged)
            }
            .store(in: &cancellables)
    }
    
    private func setupTemperatureObserver() {
        NotificationCenter.default.publisher(for: .cpuTempDidUpdateForAutomation)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshPowerState(triggerTransition: false)
                self?.evaluateRules(reason: .metricsTick)
            }
            .store(in: &cancellables)
    }
    
    private enum EvaluationReason {
        case powerTransition
        case appChanged
        case metricsTick
    }
    
    private func refreshPowerState(triggerTransition: Bool) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }
        
        var plugged = true
        var pct = 100
        
        for ps in list {
            if let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] {
                if let type = desc[kIOPSTypeKey] as? String, type == kIOPSInternalBatteryType {
                    if let powerState = desc[kIOPSPowerSourceStateKey] as? String {
                        plugged = (powerState == kIOPSACPowerValue)
                    }
                    if let current = desc[kIOPSCurrentCapacityKey] as? Int,
                       let maxCap = desc[kIOPSMaxCapacityKey] as? Int, maxCap > 0 {
                        pct = Int(round((Double(current) / Double(maxCap)) * 100.0))
                    }
                    break
                }
            }
        }
        
        let previousPlugged = lastPluggedIn
        lastPluggedIn = plugged
        isPluggedIn = plugged
        batteryPercentage = pct
        
        if triggerTransition, let prev = previousPlugged, prev != plugged {
            evaluateRules(reason: .powerTransition)
        }
    }
    
    func evaluateRulesOnDemand() {
        evaluateRules(reason: .appChanged)
    }
    
    private func evaluateRules(reason: EvaluationReason) {
        let turbo = TurboBoostService.shared
        guard !turbo.isWorking else { return }
        
        let settings = AppSettings.shared
        
        // 1. Active App Rule takes highest priority if configured
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let appKey = ruleKey(for: frontApp)
            if let rule = settings.appTurboRules[appKey], rule != .auto {
                let shouldDisable = (rule == .disable)
                if turbo.isTurboDisabled != shouldDisable {
                    turbo.setTurboDisabled(shouldDisable, isUserInitiated: false)
                }
                return
            }
        }
        
        // 2. Power Transition Rules
        if reason == .powerTransition {
            if isPluggedIn {
                switch settings.onACPowerAction {
                case .enable:
                    let blockedByLowBattery = settings.autoBatteryEnabled
                        && Double(batteryPercentage) <= settings.autoBatteryDisableThreshold
                        && !settings.allowTurboOnLowBatteryWhenPluggedIn
                    let blockedByTemp = settings.autoTempEnabled
                        && SystemMonitor.shared.cpuTemp >= settings.autoTempDisableThreshold
                    if !blockedByLowBattery && !blockedByTemp && turbo.isTurboDisabled {
                        turbo.setTurboDisabled(false, isUserInitiated: false)
                    }
                    return
                case .disable:
                    if !turbo.isTurboDisabled {
                        turbo.setTurboDisabled(true, isUserInitiated: false)
                    }
                    return
                case .keep:
                    break
                }
            } else {
                switch settings.onBatteryPowerAction {
                case .disable:
                    if !turbo.isTurboDisabled {
                        turbo.setTurboDisabled(true, isUserInitiated: false)
                    }
                    return
                case .enable:
                    let blockedByLowBattery = settings.autoBatteryEnabled
                        && Double(batteryPercentage) <= settings.autoBatteryDisableThreshold
                    let blockedByTemp = settings.autoTempEnabled
                        && SystemMonitor.shared.cpuTemp >= settings.autoTempDisableThreshold
                    if !blockedByLowBattery && !blockedByTemp && turbo.isTurboDisabled {
                        turbo.setTurboDisabled(false, isUserInitiated: false)
                    }
                    return
                case .keep:
                    break
                }
            }
        }
        
        // 3. Temperature Thresholds
        let temp = SystemMonitor.shared.cpuTemp
        if settings.autoTempEnabled && temp > 0 {
            if temp >= settings.autoTempDisableThreshold && !turbo.isTurboDisabled {
                turbo.setTurboDisabled(true, isUserInitiated: false)
                return
            }
        }
        
        // 4. Battery Level Thresholds
        if settings.autoBatteryEnabled {
            let lowBatteryBlocked = Double(batteryPercentage) <= settings.autoBatteryDisableThreshold
                && !(isPluggedIn && settings.isPowerAutomationActive && settings.allowTurboOnLowBatteryWhenPluggedIn)
            if !isPluggedIn && lowBatteryBlocked && !turbo.isTurboDisabled {
                turbo.setTurboDisabled(true, isUserInitiated: false)
                return
            }
        }
        
        // 5. Re-enable conditions (hysteresis)
        if turbo.isTurboDisabled {
            let tempAllowsEnable = !settings.autoTempEnabled || (temp > 0 && temp <= settings.autoTempEnableThreshold)
            let battAllowsEnable = !settings.autoBatteryEnabled || (
                isPluggedIn
                ? (Double(batteryPercentage) >= settings.autoBatteryEnableThreshold || (settings.isPowerAutomationActive && settings.allowTurboOnLowBatteryWhenPluggedIn))
                : false
            )
            
            let wantsEnableFromTemp = settings.autoTempEnabled && temp > 0 && temp <= settings.autoTempEnableThreshold
            let wantsEnableFromBatt = settings.autoBatteryEnabled && isPluggedIn && Double(batteryPercentage) >= settings.autoBatteryEnableThreshold
            
            if (wantsEnableFromTemp || wantsEnableFromBatt) && tempAllowsEnable && battAllowsEnable {
                turbo.setTurboDisabled(false, isUserInitiated: false)
            }
        }
    }
    
    func ruleKey(for app: NSRunningApplication) -> String {
        if let bundleId = app.bundleIdentifier, !bundleId.isEmpty {
            return bundleId
        }
        return app.localizedName ?? ""
    }
    
    deinit {
        if let source = powerRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
}
