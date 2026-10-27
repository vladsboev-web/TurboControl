import Foundation

final class SMCReader {
    static let shared = SMCReader()
    
    init() {
        _ = smc_init()
    }
    
    deinit {
        smc_close()
    }
    
    func getCPUTemperature() -> Double {
        let temp = smc_get_cpu_temp()
        return (temp > 0) ? temp : 45.0
    }
    
    func getGPUTemperature() -> Double {
        let temp = smc_get_gpu_temp()
        return (temp > 0) ? temp : getCPUTemperature()
    }
    
    func getFanRPM() -> Double {
        let rpm = smc_get_fan_rpm()
        return max(0.0, rpm)
    }
    
    func getFanMinRPM() -> Double {
        return smc_get_fan_min_rpm()
    }
    
    func getFanMaxRPM() -> Double {
        return smc_get_fan_max_rpm()
    }
}
