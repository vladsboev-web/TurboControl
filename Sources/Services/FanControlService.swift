import Foundation
import Combine

enum FanMode: String, CaseIterable {
    case auto = "auto"       // macOS Apple Default
    case smart = "smart"     // Smart Early Cooling
    case max = "max"         // Max 7200 RPM
    case manual = "manual"   // Manual custom RPM
    
    var title: String {
        switch self {
        case .auto: return "Авто (Apple)"
        case .smart: return "Умный (Ранний)"
        case .max: return "Макс"
        case .manual: return "Ручной"
        }
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
    
    private let helperPath = "/usr/local/bin/turbocontrol-helper"
    private let fanQueue = DispatchQueue(label: "com.turbocontrol.fanQueue", qos: .userInitiated)
    private var lastAppliedRPM: Int = -1
    private var smoothedTemp: Double = 0.0
    private var smartIdleAutoActive: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
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
    }
    
    deinit {
        setFanAuto(waitUntilDone: false)
    }
    
    func resetToAppleAuto() {
        setFanAuto(waitUntilDone: true)
    }
    
    private func handleMetricsUpdate() {
        let smcManual = SMCReader.shared.isFanManualMode()
        
        switch currentMode {
        case .auto:
            // If SMC is still stuck in manual mode (e.g. previous command failed), enforce Auto
            if smcManual {
                setFanAuto(waitUntilDone: false)
            }
            return
            
        case .max:
            // If macOS reset SMC to Auto after sleep, re-apply Max
            if !smcManual || lastAppliedRPM != 7200 {
                setFanManual(rpm: 7200)
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
        
        var targetRPM = calculateSmartRPM(temp: smoothedTemp)
        
        // Never spin down abruptly while cooling down: cap RPM drop to at most 350 RPM per poll cycle
        if lastAppliedRPM > 0 && targetRPM < lastAppliedRPM {
            targetRPM = max(targetRPM, lastAppliedRPM - 350)
        }
        
        // Update if SMC lost manual state (e.g. after sleep) or if difference >= 150 RPM
        if !smcManual || abs(targetRPM - lastAppliedRPM) >= 150 {
            setFanManual(rpm: targetRPM)
        }
    }
    
    private func calculateSmartRPM(temp: Double) -> Int {
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
            setFanManual(rpm: 7200)
        case .manual:
            smartIdleAutoActive = false
            setFanManual(rpm: Int(targetManualRPM))
        }
    }
    
    private func setFanAuto(waitUntilDone: Bool) {
        lastAppliedRPM = 0
        let work = { [helperPath] in
            guard FileManager.default.isExecutableFile(atPath: helperPath) else { return }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            task.arguments = ["-n", helperPath, "fan", "auto"]
            try? task.run()
            task.waitUntilExit()
            if !waitUntilDone {
                SystemMonitor.shared.refreshFanRPMQuickly()
            }
        }
        if waitUntilDone {
            fanQueue.sync(execute: work)
        } else {
            fanQueue.async(execute: work)
        }
    }
    
    private func setFanManual(rpm: Int) {
        lastAppliedRPM = rpm
        fanQueue.async { [helperPath] in
            guard FileManager.default.isExecutableFile(atPath: helperPath) else { return }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            task.arguments = ["-n", helperPath, "fan", "manual", "\(rpm)"]
            try? task.run()
            task.waitUntilExit()
            SystemMonitor.shared.refreshFanRPMQuickly()
        }
    }
}
