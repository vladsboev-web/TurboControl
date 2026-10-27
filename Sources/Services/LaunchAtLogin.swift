import Foundation
import ServiceManagement

enum LaunchAtLogin {
    private static let agentLabel = "com.turbocontrol.app.launchagent"
    
    private static var plistURL: URL {
        let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        return launchAgentsDir.appendingPathComponent("\(agentLabel).plist")
    }
    
    static func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                return
            } catch {
                // Fallback to LaunchAgent plist if SMAppService errors
            }
        }
        
        let fileManager = FileManager.default
        let launchAgentsDir = plistURL.deletingLastPathComponent()
        
        if enabled {
            try? fileManager.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
            
            let appPath = Bundle.main.bundleURL.path
            let plistContent: [String: Any] = [
                "Label": agentLabel,
                "ProgramArguments": ["/usr/bin/open", "-a", appPath],
                "RunAtLoad": true,
                "ProcessType": "Interactive"
            ]
            
            if let data = try? PropertyListSerialization.data(fromPropertyList: plistContent, format: .xml, options: 0) {
                try? data.write(to: plistURL)
            }
        } else {
            try? fileManager.removeItem(at: plistURL)
        }
    }
    
    static func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return FileManager.default.fileExists(atPath: plistURL.path)
    }
}
