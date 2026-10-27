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
    private var lastAppliedRPM: Int = 0
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
        
        // Listen to sensor updates for Smart Curve
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
        guard currentMode == .smart else { return }
        
        let cpuTemp = SystemMonitor.shared.cpuTemp
        let gpuTemp = SystemMonitor.shared.gpuTemp
        let maxTemp = max(cpuTemp, gpuTemp)
        guard maxTemp > 0 else { return }
        
        let targetRPM = calculateSmartRPM(temp: maxTemp)
        
        // Only update if difference >= 150 RPM to prevent constant micro-adjustments
        if abs(targetRPM - lastAppliedRPM) >= 150 {
            setFanManual(rpm: targetRPM)
        }
    }
    
    private func calculateSmartRPM(temp: Double) -> Int {
        // Smart early cooling curve:
        // < 50°C -> 1200 RPM (quiet)
        // 50°C - 65°C -> 1800 - 3400 RPM (ramp-up before heat builds up)
        // 65°C - 75°C -> 3400 - 4900 RPM (active cooling to stay below 75°C)
        // 75°C - 85°C -> 4900 - 6400 RPM (high performance cooling)
        // > 85°C -> 7200 RPM (emergency max)
        if temp < 50.0 {
            return 1200
        } else if temp < 65.0 {
            let ratio = (temp - 50.0) / 15.0
            return Int(1800.0 + ratio * (3400.0 - 1800.0))
        } else if temp < 75.0 {
            let ratio = (temp - 65.0) / 10.0
            return Int(3400.0 + ratio * (4900.0 - 3400.0))
        } else if temp < 85.0 {
            let ratio = (temp - 75.0) / 10.0
            return Int(4900.0 + ratio * (6400.0 - 4900.0))
        } else {
            return 7200
        }
    }
    
    func applyCurrentMode() {
        switch currentMode {
        case .auto:
            setFanAuto(waitUntilDone: false)
        case .smart:
            lastAppliedRPM = 0
            handleMetricsUpdate()
        case .max:
            setFanManual(rpm: 7200)
        case .manual:
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
        }
    }
}
