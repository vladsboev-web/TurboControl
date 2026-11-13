import Foundation
import Combine
import AppKit

enum FanMode: String, CaseIterable {
    case auto = "auto"       // macOS Apple Default
    case smart = "smart"     // Smart Early Cooling
    case max = "max"         // Max 7200 RPM
    case manual = "manual"   // Manual custom RPM
    
    var title: String {
        L10n.fanModeTitle(self)
    }
    
    var icon: String {
        switch self {
        case .auto: return "gearshape.2"
        case .smart: return "bolt.shield.fill"
        case .max: return "flame.fill"
        case .manual: return "slider.horizontal.3"
        }
    }
}

final class FanControlService: ObservableObject {
    static let shared = FanControlService()
    
    @Published var currentMode: FanMode = .smart {
        didSet {
            UserDefaults.standard.set(currentMode.rawValue, forKey: "fanMode")
            applyCurrentMode()
        }
    }
    
    @Published var targetManualRPM: Double = 3500 {
        didSet {
            UserDefaults.standard.set(targetManualRPM, forKey: "targetManualRPM")
        }
    }
    
    private let fanQueue = DispatchQueue(label: "com.turbocontrol.fanQueue", qos: .userInitiated)
    private var lastAppliedRPM: Int = -1
    private var smoothedTemp: Double = 0.0
    private var smartIdleAutoActive: Bool = false
    private var lastFailureTime: Date = .distantPast
    private var isCommandInFlight: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    private var minFanRPM: Int {
        max(800, Int(SystemMonitor.shared.fanMinRPM))
    }
    
    private var maxFanRPM: Int {
        max(minFanRPM, Int(SystemMonitor.shared.fanMaxRPM))
    }
    
