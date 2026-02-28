import Foundation
import Combine
import SwiftUI

protocol CaffeinateProcessHandle: AnyObject {
    var isRunning: Bool { get }
    var processIdentifier: Int32 { get }
    var terminationHandler: (@Sendable () -> Void)? { get set }
    func terminate()
}

protocol CaffeinateProcessLaunching {
    func launch(arguments: [String]) throws -> any CaffeinateProcessHandle
}

final class FoundationCaffeinateProcessHandle: CaffeinateProcessHandle {
    private let process: Process
    var terminationHandler: (@Sendable () -> Void)? {
        didSet {
            process.terminationHandler = { [weak self] _ in
                self?.terminationHandler?()
            }
        }
    }

    init(process: Process) {
        self.process = process
    }

    var isRunning: Bool { process.isRunning }
    var processIdentifier: Int32 { process.processIdentifier }

    func terminate() {
        process.terminate()
    }
}

struct SystemCaffeinateLauncher: CaffeinateProcessLaunching {
    func launch(arguments: [String]) throws -> any CaffeinateProcessHandle {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = arguments
        try process.run()
        return FoundationCaffeinateProcessHandle(process: process)
    }
}

@MainActor
final class CaffeinateController: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var startedAt: Date?
    @Published private(set) var endsAt: Date?
    @Published private(set) var lastStartKind: CaffeinateStartKind?

    @Published var keepDisplayAwake: Bool { didSet { persistBool(keepDisplayAwake, key: Keys.keepDisplayAwake) } }
    @Published var keepIdleAwake: Bool { didSet { persistBool(keepIdleAwake, key: Keys.keepIdleAwake) } }
    @Published var keepSystemAwake: Bool { didSet { persistBool(keepSystemAwake, key: Keys.keepSystemAwake) } }
    @Published var declareUserActive: Bool { didSet { persistBool(declareUserActive, key: Keys.declareUserActive) } }
    @Published var preventDiskSleep: Bool { didSet { persistBool(preventDiskSleep, key: Keys.preventDiskSleep) } }
    @Published var attachToPID: Bool { didSet { persistBool(attachToPID, key: Keys.attachToPID); if attachToPID == false { inlineErrorMessage = nil } } }
    @Published var attachPIDText: String { didSet { persistString(attachPIDText, key: Keys.attachPIDText) } }
    @Published var durationComponents: DurationComponentsModel {
        didSet {
            let clamped = durationComponents.clamped()
            if clamped != durationComponents {
                durationComponents = clamped
                return
            }
            persistDurationComponents(clamped)
        }
    }
    @Published var isAdvancedExpanded = false
    @Published var inlineErrorMessage: String?
    @Published var alertItem: MenuAlertItem?

    @Published private var now = Date()

    var remainingText: String {
        guard isRunning else { return "∞" }
        guard endsAt != nil else { return "∞" }
        return Self.formatDuration(timedRemainingSeconds)
    }

    var menuBarRemainingText: String {
        guard isRunning else { return "" }
        guard endsAt != nil else { return "∞" }
        return Self.formatCompactDuration(timedRemainingSeconds)
    }

    var menuBarHoverText: String {
        if isRunning {
            return "CaffBar • ON (Remaining: \(remainingText))"
        }
        return "CaffBar"
    }

    private var timedRemainingSeconds: Int {
        guard let endsAt else { return 0 }
        // Use ceiling to avoid visually skipping the first second due to timer scheduling jitter.
        let remaining = endsAt.timeIntervalSince(now)
        return max(0, Int(remaining.rounded(.up)))
    }

    private enum Keys {
        static let keepDisplayAwake = "keepDisplayAwake"
        static let keepIdleAwake = "keepIdleAwake"
        static let keepSystemAwake = "keepSystemAwake"
        static let declareUserActive = "declareUserActive"
        static let preventDiskSleep = "preventDiskSleep"
        static let attachToPID = "attachToPID"
        static let attachPIDText = "attachPIDText"
        static let durationDays = "durationDays"
        static let durationHours = "durationHours"
        static let durationMinutes = "durationMinutes"
        static let durationSeconds = "durationSeconds"
        static let lastPreset = "lastPreset"
    }

    private let defaults: UserDefaults
    private let processLauncher: any CaffeinateProcessLaunching
    private var caffeinateProcess: (any CaffeinateProcessHandle)?
    private var timer: Timer?
    private var isRestoring = true

    init(defaults: UserDefaults = .standard, processLauncher: any CaffeinateProcessLaunching = SystemCaffeinateLauncher()) {
        self.defaults = defaults
        self.processLauncher = processLauncher

        self.keepDisplayAwake = defaults.object(forKey: Keys.keepDisplayAwake) as? Bool ?? true
        self.keepIdleAwake = defaults.object(forKey: Keys.keepIdleAwake) as? Bool ?? true
        self.keepSystemAwake = defaults.object(forKey: Keys.keepSystemAwake) as? Bool ?? false
        self.declareUserActive = defaults.object(forKey: Keys.declareUserActive) as? Bool ?? false
        self.preventDiskSleep = defaults.object(forKey: Keys.preventDiskSleep) as? Bool ?? false
        self.attachToPID = defaults.object(forKey: Keys.attachToPID) as? Bool ?? false
        self.attachPIDText = defaults.string(forKey: Keys.attachPIDText) ?? ""

        let restoredDuration = DurationComponentsModel(
            days: defaults.object(forKey: Keys.durationDays) as? Int ?? 0,
            hours: defaults.object(forKey: Keys.durationHours) as? Int ?? 0,
            minutes: defaults.object(forKey: Keys.durationMinutes) as? Int ?? 0,
            seconds: defaults.object(forKey: Keys.durationSeconds) as? Int ?? 0
        ).clamped()
        self.durationComponents = restoredDuration

        self.isRestoring = false
        self.persistDurationComponents(restoredDuration)
    }

    deinit {
        timer?.invalidate()
        if let process = caffeinateProcess, process.isRunning {
            process.terminate()
        }
    }

    func startPreset(_ preset: CaffBarPreset) {
        defaults.set(preset.rawValue, forKey: Keys.lastPreset)
        start(durationSeconds: preset.seconds, requestedKind: preset.seconds == nil ? .infinity : .preset)
    }

    func startFromDurationComponents() {
        let total = durationComponents.totalSeconds
        let durationSeconds = total > 0 ? total : nil
        let kind: CaffeinateStartKind = total > 0 ? .durationComponents : .infinity
        start(durationSeconds: durationSeconds, requestedKind: kind)
    }

    func startFooterPrimary() {
        if isRunning {
            stop()
        } else {
            startFromDurationComponents()
        }
    }

    func stop() {
        inlineErrorMessage = nil
        timer?.invalidate()
        timer = nil

        if let process = caffeinateProcess, process.isRunning {
            process.terminate()
        }

        caffeinateProcess = nil
        clearRuntimeState()
    }

    func dismissAlert() {
        alertItem = nil
    }

    func sanitizePIDText() {
        let filtered = attachPIDText.filter(\.isNumber)
        if filtered != attachPIDText {
            attachPIDText = filtered
        }
    }

    func durationBinding(_ keyPath: WritableKeyPath<DurationComponentsModel, Int>, range: ClosedRange<Int>) -> Binding<Int> {
        Binding(
            get: { self.durationComponents[keyPath: keyPath] },
            set: { newValue in
                var updated = self.durationComponents
                updated[keyPath: keyPath] = min(max(newValue, range.lowerBound), range.upperBound)
                self.durationComponents = updated
            }
        )
    }

    private func start(durationSeconds: Int?, requestedKind: CaffeinateStartKind) {
        inlineErrorMessage = nil

        let effectivePID: Int?
        if attachToPID {
            guard let pid = Int(attachPIDText), pid > 0 else {
                inlineErrorMessage = "Enter a valid positive PID before starting."
                return
            }
            effectivePID = pid
        } else {
            effectivePID = nil
        }

        if let validationError = validateModeSelection(durationSeconds: durationSeconds, attachPID: effectivePID) {
            inlineErrorMessage = validationError
            return
        }

        let options = CaffeinateOptions(
            keepDisplayAwake: keepDisplayAwake,
            keepIdleAwake: keepIdleAwake,
            keepSystemAwake: keepSystemAwake,
            declareUserActive: declareUserActive,
            preventDiskSleep: preventDiskSleep,
            attachToPID: attachToPID,
            pidValue: effectivePID,
            durationSeconds: attachToPID ? nil : durationSeconds
        )

        if let existing = caffeinateProcess, existing.isRunning {
            existing.terminate()
        }
        caffeinateProcess = nil

        let arguments = Self.buildArguments(from: options)
        let process: any CaffeinateProcessHandle

        do {
            process = try processLauncher.launch(arguments: arguments)
        } catch {
            showStartError(error)
            return
        }

        let launchDate = Date()
        let launchedPID = process.processIdentifier
        process.terminationHandler = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.caffeinateProcess?.processIdentifier == launchedPID else { return }
                self.caffeinateProcess = nil
                self.clearRuntimeState()
            }
        }

        caffeinateProcess = process
        isRunning = true
        startedAt = launchDate
        endsAt = options.durationSeconds.map { launchDate.addingTimeInterval(TimeInterval($0)) }
        lastStartKind = options.attachToPID ? .attachPid : requestedKind
        now = launchDate
        startTimerIfNeeded()
    }

    static func buildArguments(from options: CaffeinateOptions) -> [String] {
        var arguments: [String] = []

        if options.keepDisplayAwake { arguments.append("-d") }
        if options.keepIdleAwake { arguments.append("-i") }
        if options.keepSystemAwake { arguments.append("-s") }
        if options.declareUserActive { arguments.append("-u") }
        if options.preventDiskSleep { arguments.append("-m") }

        if options.attachToPID, let pid = options.pidValue {
            arguments.append(contentsOf: ["-w", String(pid)])
        } else if let seconds = options.durationSeconds, seconds > 0 {
            arguments.append(contentsOf: ["-t", String(seconds)])
        }

        return arguments
    }

    private func startTimerIfNeeded() {
        timer?.invalidate()
        guard endsAt != nil else {
            timer = nil
            return
        }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleTimerTick()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func handleTimerTick(now overrideNow: Date? = nil) {
        now = overrideNow ?? Date()
        if let endsAt, now >= endsAt, caffeinateProcess?.isRunning != true {
            caffeinateProcess = nil
            clearRuntimeState()
        }
    }

    var debugIsRunningProcessPresent: Bool {
        caffeinateProcess != nil
    }

    var debugHasActiveTimer: Bool {
        timer != nil
    }

    private func clearRuntimeState() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        startedAt = nil
        endsAt = nil
        now = Date()
    }

    private func showStartError(_ error: Error) {
        alertItem = MenuAlertItem(
            title: "Couldn’t start caffeinate",
            message: "\(error.localizedDescription)\n\nTry stopping any existing session and starting again."
        )
    }

    private func validateModeSelection(durationSeconds: Int?, attachPID: Int?) -> String? {
        let hasPersistentAssertion =
            keepDisplayAwake ||
            keepIdleAwake ||
            keepSystemAwake ||
            preventDiskSleep

        if hasPersistentAssertion {
            return nil
        }

        if declareUserActive {
            if durationSeconds != nil {
                return nil
            }
            if attachPID != nil {
                return "Declare user active needs another keep-awake mode when attaching to a PID."
            }
            return "Declare user active needs a timed duration or another keep-awake mode."
        }

        return "Select at least one keep-awake mode before starting."
    }

    private func persistBool(_ value: Bool, key: String) {
        guard !isRestoring else { return }
        defaults.set(value, forKey: key)
    }

    private func persistString(_ value: String, key: String) {
        guard !isRestoring else { return }
        defaults.set(value, forKey: key)
    }

    private func persistDurationComponents(_ components: DurationComponentsModel) {
        guard !isRestoring else { return }
        defaults.set(components.days, forKey: Keys.durationDays)
        defaults.set(components.hours, forKey: Keys.durationHours)
        defaults.set(components.minutes, forKey: Keys.durationMinutes)
        defaults.set(components.seconds, forKey: Keys.durationSeconds)
    }

    private static func formatDuration(_ totalSeconds: Int) -> String {
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    private static func formatCompactDuration(_ totalSeconds: Int) -> String {
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if days > 0 {
            return hours > 0 ? "\(days)d\(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(seconds)s"
    }
}
