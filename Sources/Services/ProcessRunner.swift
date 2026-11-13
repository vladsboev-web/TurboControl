import Foundation
import Darwin

enum ProcessRunner {
    struct Result {
        let exitCode: Int32
        let stdout: String
        let stderr: String
        let timedOut: Bool
        
        var succeeded: Bool { !timedOut && exitCode == 0 }
    }
    
    /// Executes a process synchronously with concurrent stdout/stderr reading and a protective timeout.
    static func run(_ executablePath: String, arguments: [String] = [], timeout: TimeInterval = 10.0) -> Result {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executablePath)
        task.arguments = arguments
        
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
        
        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""
        let exitCode = timedOut ? -1 : task.terminationStatus
        
        return Result(exitCode: exitCode, stdout: stdout, stderr: stderr, timedOut: timedOut)
    }
}
