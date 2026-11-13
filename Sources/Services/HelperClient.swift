import Foundation

enum HelperClient {
    static let helperPath = "/Library/PrivilegedHelperTools/turbocontrol-helper"
    static let legacyHelperPath = "/usr/local/bin/turbocontrol-helper"
    
    typealias Result = ProcessRunner.Result
    
    static var isHelperInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: helperPath)
    }
    
    /// Executes the privileged helper via `sudo -n` with a protective timeout.
    static func run(_ arguments: [String], timeout: TimeInterval = 10.0) -> Result {
        guard isHelperInstalled else {
            return Result(exitCode: -1, stdout: "", stderr: "Helper not installed", timedOut: false)
        }
        let result = ProcessRunner.run("/usr/bin/sudo", arguments: ["-n", helperPath] + arguments, timeout: timeout)
        return Result(
            exitCode: result.exitCode,
            stdout: result.stdout.trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: result.stderr,
            timedOut: result.timedOut
        )
    }
}
