import SwiftUI
import AppKit

@MainActor
@main
struct CaffBarApp: App {
    @StateObject private var controller = CaffeinateController()
    private let terminator: @MainActor (NSApplication) -> Void
    private let environment: [String: String]

    init() {
        self.environment = ProcessInfo.processInfo.environment
        self.terminator = Self.defaultTerminator
    }

    init(terminator: @MainActor @escaping (NSApplication) -> Void) {
        self.environment = ProcessInfo.processInfo.environment
        self.terminator = terminator
    }

    init(environment: [String: String]) {
        self.environment = environment
        self.terminator = Self.defaultTerminator
    }

    init(environment: [String: String], terminator: @MainActor @escaping (NSApplication) -> Void) {
        self.environment = environment
        self.terminator = terminator
    }

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(!isRunningForPreviews)) {
            MenuPanelView(controller: controller, onQuit: quitApplication)
        } label: {
            Image(systemName: controller.isRunning ? "cup.and.saucer.fill" : "cup.and.saucer")
            .font(.system(size: 12, weight: .semibold))
            .accessibilityLabel(controller.menuBarHoverText)
            .help(controller.menuBarHoverText)
        }
        .menuBarExtraStyle(.window)
    }

    private func quitApplication() {
        terminator(NSApplication.shared)
    }

    private var isRunningForPreviews: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private static func defaultTerminator(_ app: NSApplication) {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }
        app.terminate(nil)
    }

    func debugInvokeQuitApplication() {
        quitApplication()
    }

    var debugIsRunningForPreviews: Bool {
        isRunningForPreviews
    }
}
