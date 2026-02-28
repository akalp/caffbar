import XCTest
import SwiftUI
import AppKit
@testable import CaffBar

@MainActor
final class CaffBarAppViewTests: XCTestCase {
    func testAppBodyBuilds() {
        let app = CaffBarApp()
        _ = app.body
        app.debugInvokeQuitApplication()
    }

    func testAppQuitHookIsCallableInTests() {
        var terminateCalled = false
        let app = CaffBarApp(terminator: { _ in terminateCalled = true })
        app.debugInvokeQuitApplication()
        XCTAssertTrue(terminateCalled)
    }

    func testPreviewEnvironmentSuppressesMenuBarScene() {
        let app = CaffBarApp(environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"])
        XCTAssertTrue(app.debugIsRunningForPreviews)
        _ = app.body
    }

    func testMenuPanelViewBuildsWhenInactive() {
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: FakeCaffeinateLauncher())
        let view = MenuPanelView(controller: controller, onQuit: {})
        render(view: view)
    }

    func testMenuPanelViewBuildsWhenActiveWithAdvancedExpanded() {
        let launcher = FakeCaffeinateLauncher()
        launcher.enqueueProcess(pid: 4200)
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        controller.durationComponents = DurationComponentsModel(hours: 1)
        controller.startFromDurationComponents()
        controller.isAdvancedExpanded = true
        controller.attachToPID = true
        controller.attachPIDText = "12345"
        controller.inlineErrorMessage = "Sample error"

        let view = MenuPanelView(controller: controller, onQuit: {})
        render(view: view)
    }

    func testMenuPanelViewBuildsWithAlertItem() {
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: FakeCaffeinateLauncher())
        controller.alertItem = MenuAlertItem(title: "Oops", message: "Try again")
        let view = MenuPanelView(controller: controller, onQuit: {})
        render(view: view)
    }

    func testPIDBindingFiltersNonDigits() {
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: FakeCaffeinateLauncher())
        let view = MenuPanelView(controller: controller, onQuit: {})
        view.debugPIDBinding.wrappedValue = "pid 12-34"
        XCTAssertEqual(controller.attachPIDText, "1234")
    }

    func testDurationSummaryCoversAllDisplayBranches() {
        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: FakeCaffeinateLauncher())

        controller.durationComponents = DurationComponentsModel(days: 1, hours: 2, minutes: 0, seconds: 0)
        render(view: MenuPanelView(controller: controller, onQuit: {}))

        controller.durationComponents = DurationComponentsModel(days: 0, hours: 0, minutes: 5, seconds: 9)
        render(view: MenuPanelView(controller: controller, onQuit: {}))

        controller.durationComponents = DurationComponentsModel(days: 0, hours: 0, minutes: 0, seconds: 12)
        render(view: MenuPanelView(controller: controller, onQuit: {}))
    }

    func testPresetAndQuitDebugTriggersAreWired() {
        let launcher = FakeCaffeinateLauncher()
        launcher.enqueueProcess(pid: 5001)
        launcher.enqueueProcess(pid: 5002)
        launcher.enqueueProcess(pid: 5003)
        launcher.enqueueProcess(pid: 5004)
        launcher.enqueueProcess(pid: 5005)

        let controller = CaffeinateController(defaults: makeIsolatedDefaults(), processLauncher: launcher)
        var didQuit = false
        let view = MenuPanelView(controller: controller, onQuit: { didQuit = true })

        view.debugTriggerPreset(.minutes15)
        view.debugTriggerPreset(.hour1)
        view.debugTriggerPreset(.hours3)
        view.debugTriggerPreset(.night8)
        view.debugTriggerPreset(.infinity)
        view.debugTriggerQuit()

        XCTAssertEqual(launcher.launchedArguments.count, 5)
        XCTAssertEqual(controller.lastStartKind, .infinity)
        XCTAssertTrue(didQuit)
    }

    func testDurationRowsBuild() {
        let strip = DurationStripRow(
            days: .constant(1),
            hours: .constant(2),
            minutes: .constant(3),
            seconds: .constant(4)
        )
        render(view: strip)

        let unit = DurationUnitEditor(label: "Seconds", shortLabel: "S", value: .constant(5), range: 0...59)
        render(view: unit)
    }

    private func render<V: View>(view: V) {
        let host = makeHost(view: view)
        host.layoutSubtreeIfNeeded()
        _ = host.fittingSize
    }

    private func makeHost<V: View>(view: V) -> NSHostingView<AnyView> {
        let host = NSHostingView(rootView: AnyView(view.frame(width: 344)))
        host.layoutSubtreeIfNeeded()
        _ = host.fittingSize
        return host
    }
}
