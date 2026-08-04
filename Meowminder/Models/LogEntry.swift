import Foundation

/// A single recorded completion for a rule — either from an alert being
/// accepted, or a manual log from the popover.
struct LogEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var ruleId: UUID
    var timestamp: Date
    var source: LogSource

    /// Quantity template: amount logged (in the rule's unit).
    var amount: Double?
    /// Timer template: duration logged, in minutes.
    var durationMinutes: Int?
    /// Start/Stop template: which state this entry represents.
    var stateEvent: StartStopEvent?

    init(
        id: UUID = UUID(),
        ruleId: UUID,
        timestamp: Date = Date(),
        source: LogSource,
        amount: Double? = nil,
        durationMinutes: Int? = nil,
        stateEvent: StartStopEvent? = nil
    ) {
        self.id = id
        self.ruleId = ruleId
        self.timestamp = timestamp
        self.source = source
        self.amount = amount
        self.durationMinutes = durationMinutes
        self.stateEvent = stateEvent
    }
}

enum LogSource: String, Codable, Equatable {
    case alertAccepted
    case manualEntry
}

enum StartStopEvent: String, Codable, Equatable {
    case started
    case stopped
}

/// A snoozed/pending alert that hasn't been resolved yet. Persisted so a
/// snooze survives an app relaunch.
struct PendingSnooze: Codable, Equatable {
    var ruleId: UUID
    var fireAt: Date
}
