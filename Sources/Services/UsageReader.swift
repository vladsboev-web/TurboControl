import Foundation
import IOKit

final class UsageReader {
    static let shared = UsageReader()
    
    private var previousCpuInfo: [integer_t] = []
    private let lock = NSLock()
    
    private init() {}
    
    func getCPULoad() -> Double {
        lock.lock()
        defer { lock.unlock() }
        
        var processorCount: natural_t = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0
        
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )
        
        guard result == KERN_SUCCESS, let info = processorInfo else { return 0.0 }
        let count = Int(processorInfoCount)
        let vmSize = vm_size_t(processorInfoCount * UInt32(MemoryLayout<integer_t>.size))
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vmSize)
        }
        
        let currentInfo = Array(UnsafeBufferPointer(start: info, count: count))
        
        guard previousCpuInfo.count == count else {
            previousCpuInfo = currentInfo
            return 0.0
        }
        
        var totalInUse: Int64 = 0
        var totalTotal: Int64 = 0
        
        for i in 0..<Int(processorCount) {
            let base = i * Int(CPU_STATE_MAX)
            let user = Int64(currentInfo[base + Int(CPU_STATE_USER)] &- previousCpuInfo[base + Int(CPU_STATE_USER)])
            let system = Int64(currentInfo[base + Int(CPU_STATE_SYSTEM)] &- previousCpuInfo[base + Int(CPU_STATE_SYSTEM)])
            let nice = Int64(currentInfo[base + Int(CPU_STATE_NICE)] &- previousCpuInfo[base + Int(CPU_STATE_NICE)])
            let idle = Int64(currentInfo[base + Int(CPU_STATE_IDLE)] &- previousCpuInfo[base + Int(CPU_STATE_IDLE)])
            
            let inUse = max(0, user + system + nice)
            let total = max(1, inUse + max(0, idle))
            
            totalInUse += inUse
            totalTotal += total
        }
        
        previousCpuInfo = currentInfo
        
        if totalTotal > 0 {
            let pct = (Double(totalInUse) / Double(totalTotal)) * 100.0
            return min(100.0, max(0.0, pct))
        }
        return 0.0
    }
    
    func getGPULoad() -> Double {
        let matchDict = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator) == kIOReturnSuccess else {
            return 0.0
        }
        defer { IOObjectRelease(iterator) }
        
        var usage: Double = 0.0
        var regEntry = IOIteratorNext(iterator)
        while regEntry != 0 {
            var serviceDict: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(regEntry, &serviceDict, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let dict = serviceDict?.takeRetainedValue() as? [String: Any],
               let perfStats = dict["PerformanceStatistics"] as? [String: Any] {
                if let devUtil = perfStats["Device Utilization %"] as? NSNumber {
                    usage = max(usage, devUtil.doubleValue)
                } else if let gpuCore = perfStats["GPU Core Utilization"] as? NSNumber {
                    usage = max(usage, gpuCore.doubleValue)
                }
            }
            IOObjectRelease(regEntry)
            regEntry = IOIteratorNext(iterator)
        }
        return min(100.0, max(0.0, usage))
    }
    
    func getNominalCPUFrequencyGHz() -> Double {
        var freq: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.cpufrequency", &freq, &size, nil, 0) == 0, freq > 0 {
            return Double(freq) / 1_000_000_000.0
        }
        return 0.0
    }
    
    func getCPUFrequencyGHz() -> Double {
        let nominal = getNominalCPUFrequencyGHz()
        let result = HelperClient.run(["cpu_freq"], timeout: 3.0)
        guard result.succeeded else {
            return nominal
        }
        let output = result.stdout
        if output.hasPrefix("PCT:"), let pct = Double(output.dropFirst(4)), nominal > 0 {
            return nominal * (pct / 100.0)
        } else if let mhz = Double(output), mhz > 100 {
            return mhz / 1000.0
        }
        return nominal
    }
    
    func getBatteryPowerWatts() -> Double? {
        let matchDict = IOServiceMatching("AppleSmartBattery")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matchDict)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        
        guard let voltageNum = dict["Voltage"] as? NSNumber else { return nil }
        let ampNum = (dict["InstantAmperage"] as? NSNumber) ?? (dict["Amperage"] as? NSNumber)
        guard let ampNum = ampNum else { return nil }
        
        let voltageMV = voltageNum.doubleValue
        let amperageMA = Double(Int64(bitPattern: ampNum.uint64Value))
        let externalConnected = (dict["ExternalConnected"] as? Bool) ?? true
        
        // Negative amperage (or non-zero draw on battery) represents battery discharge power
        if amperageMA < 0 && amperageMA > -30000 {
            let watts = (voltageMV * abs(amperageMA)) / 1_000_000.0
            return (watts > 0.1 && watts < 250.0) ? watts : nil
        } else if !externalConnected && amperageMA > 0 && amperageMA < 30000 {
            let watts = (voltageMV * amperageMA) / 1_000_000.0
            return (watts > 0.1 && watts < 250.0) ? watts : nil
        }
        return nil
    }
    
    private static var cachedLowPowerModeSupport: Bool?
    private static let lpmLock = NSLock()
    
    func isLowPowerModeSupported() -> Bool {
        Self.lpmLock.lock()
        if let cached = Self.cachedLowPowerModeSupport {
            Self.lpmLock.unlock()
            return cached
        }
        Self.lpmLock.unlock()
        
        let result = ProcessRunner.run("/usr/bin/pmset", arguments: ["-g"], timeout: 5.0)
        let supported = result.succeeded && result.stdout.contains("lowpowermode")
        
        Self.lpmLock.lock()
        Self.cachedLowPowerModeSupport = supported
        Self.lpmLock.unlock()
        return supported
    }
}
