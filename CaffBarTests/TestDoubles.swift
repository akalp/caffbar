import Foundation
@testable import CaffBar

final class FakeCaffeinateProcess: CaffeinateProcessHandle {
    var isRunning: Bool
    let processIdentifier: Int32
    var terminationHandler: (@Sendable () -> Void)?
    private(set) var terminateCallCount = 0

    init(processIdentifier: Int32, isRunning: Bool = true) {
        self.processIdentifier = processIdentifier
        self.isRunning = isRunning
    }

    func terminate() {
        terminateCallCount += 1
        isRunning = false
    }

    func simulateExit() {
        isRunning = false
        terminationHandler?()
    }
}

enum FakeLauncherError: Error {
    case launchFailed
}

final class FakeCaffeinateLauncher: CaffeinateProcessLaunching {
    private(set) var launchedArguments: [[String]] = []
    var nextError: Error?
    var processesToReturn: [FakeCaffeinateProcess] = []
    private var nextPID: Int32 = 2000

    @discardableResult
    func enqueueProcess(pid: Int32? = nil, isRunning: Bool = true) -> FakeCaffeinateProcess {
        let process = FakeCaffeinateProcess(processIdentifier: pid ?? nextPID, isRunning: isRunning)
        nextPID += 1
        processesToReturn.append(process)
        return process
    }

    func launch(arguments: [String]) throws -> any CaffeinateProcessHandle {
        launchedArguments.append(arguments)
        if let nextError {
            self.nextError = nil
            throw nextError
        }
        if processesToReturn.isEmpty {
            return enqueueProcess()
        }
        return processesToReturn.removeFirst()
    }
}

func makeIsolatedDefaults(testName: String = #function) -> UserDefaults {
    let suiteName = "CaffBarTests.\(testName).\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