    private init() {
        if let savedMode = UserDefaults.standard.string(forKey: "fanMode"),
           let mode = FanMode(rawValue: savedMode) {
            self.currentMode = mode
        } else {
            self.currentMode = .smart
        }
        
        let savedRPM = UserDefaults.standard.double(forKey: "targetManualRPM")
        self.targetManualRPM = savedRPM >= 1200 ? savedRPM : 3500
        
        // Listen to sensor updates for Smart Curve and mode enforcement
        NotificationCenter.default.publisher(for: .metricsDidUpdate)
            .sink { [weak self] _ in
                self?.handleMetricsUpdate()
            }
            .store(in: &cancellables)
        
        // Debounce manual slider changes to avoid spamming sudo processes while dragging
        $targetManualRPM
            .dropFirst()
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] rpm in
                guard let self = self, self.currentMode == .manual else { return }
                self.setFanManual(rpm: Int(rpm))
            }
            .store(in: &cancellables)
        
        // Re-apply mode after system wake (macOS resets SMC fan control to Auto)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.applyCurrentMode()
                }
            }
            .store(in: &cancellables)
    }
    
    func resetToAppleAuto() {
        setFanAuto(waitUntilDone: true)
    }
    
    private func handleMetricsUpdate() {
        guard !isCommandInFlight, Date().timeIntervalSince(lastFailureTime) >= 10.0 else { return }
        let smcManual = SystemMonitor.shared.isFanManualMode
        
        switch currentMode {
        case .auto:
            // Enforce Auto only until first confirmed Auto state; afterwards do not fight third-party fan tools
            if !smcManual {
                lastAppliedRPM = 0
            } else if lastAppliedRPM != 0 {
                setFanAuto(waitUntilDone: false)
            }
            return
            
        case .max:
            // If macOS reset SMC to Auto after sleep, re-apply Max
            let maxRPM = maxFanRPM
            if !smcManual || lastAppliedRPM != maxRPM {
                setFanManual(rpm: maxRPM)
            }
            return
            
        case .manual:
            let target = Int(targetManualRPM)
            if !smcManual || abs(lastAppliedRPM - target) >= 50 {
                setFanManual(rpm: target)
            }
            return
            
        case .smart:
            break
        }
        
        let cpuTemp = SystemMonitor.shared.cpuTemp
        let gpuTemp = SystemMonitor.shared.gpuTemp
        let rawTemp = max(cpuTemp, gpuTemp)
        guard rawTemp > 0 else { return }
        
        // Asymmetric smoothing: react faster to heating up (0.55), cool down gradually (0.20)
        // so the fan keeps spinning while the heatsink is still warm (preventing Auto > Smart inversion)
        if smoothedTemp <= 0.0 {
            smoothedTemp = rawTemp
        } else if rawTemp > smoothedTemp {
            smoothedTemp = smoothedTemp * 0.45 + rawTemp * 0.55
        } else {
            smoothedTemp = smoothedTemp * 0.80 + rawTemp * 0.20
        }
        
        // Below 52°C (or up to 55°C while already quiet): release to Apple Auto so fan can stay at 0 RPM (Silent)
        if smartIdleAutoActive {
            if smoothedTemp < 55.0 && rawTemp < 58.0 {
                if smcManual {
                    setFanAuto(waitUntilDone: false)
                }
                return
            } else {
                smartIdleAutoActive = false
            }
        } else if smoothedTemp < 52.0 && rawTemp < 54.0 {
            smartIdleAutoActive = true
            setFanAuto(waitUntilDone: false)
            return
        }
        
        var targetRPM = Self.calculateSmartRPM(temp: smoothedTemp)
        
        // Never spin down abruptly while cooling down: cap RPM drop to at most 350 RPM per poll cycle
        if lastAppliedRPM > 0 && targetRPM < lastAppliedRPM {
            targetRPM = max(targetRPM, lastAppliedRPM - 350)
        }
        
        // Update if SMC lost manual state (e.g. after sleep) or if difference >= 150 RPM
        if !smcManual || abs(targetRPM - lastAppliedRPM) >= 150 {
            setFanManual(rpm: targetRPM)
        }
    }
    
    static func calculateSmartRPM(temp: Double) -> Int {
        // Smart early cooling curve (active from 55°C):
        // 52°C - 55°C -> 1500 - 2000 RPM (gentle transition from silent)
        // 55°C - 65°C -> 2000 - 3600 RPM (early ramp-up before heat builds up)
        // 65°C - 75°C -> 3600 - 5200 RPM (active cooling to keep temp < 75°C)
        // 75°C - 84°C -> 5200 - 6600 RPM (high performance cooling)
        // >= 84°C     -> 7200 RPM (max blast)
        if temp < 55.0 {
            let ratio = max(0.0, (temp - 52.0) / 3.0)
            return Int(1500.0 + ratio * (2000.0 - 1500.0))
        } else if temp < 65.0 {
            let ratio = (temp - 55.0) / 10.0
            return Int(2000.0 + ratio * (3600.0 - 2000.0))
        } else if temp < 75.0 {
            let ratio = (temp - 65.0) / 10.0
            return Int(3600.0 + ratio * (5200.0 - 3600.0))
        } else if temp < 84.0 {
            let ratio = (temp - 75.0) / 9.0
            return Int(5200.0 + ratio * (6600.0 - 5200.0))
        } else {
            return 7200
        }
    }
    
    func applyCurrentMode() {
        lastAppliedRPM = -1
        switch currentMode {
        case .auto:
            smartIdleAutoActive = false
            setFanAuto(waitUntilDone: false)
        case .smart:
            smartIdleAutoActive = false
            let currentMax = max(SystemMonitor.shared.cpuTemp, SystemMonitor.shared.gpuTemp)
            if currentMax > 0 {
                // Keep higher of smoothedTemp and currentMax so switching to Smart on a hot Mac immediately cools it
                smoothedTemp = max(smoothedTemp, currentMax)
            }
            handleMetricsUpdate()
        case .max:
            smartIdleAutoActive = false
            setFanManual(rpm: maxFanRPM)
        case .manual:
            smartIdleAutoActive = false
            setFanManual(rpm: Int(targetManualRPM))
        }
    }
    
    private func setFanAuto(waitUntilDone: Bool) {
        executeFanCommand(["fan", "auto"], appliedRPM: 0, waitUntilDone: waitUntilDone)
    }
    
    private func setFanManual(rpm: Int) {
        let clampedRPM = max(minFanRPM, min(maxFanRPM, rpm))
        executeFanCommand(["fan", "manual", "\(clampedRPM)"], appliedRPM: clampedRPM, waitUntilDone: false)
    }
    
    private func executeFanCommand(_ arguments: [String], appliedRPM: Int, waitUntilDone: Bool) {
        let updateStateOnMain: (Bool) -> Void = { [weak self] succeeded in
            guard let self = self else { return }
            self.isCommandInFlight = false
            if succeeded {
                self.lastAppliedRPM = appliedRPM
                self.lastFailureTime = .distantPast
                if !waitUntilDone {
                    SystemMonitor.shared.refreshFanRPMQuickly()
                }
            } else {
                self.lastFailureTime = Date()
            }
        }
        
        if waitUntilDone {
            let succeeded = fanQueue.sync {
                HelperClient.run(arguments, timeout: 10.0).succeeded
            }
            if Thread.isMainThread {
                updateStateOnMain(succeeded)
            } else {
                DispatchQueue.main.sync {
                    updateStateOnMain(succeeded)
                }
            }
        } else {
            isCommandInFlight = true
            fanQueue.async {
                let succeeded = HelperClient.run(arguments, timeout: 10.0).succeeded
                DispatchQueue.main.async {
                    updateStateOnMain(succeeded)
                }
            }
        }
    }
}
