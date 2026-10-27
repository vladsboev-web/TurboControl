import Foundation
import Combine

final class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()
    
    @Published var cpuTemp: Double = 0.0
    @Published var gpuTemp: Double = 0.0
    @Published var fanRPM: Double = 0.0
    @Published var fanMinRPM: Double = 1200.0
    @Published var fanMaxRPM: Double = 7200.0
    
    @Published var cpuLoad: Double = 0.0
    @Published var gpuLoad: Double = 0.0
    
    private let smc = SMCReader.shared
    private let usage = UsageReader()
    private let pollQueue = DispatchQueue(label: "com.turbocontrol.pollQueue", qos: .utility)
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        fanMinRPM = smc.getFanMinRPM()
        fanMaxRPM = smc.getFanMaxRPM()
        
        // Initial reading
        updateMetrics()
        
        // Setup timer
        setupTimer()
        
        // Listen to settings changes
        NotificationCenter.default.publisher(for: .updateIntervalChanged)
            .sink { [weak self] _ in
                self?.setupTimer()
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
    
    func updateMetrics() {
        pollQueue.async { [weak self] in
            guard let self = self else { return }
            
            let cpuT = self.smc.getCPUTemperature()
            let gpuT = self.smc.getGPUTemperature()
            let fan = self.smc.getFanRPM()
            let cpuL = self.usage.getCPULoad()
            let gpuL = self.usage.getGPULoad()
            
            DispatchQueue.main.async {
                self.cpuTemp = cpuT
                self.gpuTemp = gpuT
                self.fanRPM = fan
                self.cpuLoad = cpuL
                self.gpuLoad = gpuL
                
                NotificationCenter.default.post(name: .metricsDidUpdate, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let metricsDidUpdate = Notification.Name("metricsDidUpdate")
}
