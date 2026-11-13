import Foundation

final class SMCReader {
    static let shared = SMCReader()
    
    init() {
        _ = smc_init()
    }
    
    func getCPUTemperature() -> Double {
        let temp = smc_get_cpu_temp()
        return (temp > 0) ? temp : 0.0
    }
    
    func getGPUTemperature() -> Double {
        let temp = smc_get_gpu_temp()
        return (temp > 0) ? temp : 0.0
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
    
    func isFanManualMode() -> Bool {
        return smc_is_fan_manual_mode() != 0
    }
    
    func getCPUPowerWatts() -> Double {
        let w = smc_get_cpu_power_watts()
        return (w > 0) ? w : 0.0
    }
    
    func getSystemPowerWatts() -> Double {
        let w = smc_get_system_power_watts()
        return (w > 0) ? w : 0.0
    }
    
    func getBatteryChargeLimit() -> Int? {
        let val = smc_get_battery_charge_limit()
        return val > 0 ? Int(val) : nil
    }
    
    func isChargeInhibited() -> Bool? {
        let val = smc_is_charge_inhibited()
        if val < 0 { return nil }
        return val != 0
    }
    
    func supportsChargeLimit() -> Bool {
        return smc_supports_charge_limit() != 0
    }
}
