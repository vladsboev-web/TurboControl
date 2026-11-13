import Foundation
import Darwin

enum HelperClient {
    static let helperPath = "/Library/PrivilegedHelperTools/turbocontrol-helper"
    static let legacyHelperPath = "/usr/local/bin/turbocontrol-helper"
    
    struct Result {
        let exitCode: Int32
        let stdout: String
        let stderr: String
        let timedOut: Bool
        
        var succeeded: Bool { !timedOut && exitCode == 0 }
    }
    
    static var isHelperInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: helperPath)
    }
    
    /// Executes the privileged helper via `sudo -n` with a protective timeout.
    static func run(_ arguments: [String], timeout: TimeInterval = 10.0) -> Result {
        guard isHelperInstalled else {
            return Result(exitCode: -1, stdout: "", stderr: "Helper not installed", timedOut: false)
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        task.arguments = ["-n", helperPath] + arguments
        
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        
        let sem = DispatchSemaphore(value: 0)
        task.terminationHandler = { _ in
            sem.signal()
        }
        
        do {
            try task.run()
        } catch {
            task.terminationHandler = nil
            return Result(exitCode: -1, stdout: "", stderr: error.localizedDescription, timedOut: false)
        }
        
        var outData = Data()
        var errData = Data()
        let readGroup = DispatchGroup()
        
        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }
        
        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }
        
        let waitResult = sem.wait(timeout: .now() + timeout)
        var timedOut = false
        if waitResult == .timedOut {
            timedOut = true
            task.terminate()
            if sem.wait(timeout: .now() + 0.5) == .timedOut {
                kill(task.processIdentifier, SIGKILL)
                _ = sem.wait(timeout: .now() + 0.5)
            }
        }
        
        _ = readGroup.wait(timeout: .now() + 1.0)
        
        let stdout = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""
        let exitCode = timedOut ? -1 : task.terminationStatus
        
        return Result(exitCode: exitCode, stdout: stdout, stderr: stderr, timedOut: timedOut)
    }
}
