import Foundation
import Cocoa
import Combine
import IOKit.ps

enum AutomationReason {
    case powerTransition
    case appChanged
    case metricsTick
}

enum AutomationDecision: Equatable {
    case noChange
    case disableTurbo
    case enableTurbo
}

struct AutomationInput {
    let reason: AutomationReason
    let isTurboDisabled: Bool
    let isPluggedIn: Bool
    let batteryPercentage: Int
    let cpuTemp: Double
    let frontmostAppRule: AppTurboRule?
    let onACPowerAction: PowerTurboAction
    let onBatteryPowerAction: PowerTurboAction
    let isPowerAutomationActive: Bool
    let allowTurboOnLowBatteryWhenPluggedIn: Bool
    let autoTempEnabled: Bool
    let autoTempDisableThreshold: Double
    let autoTempEnableThreshold: Double
    let autoBatteryEnabled: Bool
    let autoBatteryDisableThreshold: Double
    let autoBatteryEnableThreshold: Double
}

final class AutomationService: ObservableObject {
    static let shared = AutomationService()
    
    @Published private(set) var isPluggedIn: Bool = true
    @Published private(set) var batteryPercentage: Int = 100
    
    private var powerRunLoopSource: CFRunLoopSource?
    private var lastPluggedIn: Bool?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        guard SystemCapabilities.isIntelMac else { return }
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
    
    func evaluateRulesOnDemand() {
        evaluateRules(reason: .appChanged)
    }
    
    private func evaluateRules(reason: AutomationReason) {
        guard SystemCapabilities.isIntelMac else { return }
        let turbo = TurboBoostService.shared
        guard !turbo.isWorking else { return }
        
        let settings = AppSettings.shared
        var frontRule: AppTurboRule?
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            frontRule = settings.appTurboRules[frontApp.turboRuleKey]
        }
        
        let input = AutomationInput(
            reason: reason,
            isTurboDisabled: turbo.isTurboDisabled,
            isPluggedIn: isPluggedIn,
            batteryPercentage: batteryPercentage,
            cpuTemp: SystemMonitor.shared.cpuTemp,
            frontmostAppRule: frontRule,
            onACPowerAction: settings.onACPowerAction,
            onBatteryPowerAction: settings.onBatteryPowerAction,
            isPowerAutomationActive: settings.isPowerAutomationActive,
            allowTurboOnLowBatteryWhenPluggedIn: settings.allowTurboOnLowBatteryWhenPluggedIn,
            autoTempEnabled: settings.autoTempEnabled,
            autoTempDisableThreshold: settings.autoTempDisableThreshold,
            autoTempEnableThreshold: settings.autoTempEnableThreshold,
            autoBatteryEnabled: settings.autoBatteryEnabled,
            autoBatteryDisableThreshold: settings.autoBatteryDisableThreshold,
            autoBatteryEnableThreshold: settings.autoBatteryEnableThreshold
        )
        
        switch Self.decideTurboState(input: input) {
        case .disableTurbo:
            turbo.setTurboDisabled(true, isUserInitiated: false)
        case .enableTurbo:
            turbo.setTurboDisabled(false, isUserInitiated: false)
        case .noChange:
            break
        }
    }
    
    static func decideTurboState(input: AutomationInput) -> AutomationDecision {
        // 1. Active App Rule takes highest priority if configured
        if let rule = input.frontmostAppRule, rule != .auto {
            let shouldDisable = (rule == .disable)
            if input.isTurboDisabled != shouldDisable {
                return shouldDisable ? .disableTurbo : .enableTurbo
            }
            return .noChange
        }
        
        // 2. Power Transition Rules
        if input.reason == .powerTransition {
            if input.isPluggedIn {
                switch input.onACPowerAction {
                case .enable:
                    let blockedByLowBattery = input.autoBatteryEnabled
                        && Double(input.batteryPercentage) <= input.autoBatteryDisableThreshold
                        && !input.allowTurboOnLowBatteryWhenPluggedIn
                    let blockedByTemp = input.autoTempEnabled
                        && input.cpuTemp >= input.autoTempDisableThreshold
                    if !blockedByLowBattery && !blockedByTemp && input.isTurboDisabled {
                        return .enableTurbo
                    }
                    return .noChange
                case .disable:
                    return !input.isTurboDisabled ? .disableTurbo : .noChange
                case .keep:
                    break
                }
            } else {
                switch input.onBatteryPowerAction {
                case .disable:
                    return !input.isTurboDisabled ? .disableTurbo : .noChange
                case .enable:
                    let blockedByLowBattery = input.autoBatteryEnabled
                        && Double(input.batteryPercentage) <= input.autoBatteryDisableThreshold
                    let blockedByTemp = input.autoTempEnabled
                        && input.cpuTemp >= input.autoTempDisableThreshold
                    if !blockedByLowBattery && !blockedByTemp && input.isTurboDisabled {
                        return .enableTurbo
                    }
                    return .noChange
                case .keep:
                    break
                }
            }
        }
        
        // 3. Temperature Thresholds
        let temp = input.cpuTemp
        if input.autoTempEnabled && temp > 0 {
            if temp >= input.autoTempDisableThreshold && !input.isTurboDisabled {
                return .disableTurbo
            }
        }
        
        // 4. Battery Level Thresholds
        if input.autoBatteryEnabled {
            let lowBatteryBlocked = Double(input.batteryPercentage) <= input.autoBatteryDisableThreshold
                && !(input.isPluggedIn && input.isPowerAutomationActive && input.allowTurboOnLowBatteryWhenPluggedIn)
            if !input.isPluggedIn && lowBatteryBlocked && !input.isTurboDisabled {
                return .disableTurbo
            }
        }
        
        // 5. Re-enable conditions (hysteresis)
        if input.isTurboDisabled {
            let tempAllowsEnable = !input.autoTempEnabled || (temp > 0 && temp <= input.autoTempEnableThreshold)
            let battAllowsEnable = !input.autoBatteryEnabled || (
                input.isPluggedIn
                ? (Double(input.batteryPercentage) >= input.autoBatteryEnableThreshold || (input.isPowerAutomationActive && input.allowTurboOnLowBatteryWhenPluggedIn))
                : false
            )
            
            let wantsEnableFromTemp = input.autoTempEnabled && temp > 0 && temp <= input.autoTempEnableThreshold
            let wantsEnableFromBatt = input.autoBatteryEnabled && input.isPluggedIn && Double(input.batteryPercentage) >= input.autoBatteryEnableThreshold
            
            if (wantsEnableFromTemp || wantsEnableFromBatt) && tempAllowsEnable && battAllowsEnable {
                return .enableTurbo
            }
        }
        
        return .noChange
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
}

extension NSRunningApplication {
    var turboRuleKey: String {
        if let bundleId = bundleIdentifier, !bundleId.isEmpty {
            return bundleId
        }
        return localizedName ?? ""
    }
}
