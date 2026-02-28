import XCTest
@testable import CaffBar

final class ProcessLauncherTests: XCTestCase {
    func testFoundationProcessHandleReflectsProcessStateAndTerminates() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["5"]
        try process.run()

        let handle = FoundationCaffeinateProcessHandle(process: process)
        XCTAssertTrue(handle.isRunning)
        XCTAssertGreaterThan(handle.processIdentifier, 0)

        let exited = expectation(description: "process exits")
        handle.terminationHandler = {
            exited.fulfill()
        }

        handle.terminate()
        wait(for: [exited], timeout: 2.0)
        XCTAssertFalse(handle.isRunning)
    }

    func testSystemLauncherCanLaunchAndTerminateCaffeinate() throws {
        let launcher = SystemCaffeinateLauncher()
        let handle = try launcher.launch(arguments: ["-t", "30"])

        XCTAssertTrue(handle.isRunning)
        XCTAssertGreaterThan(handle.processIdentifier, 0)

        let exited = expectation(description: "caffeinate exits")
        handle.terminationHandler = {
            exited.fulfill()
        }

        handle.terminate()
        wait(for: [exited], timeout: 2.0)
        XCTAssertFalse(handle.isRunning)
    }
}
