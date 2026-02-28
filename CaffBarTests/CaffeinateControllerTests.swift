import XCTest
@testable import CaffBar

@MainActor
final class CaffeinateControllerTests: XCTestCase {
    func testDefaultsOnFirstLaunchMatchUXSpec() {
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: FakeCaffeinateLauncher())

        XCTAssertFalse(controller.isRunning)
        XCTAssertTrue(controller.keepDisplayAwake)
        XCTAssertTrue(controller.keepIdleAwake)
        XCTAssertFalse(controller.keepSystemAwake)
        XCTAssertFalse(controller.declareUserActive)
        XCTAssertFalse(controller.preventDiskSleep)
        XCTAssertFalse(controller.attachToPID)
        XCTAssertEqual(controller.durationComponents, DurationComponentsModel())
        XCTAssertEqual(controller.remainingText, "∞")
        XCTAssertEqual(controller.menuBarHoverText, "CaffBar")
    }

    func testMutationsPersistAndRestoreAcrossControllerInstances() {
        let defaults = makeIsolatedDefaults()
        let launcher = FakeCaffeinateLauncher()
        var controller: CaffeinateController? = CaffeinateController(defaults: defaults, processLauncher: launcher)

        controller?.keepSystemAwake = true
        controller?.declareUserActive = true
        controller?.preventDiskSleep = true
        controller?.attachToPID = true
        controller?.attachPIDText = "4242"
        controller?.durationComponents = DurationComponentsModel(days: 1, hours: 2, minutes: 3, seconds: 4)

        controller = nil

        let restored = CaffeinateController(defaults: defaults, processLauncher: FakeCaffeinateLauncher())
        XCTAssertTrue(restored.keepSystemAwake)
        XCTAssertTrue(restored.declareUserActive)
        XCTAssertTrue(restored.preventDiskSleep)
        XCTAssertTrue(restored.attachToPID)
        XCTAssertEqual(restored.attachPIDText, "4242")
        XCTAssertEqual(restored.durationComponents, DurationComponentsModel(days: 1, hours: 2, minutes: 3, seconds: 4))
        XCTAssertFalse(restored.isRunning, "Settings should restore but app should remain inactive on launch")
    }

    func testSanitizePIDTextKeepsOnlyDigits() {
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: FakeCaffeinateLauncher())
        controller.attachPIDText = "a1b2-3 4"
        controller.sanitizePIDText()
        XCTAssertEqual(controller.attachPIDText, "1234")
    }

    func testDurationBindingClampsIntoRange() {
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: FakeCaffeinateLauncher())
        let hoursBinding = controller.durationBinding(\.hours, range: 0...23)
        hoursBinding.wrappedValue = 99
        XCTAssertEqual(controller.durationComponents.hours, 23)
        hoursBinding.wrappedValue = -5
        XCTAssertEqual(controller.durationComponents.hours, 0)
    }

    func testDisplayAndIdleTogglesPersistWhenChanged() {
        let defaults = makeIsolatedDefaults()
        let controller = CaffeinateController(defaults: defaults, processLauncher: FakeCaffeinateLauncher())
        controller.keepDisplayAwake = false
        controller.keepIdleAwake = false

        XCTAssertEqual(defaults.object(forKey: "keepDisplayAwake") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "keepIdleAwake") as? Bool, false)
    }

    func testDurationComponentsDirectAssignmentClampsModel() {
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: FakeCaffeinateLauncher())
        controller.durationComponents = DurationComponentsModel(days: 90, hours: -2, minutes: 99, seconds: -1)
        XCTAssertEqual(controller.durationComponents, DurationComponentsModel(days: 30, hours: 0, minutes: 59, seconds: 0))
    }

    func testStartFromDurationComponentsZeroTreatsAsInfinity() {
        let launcher = FakeCaffeinateLauncher()
        let process = launcher.enqueueProcess(pid: 3001)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.durationComponents = DurationComponentsModel(days: 0, hours: 0, minutes: 0, seconds: 0)

        controller.startFromDurationComponents()

        XCTAssertTrue(controller.isRunning)
        XCTAssertNil(controller.endsAt)
        XCTAssertEqual(controller.lastStartKind, .infinity)
        XCTAssertEqual(controller.remainingText, "∞")
        XCTAssertEqual(launcher.launchedArguments.last, ["-d", "-i"])
        XCTAssertEqual(process.terminateCallCount, 0)
    }

    func testStartPresetBuildsExpectedArgumentsAndPersistsLastPreset() {
        let defaults = makeIsolatedDefaults()
        let launcher = FakeCaffeinateLauncher()
        launcher.enqueueProcess(pid: 3002)
        let controller = CaffeinateController(defaults: defaults, processLauncher: launcher)
        controller.keepSystemAwake = true

        controller.startPreset(.hour1)

        XCTAssertTrue(controller.isRunning)
        XCTAssertEqual(controller.lastStartKind, .preset)
        XCTAssertNotNil(controller.endsAt)
        XCTAssertEqual(launcher.launchedArguments.last, ["-d", "-i", "-s", "-t", "3600"])
        XCTAssertEqual(defaults.string(forKey: "lastPreset"), CaffBarPreset.hour1.rawValue)
    }

    func testStartPresetInfinityUsesInfinityKind() {
        let launcher = FakeCaffeinateLauncher()
        launcher.enqueueProcess(pid: 3501)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)

        controller.startPreset(.infinity)

        XCTAssertTrue(controller.isRunning)
        XCTAssertEqual(controller.lastStartKind, .infinity)
        XCTAssertNil(controller.endsAt)
        XCTAssertEqual(launcher.launchedArguments.last, ["-d", "-i"])
    }

    func testAttachPIDRequiresPositiveInteger() {
        let launcher = FakeCaffeinateLauncher()
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.attachToPID = true
        controller.attachPIDText = "0"

        controller.startFromDurationComponents()

        XCTAssertFalse(controller.isRunning)
        XCTAssertEqual(controller.inlineErrorMessage, "Enter a valid positive PID before starting.")
        XCTAssertTrue(launcher.launchedArguments.isEmpty)
    }

    func testNoKeepAwakeModeSelectedShowsValidationError() {
        let launcher = FakeCaffeinateLauncher()
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.keepDisplayAwake = false
        controller.keepIdleAwake = false
        controller.durationComponents = DurationComponentsModel(minutes: 10)

        controller.startFromDurationComponents()

        XCTAssertFalse(controller.isRunning)
        XCTAssertEqual(controller.inlineErrorMessage, "Select at least one keep-awake mode before starting.")
        XCTAssertTrue(launcher.launchedArguments.isEmpty)
    }

    func testAttachPIDValidIgnoresDurationAndUsesAttachKind() {
        let launcher = FakeCaffeinateLauncher()
        launcher.enqueueProcess(pid: 3003)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.attachToPID = true
        controller.attachPIDText = "12345"
        controller.durationComponents = DurationComponentsModel(seconds: 9)

        controller.startFromDurationComponents()

        XCTAssertTrue(controller.isRunning)
        XCTAssertNil(controller.endsAt)
        XCTAssertEqual(controller.lastStartKind, .attachPid)
        XCTAssertEqual(launcher.launchedArguments.last, ["-d", "-i", "-w", "12345"])
    }

    func testDeclareUserActiveAloneRequiresTimedOrPersistentMode() {
        let launcher = FakeCaffeinateLauncher()
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.keepDisplayAwake = false
        controller.keepIdleAwake = false
        controller.declareUserActive = true
        controller.durationComponents = DurationComponentsModel()

        controller.startFromDurationComponents()

        XCTAssertFalse(controller.isRunning)
        XCTAssertEqual(controller.inlineErrorMessage, "Declare user active needs a timed duration or another keep-awake mode.")
        XCTAssertTrue(launcher.launchedArguments.isEmpty)
    }

    func testDeclareUserActiveAloneWithTimedDurationLaunchesExpectedArguments() {
        let launcher = FakeCaffeinateLauncher()
        launcher.enqueueProcess(pid: 3022)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.keepDisplayAwake = false
        controller.keepIdleAwake = false
        controller.declareUserActive = true
        controller.durationComponents = DurationComponentsModel(minutes: 2)

        controller.startFromDurationComponents()

        XCTAssertTrue(controller.isRunning)
        XCTAssertEqual(launcher.launchedArguments.last, ["-u", "-t", "120"])
    }

    func testAttachPIDWithOnlyDeclareUserActiveShowsValidationError() {
        let launcher = FakeCaffeinateLauncher()
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.keepDisplayAwake = false
        controller.keepIdleAwake = false
        controller.declareUserActive = true
        controller.attachToPID = true
        controller.attachPIDText = "12345"

        controller.startFromDurationComponents()

        XCTAssertFalse(controller.isRunning)
        XCTAssertEqual(controller.inlineErrorMessage, "Declare user active needs another keep-awake mode when attaching to a PID.")
        XCTAssertTrue(launcher.launchedArguments.isEmpty)
    }

    func testLauncherErrorShowsFriendlyAlert() {
        let launcher = FakeCaffeinateLauncher()
        launcher.nextError = FakeLauncherError.launchFailed
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.durationComponents = DurationComponentsModel(seconds: 1)

        controller.startFromDurationComponents()

        XCTAssertFalse(controller.isRunning)
        XCTAssertEqual(controller.alertItem?.title, "Couldn’t start caffeinate")
        XCTAssertNotNil(controller.alertItem?.message)
    }

    func testDismissAlertClearsAlertItem() {
        let launcher = FakeCaffeinateLauncher()
        launcher.nextError = FakeLauncherError.launchFailed
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.startFromDurationComponents()
        XCTAssertNotNil(controller.alertItem)

        controller.dismissAlert()
        XCTAssertNil(controller.alertItem)
    }

    func testStopTerminatesProcessAndClearsRuntimeState() {
        let launcher = FakeCaffeinateLauncher()
        let process = launcher.enqueueProcess(pid: 3004)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.durationComponents = DurationComponentsModel(seconds: 20)
        controller.startFromDurationComponents()

        controller.stop()

        XCTAssertEqual(process.terminateCallCount, 1)
        XCTAssertFalse(controller.isRunning)
        XCTAssertNil(controller.startedAt)
        XCTAssertNil(controller.endsAt)
        XCTAssertFalse(controller.debugHasActiveTimer)
        XCTAssertFalse(controller.debugIsRunningProcessPresent)
    }

    func testRestartTerminatesExistingProcessBeforeLaunchingNext() {
        let launcher = FakeCaffeinateLauncher()
        let first = launcher.enqueueProcess(pid: 3010)
        _ = launcher.enqueueProcess(pid: 3011)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)

        controller.startPreset(.minutes15)
        controller.startPreset(.hour1)

        XCTAssertEqual(first.terminateCallCount, 1)
        XCTAssertEqual(launcher.launchedArguments.count, 2)
        XCTAssertEqual(controller.lastStartKind, .preset)
    }

    func testTerminationHandlerClearsStateWhenProcessExits() async {
        let launcher = FakeCaffeinateLauncher()
        let process = launcher.enqueueProcess(pid: 3012)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.startPreset(.minutes15)
        XCTAssertTrue(controller.isRunning)

        process.simulateExit()
        await Task.yield()

        XCTAssertFalse(controller.isRunning)
        XCTAssertNil(controller.endsAt)
        XCTAssertFalse(controller.debugIsRunningProcessPresent)
    }

    func testCountdownUsesCeilingToAvoidInitialTwoSecondSkip() {
        let launcher = FakeCaffeinateLauncher()
        launcher.enqueueProcess(pid: 3013)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.durationComponents = DurationComponentsModel(seconds: 5)
        controller.startFromDurationComponents()

        let start = try! XCTUnwrap(controller.startedAt)
        controller.handleTimerTick(now: start.addingTimeInterval(1.01))

        XCTAssertEqual(controller.remainingText, "4s")
        XCTAssertEqual(controller.menuBarRemainingText, "4s")
    }

    func testFooterPrimaryStopsWhenRunning() {
        let launcher = FakeCaffeinateLauncher()
        let process = launcher.enqueueProcess(pid: 3014)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.durationComponents = DurationComponentsModel(seconds: 3)
        controller.startFooterPrimary()
        XCTAssertTrue(controller.isRunning)

        controller.startFooterPrimary()

        XCTAssertEqual(process.terminateCallCount, 1)
        XCTAssertFalse(controller.isRunning)
    }

    func testTimedSessionArmsTimer() {
        let launcher = FakeCaffeinateLauncher()
        launcher.enqueueProcess(pid: 3023)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.durationComponents = DurationComponentsModel(seconds: 3)

        controller.startFromDurationComponents()

        XCTAssertTrue(controller.debugHasActiveTimer)
    }

    func testInfiniteSessionDoesNotArmTimer() {
        let launcher = FakeCaffeinateLauncher()
        launcher.enqueueProcess(pid: 3024)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)

        controller.startFromDurationComponents()

        XCTAssertFalse(controller.debugHasActiveTimer)
    }

    func testAttachPIDSessionDoesNotArmTimer() {
        let launcher = FakeCaffeinateLauncher()
        launcher.enqueueProcess(pid: 3025)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.attachToPID = true
        controller.attachPIDText = "12345"

        controller.startFromDurationComponents()

        XCTAssertFalse(controller.debugHasActiveTimer)
    }

    func testAttachToggleOffClearsInlineError() {
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: FakeCaffeinateLauncher())
        controller.attachToPID = true
        controller.inlineErrorMessage = "Invalid PID"

        controller.attachToPID = false

        XCTAssertNil(controller.inlineErrorMessage)
    }

    func testMenuBarHoverTextShowsRunningState() {
        let launcher = FakeCaffeinateLauncher()
        launcher.enqueueProcess(pid: 3015)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.durationComponents = DurationComponentsModel(minutes: 2)

        controller.startFromDurationComponents()

        XCTAssertTrue(controller.menuBarHoverText.hasPrefix("CaffBar • ON (Remaining: "))
    }

    func testTimerRunLoopPathUpdatesCountdown() {
        let launcher = FakeCaffeinateLauncher()
        launcher.enqueueProcess(pid: 3016)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.durationComponents = DurationComponentsModel(seconds: 3)
        controller.startFromDurationComponents()
        let before = controller.remainingText

        RunLoop.main.run(until: Date().addingTimeInterval(1.2))

        XCTAssertNotEqual(controller.remainingText, before)
    }

    func testRemainingFormattingCoversDayAndCompactDayOnlyBranches() {
        let launcher = FakeCaffeinateLauncher()
        launcher.enqueueProcess(pid: 3017)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.durationComponents = DurationComponentsModel(days: 1)

        controller.startFromDurationComponents()

        XCTAssertTrue(controller.remainingText.hasPrefix("1d "))
        XCTAssertEqual(controller.menuBarRemainingText, "1d")
    }

    func testCompactDurationFormatsDayHourBranch() {
        let launcher = FakeCaffeinateLauncher()
        launcher.enqueueProcess(pid: 3018)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.durationComponents = DurationComponentsModel(days: 1, hours: 2)

        controller.startFromDurationComponents()

        XCTAssertTrue(controller.menuBarRemainingText.hasPrefix("1d2h"))
    }

    func testCompactDurationFormatsHourAndMinuteBranches() {
        let launcher = FakeCaffeinateLauncher()
        launcher.enqueueProcess(pid: 3020)
        launcher.enqueueProcess(pid: 3021)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)

        controller.durationComponents = DurationComponentsModel(hours: 2, minutes: 5)
        controller.startFromDurationComponents()
        XCTAssertTrue(controller.menuBarRemainingText.hasPrefix("2h5m"))

        controller.durationComponents = DurationComponentsModel(minutes: 45)
        controller.startFromDurationComponents()
        XCTAssertEqual(controller.menuBarRemainingText, "45m")
    }

    func testHandleTimerTickDoesNotStopWhileProcessStillRunningThenStops() {
        let launcher = FakeCaffeinateLauncher()
        let process = launcher.enqueueProcess(pid: 3019)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.durationComponents = DurationComponentsModel(seconds: 1)
        controller.startFromDurationComponents()
        let started = try! XCTUnwrap(controller.startedAt)

        controller.handleTimerTick(now: started.addingTimeInterval(2))
        XCTAssertTrue(controller.isRunning, "Should remain running while process still reports running")

        process.isRunning = false
        controller.handleTimerTick(now: started.addingTimeInterval(3))
        XCTAssertFalse(controller.isRunning, "Should clear runtime state after duration end when process is no longer running")
    }
}
