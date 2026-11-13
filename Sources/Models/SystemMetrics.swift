import Foundation
import Combine

struct MetricSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let cpuTemp: Double
    let cpuFreqGHz: Double
    let fanRPM: Double
    let systemPowerW: Double
}

final class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()
    
    @Published var cpuTemp: Double = 0.0
    @Published var gpuTemp: Double = 0.0
    @Published var fanRPM: Double = 0.0
    @Published var fanMinRPM: Double = 1200.0
    @Published var fanMaxRPM: Double = 7200.0
    
    @Published var cpuLoad: Double = 0.0
    @Published var gpuLoad: Double = 0.0
    @Published var cpuFrequencyGHz: Double = 0.0
    @Published var cpuPowerWatts: Double = 0.0
    @Published var systemPowerWatts: Double = 0.0
    @Published var isFanManualMode: Bool = false
    @Published var metricsHistory: [MetricSample] = []
    
    var isPopoverVisible: Bool = false
    
    private let smc = SMCReader.shared
    private let usage = UsageReader.shared
    private let pollQueue = DispatchQueue(label: "com.turbocontrol.pollQueue", qos: .utility)
    private var timer: Timer?
    private var chartTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastFreqCheckTime: Date = .distantPast
    private let maxHistoryCount = 120
    
    private init() {
        fanMinRPM = smc.getFanMinRPM()
        fanMaxRPM = smc.getFanMaxRPM()
        
        // Initial reading
        updateMetrics()
        
        // Setup timer
        setupTimer()
        setupChartTimer()
        
        // Listen to settings changes
        NotificationCenter.default.publisher(for: .updateIntervalChanged)
            .sink { [weak self] _ in
                self?.setupTimer()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .chartsSettingsChanged)
            .sink { [weak self] _ in
                self?.setupChartTimer()
            }
            .store(in: &cancellables)
    }
    
    private func setupTimer() {
        timer?.invalidate()
        let interval = AppSettings.shared.updateInterval
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
        newTimer.tolerance = min(1.0, interval * 0.1)
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }
    
    private func setupChartTimer() {
        chartTimer?.invalidate()
        chartTimer = nil
        
        guard AppSettings.shared.chartsEnabled else {
            metricsHistory.removeAll()
            return
        }
        
        recordChartSample()
        
        let interval = AppSettings.shared.chartsSampleInterval
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.recordChartSample()
        }
        newTimer.tolerance = min(2.0, interval * 0.1)
        RunLoop.main.add(newTimer, forMode: .common)
        chartTimer = newTimer
    }
    
    private func recordChartSample() {
        guard AppSettings.shared.chartsEnabled else { return }
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            let cpuT = self.smc.getCPUTemperature()
            let fan = self.smc.getFanRPM()
            let sysW = self.readSystemPowerWatts()
            let freq = self.usage.getCPUFrequencyGHz()
            
            DispatchQueue.main.async {
                guard AppSettings.shared.chartsEnabled else { return }
                if freq > 0 && self.cpuFrequencyGHz != freq {
                    self.cpuFrequencyGHz = freq
                }
                let sample = MetricSample(
                    timestamp: Date(),
                    cpuTemp: cpuT,
                    cpuFreqGHz: freq > 0 ? freq : self.cpuFrequencyGHz,
                    fanRPM: fan,
                    systemPowerW: sysW
                )
                self.metricsHistory.append(sample)
                if self.metricsHistory.count > self.maxHistoryCount {
                    self.metricsHistory.removeFirst(self.metricsHistory.count - self.maxHistoryCount)
                }
            }
        }
    }
    
    private func readSystemPowerWatts() -> Double {
        let smcSys = smc.getSystemPowerWatts()
        if smcSys > 0 {
            return smcSys
        }
        return usage.getBatteryPowerWatts() ?? 0.0
    }
    
    func updateMetrics() {
        let shouldReadLoad = isPopoverVisible
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            
            let cpuT = self.smc.getCPUTemperature()
            let gpuT = self.smc.getGPUTemperature()
            let fan = self.smc.getFanRPM()
            let fanManual = self.smc.isFanManualMode()
            let cpuW = self.smc.getCPUPowerWatts()
            let sysW = self.readSystemPowerWatts()
            let cpuL = shouldReadLoad ? self.usage.getCPULoad() : self.cpuLoad
            let gpuL = shouldReadLoad ? self.usage.getGPULoad() : self.gpuLoad
            
            var cpuFreq = self.cpuFrequencyGHz
            if shouldReadLoad {
                let now = Date()
                if now.timeIntervalSince(self.lastFreqCheckTime) >= 8.0 || cpuFreq <= 0 {
                    self.lastFreqCheckTime = now
                    cpuFreq = self.usage.getCPUFrequencyGHz()
                }
            }
            
            DispatchQueue.main.async {
                if self.cpuTemp != cpuT { self.cpuTemp = cpuT }
                if self.gpuTemp != gpuT { self.gpuTemp = gpuT }
                if self.fanRPM != fan { self.fanRPM = fan }
                if self.isFanManualMode != fanManual { self.isFanManualMode = fanManual }
                if self.cpuPowerWatts != cpuW { self.cpuPowerWatts = cpuW }
                if self.systemPowerWatts != sysW { self.systemPowerWatts = sysW }
                if shouldReadLoad {
                    if self.cpuLoad != cpuL { self.cpuLoad = cpuL }
                    if self.gpuLoad != gpuL { self.gpuLoad = gpuL }
                    if cpuFreq > 0 && self.cpuFrequencyGHz != cpuFreq {
                        self.cpuFrequencyGHz = cpuFreq
                    }
                }
                
                NotificationCenter.default.post(name: .metricsDidUpdate, object: nil)
            }
        }
    }
    
    func refreshFanRPMQuickly() {
        for delay in [0.35, 1.0, 2.0] {
            pollQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                let fan = self.smc.getFanRPM()
                DispatchQueue.main.async {
                    if self.fanRPM != fan {
                        self.fanRPM = fan
                    }
                }
            }
        }
    }
}

extension Notification.Name {
    static let metricsDidUpdate = Notification.Name("metricsDidUpdate")
}
