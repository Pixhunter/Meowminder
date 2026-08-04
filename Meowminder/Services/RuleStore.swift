import Foundation
import Combine

/// Owns the in-memory list of rules + app settings, backed by PersistenceStore.
/// Everything else (scheduler, popover, editor, settings window) reads/writes
/// through this single source of truth so the UI stays in sync.
final class RuleStore: ObservableObject {
    static let shared = RuleStore()

    @Published var rules: [Rule]
    @Published var settings: AppSettings

    private let persistence = PersistenceStore.shared

    private init() {
        let loaded = persistence.loadConfig()
        self.rules = loaded.rules
        self.settings = loaded.settings
    }

    // MARK: - Rule CRUD

    func addRule(_ rule: Rule) {
        rules.append(rule)
        persist()
    }

    func updateRule(_ rule: Rule) {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[idx] = rule
        persist()
    }

    func deleteRule(id: UUID) {
        rules.removeAll { $0.id == id }
        persist()
    }

    func setEnabled(_ enabled: Bool, for id: UUID) {
        guard let idx = rules.firstIndex(where: { $0.id == id }) else { return }
        rules[idx].isEnabled = enabled
        persist()
    }

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        persist()
    }

    private func persist() {
        persistence.saveConfig(rules: rules, settings: settings)
    }

    // MARK: - Logging

    @discardableResult
    func logCompletion(
        ruleId: UUID,
        source: LogSource,
        amount: Double? = nil,
        durationMinutes: Int? = nil,
        stateEvent: StartStopEvent? = nil
    ) -> LogEntry {
        let entry = LogEntry(ruleId: ruleId, source: source, amount: amount,
                              durationMinutes: durationMinutes, stateEvent: stateEvent)
        persistence.appendLogEntry(entry)
        objectWillChange.send() // progress views depend on log data, not just `rules`
        return entry
    }

    /// Removes today's most recent log entry for a rule — backs the "-" button
    /// in the popover, letting the user undo an accidental "+" tap.
    @discardableResult
    func undoLastEntry(for ruleId: UUID) -> Bool {
        let todaysEntries = persistence.logEntries(for: ruleId, on: Date())
        guard let mostRecent = todaysEntries.max(by: { $0.timestamp < $1.timestamp }) else { return false }
        persistence.removeLogEntry(id: mostRecent.id, timestamp: mostRecent.timestamp)
        objectWillChange.send()
        return true
    }

    // MARK: - Progress helpers (used by popover rows + overlay content)

    /// Quantity/Checkmark: sum/count of today's logged entries for a rule.
    func todayProgress(for rule: Rule) -> Double {
        let entries = persistence.logEntries(for: rule.id, on: Date())
        switch rule.template {
        case .quantity:
            return entries.reduce(0) { $0 + ($1.amount ?? 0) }
        case .checkmark:
            return Double(entries.count)
        case .timer:
            return Double(entries.reduce(0) { $0 + ($1.durationMinutes ?? 0) })
        case .startStop:
            return Double(entries.reduce(0) { $0 + ($1.durationMinutes ?? 0) })
        }
    }

    /// Current state for a Start/Stop rule: true if currently "started".
    func isCurrentlyStarted(for rule: Rule) -> Bool {
        guard let last = persistence.mostRecentLogEntry(for: rule.id) else { return false }
        return last.stateEvent == .started
    }

    func progressText(for rule: Rule) -> String {
        switch rule.template {
        case .quantity:
            let value = todayProgress(for: rule)
            return "\(Int(value)) / \(Int(rule.dailyTargetAmount)) \(rule.unitLabel) today"
        case .checkmark:
            let value = Int(todayProgress(for: rule))
            return "\(value) / \(rule.dailyTargetCount) times today"
        case .timer:
            let minutes = Int(todayProgress(for: rule))
            return "\(minutes / 60)h \(minutes % 60)m logged today"
        case .startStop:
            let started = isCurrentlyStarted(for: rule)
            return started ? "Currently active" : "Not active"
        }
    }
}
