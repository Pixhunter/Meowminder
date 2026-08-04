import Foundation

/// The kind of reminder a Rule represents. Determines what fields the
/// rule-editor form shows and what content the alert overlay renders.
enum RuleTemplate: String, Codable, CaseIterable, Identifiable, Equatable, Hashable {
    case quantity     // e.g. drink water, eat calories — accumulates a number toward a daily target
    case checkmark    // e.g. feed the cat, poop — binary done/not-done, N times per day
    case startStop    // e.g. work session — toggles between two states, tracks elapsed time
    case timer        // e.g. sleep — logs a duration after the fact

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quantity: return "Quantity"
        case .checkmark: return "Checkmark"
        case .startStop: return "Start / Stop"
        case .timer: return "Timer / Duration"
        }
    }

    var describesWhatItTracks: String {
        switch self {
        case .quantity: return "Accumulates an amount toward a daily target (e.g. water, calories)"
        case .checkmark: return "A simple done/not-done action, repeated N times a day (e.g. feed the cat)"
        case .startStop: return "Toggles between two states and tracks time in each (e.g. work / break)"
        case .timer: return "Logs a duration after the fact (e.g. hours slept)"
        }
    }
}

/// How a rule decides when it's due to fire.
enum TriggerKind: String, Codable, CaseIterable, Identifiable, Equatable, Hashable {
    case fixedTimes     // fires at specific times of day, e.g. 9:00, 13:00, 18:00
    case interval       // fires every N minutes, restarting from the last completion
    case spreadPerDay   // fires N times, evenly spread across a configured active window

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fixedTimes: return "Fixed times of day"
        case .interval: return "Repeating interval"
        case .spreadPerDay: return "N times spread across the day"
        }
    }
}

struct TriggerConfig: Codable, Equatable {
    var kind: TriggerKind

    /// Used when kind == .fixedTimes. Minutes since midnight, e.g. 9:00 -> 540.
    var fixedTimesOfDayMinutes: [Int]

    /// Used when kind == .interval. Minutes between firings.
    var intervalMinutes: Int

    /// Used when kind == .spreadPerDay.
    var timesPerDay: Int
    var activeWindowStartMinutes: Int   // e.g. 8:00 -> 480
    var activeWindowEndMinutes: Int     // e.g. 22:00 -> 1320

    static func fixedTimes(_ times: [Int]) -> TriggerConfig {
        TriggerConfig(kind: .fixedTimes, fixedTimesOfDayMinutes: times, intervalMinutes: 60,
                       timesPerDay: 3, activeWindowStartMinutes: 480, activeWindowEndMinutes: 1320)
    }

    static func interval(_ minutes: Int) -> TriggerConfig {
        TriggerConfig(kind: .interval, fixedTimesOfDayMinutes: [], intervalMinutes: minutes,
                       timesPerDay: 3, activeWindowStartMinutes: 480, activeWindowEndMinutes: 1320)
    }

    static func spread(times: Int, startMinutes: Int, endMinutes: Int) -> TriggerConfig {
        TriggerConfig(kind: .spreadPerDay, fixedTimesOfDayMinutes: [], intervalMinutes: 60,
                       timesPerDay: times, activeWindowStartMinutes: startMinutes, activeWindowEndMinutes: endMinutes)
    }
}

struct RescheduleConfig: Codable, Equatable {
    var allowsReschedule: Bool
    /// Offered snooze durations in minutes. First one is used as the default button label.
    var snoozeOptionsMinutes: [Int]

    static let `default` = RescheduleConfig(allowsReschedule: true, snoozeOptionsMinutes: [10, 30, 60])
    static let notAllowed = RescheduleConfig(allowsReschedule: false, snoozeOptionsMinutes: [])
}

enum OverlayDisplayMode: String, Codable, CaseIterable, Identifiable, Equatable, Hashable {
    case useAppDefault
    case mainDisplayOnly
    case allDisplays

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .useAppDefault: return "Use app default"
        case .mainDisplayOnly: return "Main display only"
        case .allDisplays: return "All displays"
        }
    }
}
