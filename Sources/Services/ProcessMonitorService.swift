import Foundation
import Cocoa
import Darwin
import IOKit
import Combine

enum ProcessSortOption: String, CaseIterable {
    case cpu
    case gpu
    case energy
    case sleep
}

struct SleepBlockerItem: Identifiable {
    let id: String
    let pid: Int32
    let name: String
    let executablePath: String
    let icon: NSImage?
    let assertionType: String
    let reason: String
    let isSystemCritical: Bool
}

struct HeavyProcessItem: Identifiable {
    let id: Int32 // pid
    let name: String
    let executablePath: String
    let ruleKey: String
    let icon: NSImage?
    let cpuPercent: Double
    let gpuPercent: Double
    let energyImpact: Double
}

final class ProcessMonitorService: ObservableObject {
    static let shared = ProcessMonitorService()
    
    @Published var processes: [HeavyProcessItem] = []
    @Published var sleepBlockers: [SleepBlockerItem] = []
    @Published var sortBy: ProcessSortOption = .cpu {
        didSet {
            applySortAndPublish()
            if sortBy == .energy && !lastFetchUsedTop && isWindowVisible {
                refreshNow()
            }
        }
    }
    @Published var isLoading: Bool = false
    
    private var allCapturedProcesses: [HeavyProcessItem] = []
    private var timer: Timer?
    private let workerQueue = DispatchQueue(label: "com.turbocontrol.processMonitor", qos: .utility)
    private var isWindowVisible = false
    private var isFetching = false
    private var lastFetchUsedTop = false
    private var previousCpuSamples: [Int32: UInt64] = [:]
    private var previousSampleTimeNs: UInt64 = 0
    
    private static let timebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()
    
    private init() {}
    
    func startMonitoring() {
        isWindowVisible = true
        refreshNow()
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshNow()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }
    
    func stopMonitoring() {
        isWindowVisible = false
        timer?.invalidate()
        timer = nil
        workerQueue.async { [weak self] in
            self?.previousCpuSamples.removeAll()
            self?.previousSampleTimeNs = 0
        }
    }
    
    func refreshNow() {
        guard isWindowVisible, !isFetching else { return }
        isFetching = true
        if allCapturedProcesses.isEmpty {
            isLoading = true
        }
        
        // Take GUI apps snapshot, current GPU load and sort mode safely on the main thread before dispatching
        var appByPid: [Int32: NSRunningApplication] = [:]
        for app in NSWorkspace.shared.runningApplications {
            appByPid[app.processIdentifier] = app
        }
        let totalGPUUsage = SystemMonitor.shared.gpuLoad
        let useTopForEnergy = (sortBy == .energy)
        
        workerQueue.async { [weak self] in
            guard let self = self else { return }
            let captured = useTopForEnergy
                ? self.fetchHeavyProcessesViaTop(appByPid: appByPid, totalGPUUsage: totalGPUUsage)
                : self.fetchHeavyProcessesInProcess(appByPid: appByPid, totalGPUUsage: totalGPUUsage)
            let blockers = self.fetchSleepBlockers(appByPid: appByPid)
            DispatchQueue.main.async {
                self.lastFetchUsedTop = useTopForEnergy
                self.allCapturedProcesses = captured
                self.sleepBlockers = blockers
                self.isLoading = false
                self.isFetching = false
                self.applySortAndPublish()
            }
        }
    }
    
    private func applySortAndPublish() {
        let sorted: [HeavyProcessItem]
        switch sortBy {
        case .cpu:
            sorted = allCapturedProcesses.sorted { $0.cpuPercent > $1.cpuPercent }
        case .gpu:
            sorted = allCapturedProcesses.sorted {
                if $0.gpuPercent != $1.gpuPercent {
                    return $0.gpuPercent > $1.gpuPercent
                }
                return $0.cpuPercent > $1.cpuPercent
            }
        case .energy:
            sorted = allCapturedProcesses.sorted { $0.energyImpact > $1.energyImpact }
        case .sleep:
            sorted = allCapturedProcesses.sorted { $0.cpuPercent > $1.cpuPercent }
        }
        self.processes = Array(sorted.prefix(5))
    }
    
    private func safelyTerminate(pid: Int32, expectedPath: String) {
        if !expectedPath.isEmpty {
            let currentPath = getExecutablePath(pid: pid)
            if !currentPath.isEmpty && currentPath != expectedPath {
                return
            }
        }
        if let app = NSRunningApplication(processIdentifier: pid) {
            if !app.terminate() {
                app.forceTerminate()
            }
        } else {
            kill(pid, SIGTERM)
        }
    }
    
