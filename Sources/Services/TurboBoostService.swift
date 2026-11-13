import Foundation
import AppKit

final class TurboBoostService: ObservableObject {
    static let shared = TurboBoostService()
    
    @Published var isTurboDisabled: Bool = false
    @Published var isWorking: Bool = false
    @Published var isHelperConfigured: Bool = false
    @Published var isHelperOutdated: Bool = false
    @Published var statusMessage: String?
    
    private let kextBundleID = "com.rugarciap.DisableTurboBoost"
    private let loadedKextPath = "/Library/Extensions/DisableTurboBoost.kext"
    
    private init() {
        guard SystemCapabilities.isIntelMac else { return }
        checkHelperInstalled()
        refreshStatus()
        setupWakeNotification()
    }
    
    func checkHelperInstalled() {
        let installed = HelperClient.isHelperInstalled
        var outdated = !installed && FileManager.default.isExecutableFile(atPath: HelperClient.legacyHelperPath)
        if installed,
           let bundledHelper = Bundle.main.path(forResource: "turbocontrol-helper", ofType: nil),
           let bundledData = try? Data(contentsOf: URL(fileURLWithPath: bundledHelper)),
           let installedData = try? Data(contentsOf: URL(fileURLWithPath: HelperClient.helperPath)) {
            outdated = (bundledData != installedData)
        }
        DispatchQueue.main.async {
            self.isHelperConfigured = installed
            self.isHelperOutdated = outdated
        }
    }
    
    private func setupWakeNotification() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWakeNotification),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    @objc private func handleWakeNotification() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if AppSettings.shared.restoreLastTurboState {
                let savedChoice = AppSettings.shared.userChosenTurboDisabled
                self.setTurboDisabled(savedChoice, isUserInitiated: false)
            } else {
                self.refreshStatus()
            }
            FanControlService.shared.applyCurrentMode()
        }
    }
    
    func refreshStatus() {
        guard SystemCapabilities.isIntelMac else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let disabled = self?.checkIfKextLoaded() ?? false
            DispatchQueue.main.async {
                if self?.isTurboDisabled != disabled {
                    self?.isTurboDisabled = disabled
                    NotificationCenter.default.post(name: .menuBarDisplayChanged, object: nil)
                }
            }
        }
    }
    
    private func checkIfKextLoaded() -> Bool {
        // Fast in-process IOKit check (0 processes, <0.2ms)
        if smc_is_kext_loaded(kextBundleID) == 1 {
            return true
        }
        
        // Fast check via kextstat before falling back to kmutil
        for (execPath, args) in [("/usr/sbin/kextstat", ["-b", kextBundleID]), ("/usr/bin/kmutil", ["showloaded", "--bundle-identifier", kextBundleID])] {
            guard FileManager.default.isExecutableFile(atPath: execPath) else { continue }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: execPath)
            task.arguments = args
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()
                if let output = String(data: data, encoding: .utf8), output.contains(self.kextBundleID) {
                    return true
                }
                if execPath == "/usr/sbin/kextstat" && task.terminationStatus == 0 {
                    // kextstat ran cleanly and did not contain bundle ID
                    return false
                }
            } catch {
                continue
            }
        }
        return false
    }
    
    func installHelperWithPrompt(completion: @escaping (Bool) -> Void) {
        let bundledScript = Bundle.main.bundlePath + "/Contents/Resources/setup_helper.sh"
        guard FileManager.default.fileExists(atPath: bundledScript) else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        
        let escapedPath = bundledScript.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let appleScriptCode = "do shell script \"\\\"\(escapedPath)\\\"\" with administrator privileges"
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSDictionary?
            var success = false
            if let appleScript = NSAppleScript(source: appleScriptCode) {
                _ = appleScript.executeAndReturnError(&error)
                if error == nil {
                    success = true
                }
            }
            
            DispatchQueue.main.async {
                self?.checkHelperInstalled()
                completion(success)
            }
        }
    }
    
    func setTurboDisabled(_ disabled: Bool, isUserInitiated: Bool = true, completion: ((Bool) -> Void)? = nil) {
        guard SystemCapabilities.isIntelMac else {
            completion?(false)
            return
        }
        guard !isWorking else { return }
        
        if isUserInitiated {
            AppSettings.shared.userChosenTurboDisabled = disabled
        }
        
        isWorking = true
        statusMessage = nil
        
        if !HelperClient.isHelperInstalled {
            installHelperWithPrompt { [weak self] installed in
                guard let self = self else { return }
                if installed {
                    self.executeToggle(disabled: disabled, allowRetry: false, completion: completion)
                } else {
                    self.isWorking = false
                    self.statusMessage = L10n.errHelperSetupRequired
                    completion?(false)
                }
            }
        } else {
            executeToggle(disabled: disabled, allowRetry: true, completion: completion)
        }
    }
    
    private func executeToggle(disabled: Bool, allowRetry: Bool = true, completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let command = disabled ? "disable" : "enable"
            let result = HelperClient.run([command], timeout: 10.0)
            
            var success = false
            var needsHelperReinstall = false
            var customErrorMessage: String?
            
            let output = result.stdout
            let errOutput = result.stderr
            
            if !result.timedOut {
                if errOutput.contains("password is required") || errOutput.contains("a terminal is required") || errOutput.contains("not allowed") || output.contains("KEXT_NOT_FOUND") || output.contains("FAN_BINARY_NOT_FOUND") {
                    needsHelperReinstall = true
                } else if output.contains("NEEDS_APPROVAL") || result.exitCode == 27 {
                    customErrorMessage = L10n.errKextApprovalRequired
                    DispatchQueue.main.async {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?General") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                } else if output.contains("NEEDS_REBOOT") || result.exitCode == 28 {
                    customErrorMessage = L10n.errKextRebootRequired
                } else if disabled && output == "DISABLED" {
                    success = true
                } else if !disabled && output == "ENABLED" {
                    success = true
                } else if result.succeeded {
                    success = true
                }
            }
            
            if needsHelperReinstall {
                DispatchQueue.main.async {
                    guard allowRetry else {
                        self.isWorking = false
                        self.statusMessage = L10n.errSudoersRequired
                        completion?(false)
                        return
                    }
                    self.installHelperWithPrompt { [weak self] installed in
                        guard let self = self else { return }
                        if installed {
                            self.executeToggle(disabled: disabled, allowRetry: false, completion: completion)
                        } else {
                            self.isWorking = false
                            self.statusMessage = L10n.errSudoersRequired
                            completion?(false)
                        }
                    }
                }
                return
            }
            
            let finalStatus = self.checkIfKextLoaded()
            
            DispatchQueue.main.async {
                self.isTurboDisabled = finalStatus
                self.isWorking = false
                NotificationCenter.default.post(name: .menuBarDisplayChanged, object: nil)
                if let customErrorMessage = customErrorMessage, finalStatus != disabled {
                    self.statusMessage = customErrorMessage
                } else if !success && finalStatus != disabled {
                    self.statusMessage = L10n.errToggleFailed
                }
                completion?(finalStatus == disabled)
            }
        }
    }
}
