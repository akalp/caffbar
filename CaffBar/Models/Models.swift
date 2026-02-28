import Foundation

enum CaffeinateStartKind: String, Codable {
    case preset
    case durationComponents
    case infinity
    case attachPid
}

struct DurationComponentsModel: Codable, Equatable, Sendable {
    var days: Int = 0
    var hours: Int = 0
    var minutes: Int = 0
    var seconds: Int = 0

    var totalSeconds: Int {
        (((days * 24) + hours) * 60 + minutes) * 60 + seconds
    }

    func clamped() -> DurationComponentsModel {
        DurationComponentsModel(
            days: min(max(days, 0), 30),
            hours: min(max(hours, 0), 23),
            minutes: min(max(minutes, 0), 59),
            seconds: min(max(seconds, 0), 59)
        )
    }
}

struct CaffeinateOptions: Equatable, Sendable {
    var keepDisplayAwake: Bool
    var keepIdleAwake: Bool
    var keepSystemAwake: Bool
    var declareUserActive: Bool
    var preventDiskSleep: Bool
    var attachToPID: Bool
    var pidValue: Int?
    var durationSeconds: Int?
}

enum CaffBarPreset: String, CaseIterable, Identifiable, Codable {
    case minutes15
    case hour1
    case hours3
    case night8
    case infinity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minutes15: return "15m"
        case .hour1: return "1h"
        case .hours3: return "3h"
        case .night8: return "Night (8h)"
        case .infinity: return "∞ Until I stop"
        }
    }

    var compactButtonTitle: String {
        switch self {
        case .minutes15: return "15m"
        case .hour1: return "1h"
        case .hours3: return "3h"
        case .night8: return "8h"
        case .infinity: return "∞"
        }
    }

    var seconds: Int? {
        switch self {
        case .minutes15: return 15 * 60
        case .hour1: return 60 * 60
        case .hours3: return 3 * 60 * 60
        case .night8: return 8 * 60 * 60
        case .infinity: return nil
        }
    }
}

struct MenuAlertItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let message: String

    init(id: UUID = UUID(), title: String, message: String) {
        self.id = id
        self.title = title
        self.message = message
    }
}
