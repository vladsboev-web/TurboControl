import Foundation
import Cocoa
import Darwin
import IOKit
import Combine

enum ProcessSortOption: String, CaseIterable {
    case cpu
    case gpu
    case energy
}

struct HeavyProcessItem: Identifiable {
    let id: Int32 // pid
    let name: String
    let ruleKey: String
    let icon: NSImage?
    let cpuPercent: Double
    let gpuPercent: Double
    let energyImpact: Double
}

final class ProcessMonitorService: ObservableObject {
    static let shared = ProcessMonitorService()
    
    @Published var processes: [HeavyProcessItem] = []
    @Published var sortBy: ProcessSortOption = .cpu {
        didSet {
            applySortAndPublish()
        }
    }
    @Published var isLoading: Bool = false
    
    private var allCapturedProcesses: [HeavyProcessItem] = []
    private var timer: Timer?
    private let workerQueue = DispatchQueue(label: "com.turbocontrol.processMonitor", qos: .utility)
    private var isWindowVisible = false
    
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
    }
    
    func refreshNow() {
        guard isWindowVisible else { return }
        if allCapturedProcesses.isEmpty {
            isLoading = true
        }
        
        workerQueue.async { [weak self] in
            guard let self = self else { return }
            let captured = self.fetchHeavyProcesses()
            DispatchQueue.main.async {
                self.allCapturedProcesses = captured
                self.isLoading = false
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
        }
        self.processes = Array(sorted.prefix(5))
    }
    
    func terminateProcess(_ item: HeavyProcessItem) {
        if let app = NSRunningApplication(processIdentifier: item.id) {
            if !app.terminate() {
                app.forceTerminate()
            }
        } else {
            kill(item.id, SIGTERM)
        }
        
        allCapturedProcesses.removeAll { $0.id == item.id }
        applySortAndPublish()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.refreshNow()
        }
    }
    
    private func fetchHeavyProcesses() -> [HeavyProcessItem] {
        let currentUser = NSUserName()
        let selfPid = ProcessInfo.processInfo.processIdentifier
        
        // Snapshot running GUI apps on main thread safely
        var appByPid: [Int32: NSRunningApplication] = [:]
        DispatchQueue.main.sync {
            for app in NSWorkspace.shared.runningApplications {
                appByPid[app.processIdentifier] = app
            }
        }
        
        let gpuClients = fetchGPUClientCounts()
        let totalGPUUsage = UsageReader().getGPULoad()
        let totalContexts = max(1, gpuClients.values.reduce(0, +))
        
        // Run top -l 2 -s 1 for accurate CPU% and Energy (POWER)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        task.arguments = ["-l", "2", "-s", "1", "-n", "40", "-o", "cpu", "-stats", "pid,cpu,power,user,command"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return []
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        
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
            let app = appByPid[pid]
            let execPath = getExecutablePath(pid: pid)
            if isSystemProcess(command: rawCommand, path: execPath, app: app) { continue }
            let displayName = app?.localizedName ?? rawCommand
            let ruleKey: String
            if let bundleId = app?.bundleIdentifier, !bundleId.isEmpty {
                ruleKey = bundleId
            } else {
                ruleKey = displayName
            }
            
            let icon = app?.icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil)
            let contexts = gpuClients[pid] ?? 0
            let estimatedGPU = contexts > 0 ? min(100.0, totalGPUUsage * (Double(contexts) / Double(totalContexts))) : 0.0
            
            items.append(HeavyProcessItem(
                id: pid,
                name: displayName,
                ruleKey: ruleKey,
                icon: icon,
                cpuPercent: cpu,
                gpuPercent: estimatedGPU,
                energyImpact: power
            ))
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
}
