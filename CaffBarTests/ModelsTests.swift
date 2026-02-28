import XCTest
@testable import CaffBar

final class ModelsTests: XCTestCase {
    func testDurationComponentsTotalSeconds() {
        let value = DurationComponentsModel(days: 1, hours: 2, minutes: 3, seconds: 4)
        XCTAssertEqual(value.totalSeconds, 93_784)
    }

    func testDurationComponentsClampsToValidRanges() {
        let value = DurationComponentsModel(days: 99, hours: -1, minutes: 88, seconds: -2).clamped()
        XCTAssertEqual(value.days, 30)
        XCTAssertEqual(value.hours, 0)
        XCTAssertEqual(value.minutes, 59)
        XCTAssertEqual(value.seconds, 0)
    }

    func testPresetMappings() {
        XCTAssertEqual(CaffBarPreset.minutes15.seconds, 900)
        XCTAssertEqual(CaffBarPreset.hour1.seconds, 3_600)
        XCTAssertEqual(CaffBarPreset.hours3.seconds, 10_800)
        XCTAssertEqual(CaffBarPreset.night8.seconds, 28_800)
        XCTAssertNil(CaffBarPreset.infinity.seconds)

        XCTAssertEqual(CaffBarPreset.night8.compactButtonTitle, "8h")
        XCTAssertEqual(CaffBarPreset.infinity.compactButtonTitle, "∞")
    }

    func testPresetMetadataMappings() {
        XCTAssertEqual(CaffBarPreset.minutes15.id, "minutes15")
        XCTAssertEqual(CaffBarPreset.hour1.id, "hour1")
        XCTAssertEqual(CaffBarPreset.hours3.id, "hours3")
        XCTAssertEqual(CaffBarPreset.night8.id, "night8")
        XCTAssertEqual(CaffBarPreset.infinity.id, "infinity")

        XCTAssertEqual(CaffBarPreset.minutes15.title, "15m")
        XCTAssertEqual(CaffBarPreset.hour1.title, "1h")
        XCTAssertEqual(CaffBarPreset.hours3.title, "3h")
        XCTAssertEqual(CaffBarPreset.night8.title, "Night (8h)")
        XCTAssertEqual(CaffBarPreset.infinity.title, "∞ Until I stop")
    }

    func testMenuAlertItemGeneratesDistinctIDs() {
        let lhs = MenuAlertItem(title: "t", message: "m")
        let rhs = MenuAlertItem(title: "t", message: "m")
        XCTAssertNotEqual(lhs.id, rhs.id)
    }

    @MainActor
    func testBuildArgumentsIncludesExpectedFlagsAndDuration() {
        let options = CaffeinateOptions(
            keepDisplayAwake: true,
            keepIdleAwake: true,
            keepSystemAwake: false,
            declareUserActive: true,
            preventDiskSleep: true,
            attachToPID: false,
            pidValue: nil,
            durationSeconds: 120
        )

        XCTAssertEqual(
            CaffeinateController.buildArguments(from: options),
            ["-d", "-i", "-u", "-m", "-t", "120"]
        )
    }

    @MainActor
    func testBuildArgumentsUsesAttachPidAndOmitsDuration() {
        let options = CaffeinateOptions(
            keepDisplayAwake: true,
            keepIdleAwake: true,
            keepSystemAwake: false,
            declareUserActive: false,
            preventDiskSleep: false,
            attachToPID: true,
            pidValue: 1234,
            durationSeconds: 999
        )

        XCTAssertEqual(
            CaffeinateController.buildArguments(from: options),
            ["-d", "-i", "-w", "1234"]
        )
    }
}