    func terminateSleepBlocker(_ item: SleepBlockerItem) {
        guard !item.isSystemCritical else { return }
        safelyTerminate(pid: item.pid, expectedPath: item.executablePath)
        sleepBlockers.removeAll { $0.pid == item.pid }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.refreshNow()
        }
    }
    
    func terminateProcess(_ item: HeavyProcessItem) {
        safelyTerminate(pid: item.id, expectedPath: item.executablePath)
        
        allCapturedProcesses.removeAll { $0.id == item.id }
        applySortAndPublish()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.refreshNow()
        }
    }
    
    private func makeHeavyProcessItem(
        pid: Int32,
        rawCommand: String,
        cpuPercent: Double,
        energyImpact: Double,
        appByPid: [Int32: NSRunningApplication],
        gpuClients: [Int32: Int],
        totalGPUUsage: Double,
        totalContexts: Int
    ) -> HeavyProcessItem? {
        let app = appByPid[pid]
        let execPath = getExecutablePath(pid: pid)
        if isSystemProcess(command: rawCommand, path: execPath, app: app) {
            return nil
        }
        let displayName = app?.localizedName ?? rawCommand
        let ruleKey = (app?.turboRuleKey).flatMap { $0.isEmpty ? nil : $0 } ?? displayName
        let icon = app?.icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
        let contexts = gpuClients[pid] ?? 0
        let estimatedGPU = contexts > 0 ? min(100.0, totalGPUUsage * (Double(contexts) / Double(totalContexts))) : 0.0
        
        return HeavyProcessItem(
            id: pid,
            name: displayName,
            executablePath: execPath,
            ruleKey: ruleKey,
            icon: icon,
            cpuPercent: cpuPercent,
            gpuPercent: estimatedGPU,
            energyImpact: energyImpact
        )
    }
    
    private func sampleUserProcessCpuTicks() -> (samples: [Int32: UInt64], names: [Int32: String], timestampNs: UInt64) {
        let nowNs = DispatchTime.now().uptimeNanoseconds
        let estimatedCount = proc_listallpids(nil, 0)
        guard estimatedCount > 0 else { return ([:], [:], nowNs) }
        
        var pids = [Int32](repeating: 0, count: Int(estimatedCount) + 64)
        let byteCount = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        guard byteCount > 0 else { return ([:], [:], nowNs) }
        
        let count = Int(byteCount) / MemoryLayout<Int32>.size
        let currentUID = getuid()
        let selfPid = ProcessInfo.processInfo.processIdentifier
        
        var samples: [Int32: UInt64] = [:]
        var names: [Int32: String] = [:]
        samples.reserveCapacity(count / 2)
        
        for i in 0..<count {
            let pid = pids[i]
            guard pid > 0, pid != selfPid else { continue }
            
            var bsdInfo = proc_bsdinfo()
            let bsdSize = Int32(MemoryLayout<proc_bsdinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, bsdSize) == bsdSize,
                  bsdInfo.pbi_uid == currentUID else {
                continue
            }
            
            var usage = rusage_info_v2()
            let rusageRc = withUnsafeMutablePointer(to: &usage) { ptr in
                ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reboundPtr in
                    proc_pid_rusage(pid, RUSAGE_INFO_V2, reboundPtr)
                }
            }
            guard rusageRc == 0 else { continue }
            
            let name = withUnsafePointer(to: &bsdInfo.pbi_name) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) * 2) {
                    String(cString: $0)
                }
            }
            samples[pid] = usage.ri_user_time &+ usage.ri_system_time
            names[pid] = name
        }
        
        return (samples, names, nowNs)
    }
    
    private func fetchHeavyProcessesInProcess(appByPid: [Int32: NSRunningApplication], totalGPUUsage: Double) -> [HeavyProcessItem] {
        let gpuClients = fetchGPUClientCounts()
        let totalContexts = max(1, gpuClients.values.reduce(0, +))
        
        if previousSampleTimeNs == 0 || previousCpuSamples.isEmpty {
            let baseline = sampleUserProcessCpuTicks()
            previousCpuSamples = baseline.samples
            previousSampleTimeNs = baseline.timestampNs
            Thread.sleep(forTimeInterval: 0.35)
        }
        
        let current = sampleUserProcessCpuTicks()
        let wallNsDelta = current.timestampNs > previousSampleTimeNs ? (current.timestampNs - previousSampleTimeNs) : 1
        let numer = UInt64(Self.timebaseInfo.numer)
        let denom = max(1, UInt64(Self.timebaseInfo.denom))
        
        var items: [HeavyProcessItem] = []
        for (pid, totalTicks) in current.samples {
            let prevTicks = previousCpuSamples[pid] ?? totalTicks
            let tickDelta = totalTicks >= prevTicks ? (totalTicks - prevTicks) : 0
            let cpuNsDelta = (tickDelta &* numer) / denom
            let cpuPercent = (Double(cpuNsDelta) / Double(wallNsDelta)) * 100.0
            
            let isRegularApp = appByPid[pid]?.activationPolicy == .regular
            let hasGpuContexts = (gpuClients[pid] ?? 0) > 0
            guard cpuPercent >= 0.05 || hasGpuContexts || isRegularApp else { continue }
            
            let rawCommand = current.names[pid] ?? ""
            if let item = makeHeavyProcessItem(
                pid: pid,
                rawCommand: rawCommand,
                cpuPercent: cpuPercent,
                energyImpact: 0.0,
                appByPid: appByPid,
                gpuClients: gpuClients,
                totalGPUUsage: totalGPUUsage,
                totalContexts: totalContexts
            ) {
                items.append(item)
            }
        }
        
        previousCpuSamples = current.samples
        previousSampleTimeNs = current.timestampNs
        return items
    }
    
    private func fetchHeavyProcessesViaTop(appByPid: [Int32: NSRunningApplication], totalGPUUsage: Double) -> [HeavyProcessItem] {
        let currentUser = NSUserName()
        let selfPid = ProcessInfo.processInfo.processIdentifier
        
        let gpuClients = fetchGPUClientCounts()
        let totalContexts = max(1, gpuClients.values.reduce(0, +))
        
        // Run top -l 2 -s 1 for accurate Energy (POWER)
        let result = ProcessRunner.run(
            "/usr/bin/top",
            arguments: ["-l", "2", "-s", "1", "-n", "40", "-o", "cpu", "-stats", "pid,cpu,power,user,command"],
            timeout: 8.0
        )
        guard result.succeeded else { return [] }
        let output = result.stdout
        
        // Parse only the 2nd sample (after the second "PID   %CPU")
        let lines = output.components(separatedBy: .newlines)
        var headerCount = 0
        var items: [HeavyProcessItem] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("PID") && trimmed.contains("%CPU") {
                headerCount += 1
                continue
            }
            guard headerCount >= 2, !trimmed.isEmpty else { continue }
            
            // Format: PID %CPU POWER USER COMMAND...
            let parts = trimmed.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard parts.count >= 5,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let power = Double(parts[2]) else {
                continue
            }
            
            let user = String(parts[3])
            let rawCommand = String(parts[4]).trimmingCharacters(in: .whitespaces)
            
            // Filter out system processes, daemons, and self
            guard user == currentUser, pid != selfPid else { continue }
            if let item = makeHeavyProcessItem(
                pid: pid,
                rawCommand: rawCommand,
                cpuPercent: cpu,
                energyImpact: power,
                appByPid: appByPid,
                gpuClients: gpuClients,
                totalGPUUsage: totalGPUUsage,
                totalContexts: totalContexts
            ) {
                items.append(item)
            }
        }
        
        return items
    }
    
    private func getExecutablePath(pid: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: 4096) // PROC_PIDPATHINFO_MAXSIZE
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        if length > 0 {
            return String(cString: buffer)
        }
        return ""
    }
    
    private func isSystemProcess(command: String, path: String, app: NSRunningApplication?) -> Bool {
        if command.hasPrefix("TurboControl") || app?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return true
        }
        
        // Allow regular GUI applications (even if in /System/Applications/ like Terminal, Safari)
        if let app = app, app.activationPolicy == .regular {
            return false
        }
        
        // Exclude macOS system frameworks, daemons, and CLI utilities
        let systemPathPrefixes = [
            "/System/Library/",
            "/System/iOSSupport/",
            "/usr/libexec/",
            "/usr/sbin/",
            "/usr/bin/",
            "/sbin/",
            "/bin/",
            "/Library/Apple/"
        ]
        if !path.isEmpty {
            if systemPathPrefixes.contains(where: { path.hasPrefix($0) }) {
                return true
            }
            // Allow user-installed apps and helpers inside /Applications or user folders
            if path.contains("/Applications/") || path.hasPrefix("/Users/") || path.hasPrefix("/opt/") || path.hasPrefix("/usr/local/") {
                return false
            }
        }
        
        // Fallback name filter if path couldn't be read
        let ignoredPrefixes = [
            "top", "ps", "mdworker", "mds", "cloudd", "bird", "nsurlsessiond",
            "trustd", "secd", "cfprefsd", "distnoted", "UserEventAgent",
            "loginwindow", "Dock", "Finder", "SystemUIServer", "ControlCenter",
            "NotificationCenter", "Spotlight", "WindowServer", "biomesyncd",
            "photoanalysisd", "mediaanalysisd", "sharingd", "identityservicesd",
            "callservicesd", "knowledge-agent", "contextstored", "TurboControl"
        ]
        return ignoredPrefixes.contains { command.hasPrefix($0) }
    }
    
    private func fetchGPUClientCounts() -> [Int32: Int] {
        var counts: [Int32: Int] = [:]
        let matchDict = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator) == kIOReturnSuccess else {
            return counts
        }
        defer { IOObjectRelease(iterator) }
        
        var accel = IOIteratorNext(iterator)
        while accel != 0 {
            var childIter: io_iterator_t = 0
            if IORegistryEntryGetChildIterator(accel, kIOServicePlane, &childIter) == kIOReturnSuccess {
                var child = IOIteratorNext(childIter)
                while child != 0 {
                    if let creator = IORegistryEntryCreateCFProperty(child, "IOUserClientCreator" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
                        // Format: "pid 999, Google Chrome Helper"
                        if creator.hasPrefix("pid "),
                           let commaIdx = creator.firstIndex(of: ","),
                           let pid = Int32(creator[creator.index(creator.startIndex, offsetBy: 4)..<commaIdx]) {
                            counts[pid, default: 0] += 1
                        }
                    }
                    IOObjectRelease(child)
                    child = IOIteratorNext(childIter)
                }
                IOObjectRelease(childIter)
            }
            IOObjectRelease(accel)
            accel = IOIteratorNext(iterator)
        }
        return counts
    }
    
    private func fetchSleepBlockers(appByPid: [Int32: NSRunningApplication]) -> [SleepBlockerItem] {
        let result = ProcessRunner.run("/usr/bin/pmset", arguments: ["-g", "assertions"], timeout: 5.0)
        guard result.succeeded else { return [] }
        let output = result.stdout
        
        let criticalNames: Set<String> = [
            "powerd", "kernel_task", "WindowServer", "loginwindow",
            "launchd", "coreaudiod", "bluetoothd", "UserEventAgent"
        ]
        
        var items: [SleepBlockerItem] = []
        var seenKeys = Set<String>()
        
        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("pid "),
                  let openParen = line.firstIndex(of: "("),
                  let closeParen = line.firstIndex(of: ")"),
                  openParen < closeParen else {
                continue
            }
            
            let pidStart = line.index(line.startIndex, offsetBy: 4)
            guard let pid = Int32(line[pidStart..<openParen]) else { continue }
            
            let rawName = String(line[line.index(after: openParen)..<closeParen])
            let afterParen = String(line[line.index(after: closeParen)...])
            
            // Extract assertion type (e.g. PreventUserIdleSystemSleep, PreventUserIdleDisplaySleep, PreventSystemSleep)
            var assertionType = "PreventSleep"
            let knownTypes = [
                "PreventUserIdleDisplaySleep",
                "PreventUserIdleSystemSleep",
                "PreventSystemSleep",
                "NoDisplaySleepAssertion",
                "NoIdleSleepAssertion",
                "BackgroundTask"
            ]
            if let matchedType = knownTypes.first(where: { afterParen.contains($0) }) {
                assertionType = matchedType
            } else {
                continue
            }
            
            var reason = ""
            if let namedRange = afterParen.range(of: "named: \"") {
                let tail = afterParen[namedRange.upperBound...]
                if let endQuote = tail.firstIndex(of: "\"") {
                    reason = String(tail[..<endQuote])
                }
            }
            
            let key = "\(pid)-\(assertionType)"
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            
            let app = appByPid[pid]
            let execPath = getExecutablePath(pid: pid)
            let displayName = app?.localizedName ?? rawName
            let icon = app?.icon ?? NSImage(systemSymbolName: "moon.zzz.fill", accessibilityDescription: nil)
            let isCritical = criticalNames.contains(rawName) || (app == nil && execPath.hasPrefix("/System/"))
            
            items.append(SleepBlockerItem(
                id: key,
                pid: pid,
                name: displayName,
                executablePath: execPath,
                icon: icon,
                assertionType: assertionType,
                reason: reason.isEmpty ? assertionType : reason,
                isSystemCritical: isCritical
            ))
        }
        
        return items
    }
}
