#if DEBUG
import Foundation

private final class PreviewCaffeinateProcessHandle: CaffeinateProcessHandle {
    var isRunning: Bool
    let processIdentifier: Int32
    var terminationHandler: (@Sendable () -> Void)?

    init(isRunning: Bool, processIdentifier: Int32 = 4242) {
        self.isRunning = isRunning
        self.processIdentifier = processIdentifier
    }

    func terminate() {
        guard isRunning else { return }
        isRunning = false
        terminationHandler?()
    }
}

private struct PreviewCaffeinateLauncher: CaffeinateProcessLaunching {
    func launch(arguments: [String]) throws -> any CaffeinateProcessHandle {
        PreviewCaffeinateProcessHandle(isRunning: true)
    }
}

extension CaffeinateController {
    static func previewInactive() -> CaffeinateController {
        previewController { controller in
            controller.durationComponents = DurationComponentsModel(hours: 1, minutes: 30)
        }
    }

    static func previewRunning() -> CaffeinateController {
        previewController { controller in
            controller.keepSystemAwake = true
            controller.declareUserActive = true
            controller.durationComponents = DurationComponentsModel(hours: 2, minutes: 15)
            controller.startFromDurationComponents()
        }
    }

    static func previewAttachValidation() -> CaffeinateController {
        previewController { controller in
            controller.attachToPID = true
            controller.attachPIDText = ""
            controller.isAdvancedExpanded = true
            controller.inlineErrorMessage = "Enter a valid positive PID before starting."
        }
    }

    static func previewAlertState() -> CaffeinateController {
        previewController { controller in
            controller.alertItem = MenuAlertItem(
                title: "Couldn’t start caffeinate",
                message: "Previewing the alert presentation state."
            )
        }
    }

    private static func previewController(configure: (CaffeinateController) -> Void) -> CaffeinateController {
        let suiteName = "CaffBarPreview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let controller = CaffeinateController(
            defaults: defaults,
            processLauncher: PreviewCaffeinateLauncher()
        )
        configure(controller)
        return controller
    }
}
#endif
