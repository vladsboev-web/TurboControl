import Foundation
import AppKit

final class TurboBoostService: ObservableObject {
    static let shared = TurboBoostService()
    
    @Published var isTurboDisabled: Bool = false
    @Published var isWorking: Bool = false
    @Published var isHelperConfigured: Bool = false
    @Published var isHelperOutdated: Bool = false
    @Published var statusMessage: String?
    
    private struct PendingToggle {
        let disabled: Bool
        let isUserInitiated: Bool
        let completion: ((Bool) -> Void)?
    }
    
    private let kextBundleID = "com.rugarciap.DisableTurboBoost"
    private var pendingToggle: PendingToggle?
    
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
        return smc_is_kext_loaded(kextBundleID) == 1
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
        
        if isUserInitiated {
            AppSettings.shared.userChosenTurboDisabled = disabled
        }
        
        if isWorking {
            pendingToggle?.completion?(false)
            pendingToggle = PendingToggle(disabled: disabled, isUserInitiated: isUserInitiated, completion: completion)
            return
        }
        
        isWorking = true
        statusMessage = nil
        
        if !HelperClient.isHelperInstalled {
            installHelperWithPrompt { [weak self] installed in
                guard let self = self else {
                    completion?(false)
                    return
                }
                if installed {
                    self.executeToggle(disabled: disabled, allowRetry: false, completion: completion)
                } else {
                    self.finishWithSetupFailure(message: L10n.errHelperSetupRequired, completion: completion)
                }
            }
        } else {
            executeToggle(disabled: disabled, allowRetry: true, completion: completion)
        }
    }
    
    private func finishWithSetupFailure(message: String, completion: ((Bool) -> Void)?) {
        isWorking = false
        statusMessage = message
        completion?(false)
        if let pending = pendingToggle {
            pendingToggle = nil
            pending.completion?(false)
        }
    }
    
    private func executeToggle(disabled: Bool, allowRetry: Bool = true, completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
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
                        self.finishWithSetupFailure(message: L10n.errSudoersRequired, completion: completion)
                        return
                    }
                    self.installHelperWithPrompt { [weak self] installed in
                        guard let self = self else {
                            completion?(false)
                            return
                        }
                        if installed {
                            self.executeToggle(disabled: disabled, allowRetry: false, completion: completion)
                        } else {
                            self.finishWithSetupFailure(message: L10n.errSudoersRequired, completion: completion)
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
                
                if let pending = self.pendingToggle {
                    self.pendingToggle = nil
                    if finalStatus == pending.disabled {
                        pending.completion?(true)
                    } else {
                        self.setTurboDisabled(pending.disabled, isUserInitiated: pending.isUserInitiated, completion: pending.completion)
                    }
                }
            }
        }
    }
}
