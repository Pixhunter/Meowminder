import Foundation

/// All local JSON persistence for the app. Config (rules + settings) is rare-write,
/// so it's a single small file. Log history is append-heavy, so it's split one
/// file per month to keep individual reads/writes cheap as history grows.
final class PersistenceStore {
    static let shared = PersistenceStore()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Directories

    private var appSupportDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Meowminder", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var logsDirectory: URL {
        appSupportDirectory.appendingPathComponent("logs", isDirectory: true)
    }

    private var configURL: URL {
        appSupportDirectory.appendingPathComponent("config.json")
    }

    private var snoozesURL: URL {
        appSupportDirectory.appendingPathComponent("snoozes.json")
    }

    private func logFileURL(for date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let name = formatter.string(from: date)
        return logsDirectory.appendingPathComponent("\(name).json")
    }

    // MARK: - Config (Rules + AppSettings)

    private struct ConfigFile: Codable {
        var rules: [Rule]
        var settings: AppSettings
    }

    func loadConfig() -> (rules: [Rule], settings: AppSettings) {
        guard let data = try? Data(contentsOf: configURL),
              let config = try? decoder.decode(ConfigFile.self, from: data) else {
            // First launch: seed with a couple of examples so the app isn't empty.
            let seeded = (rules: [Rule.exampleWater(), Rule.exampleFeedCat()], settings: AppSettings.default)
            saveConfig(rules: seeded.rules, settings: seeded.settings)
            return seeded
        }
        return (config.rules, config.settings)
    }

    func saveConfig(rules: [Rule], settings: AppSettings) {
        let config = ConfigFile(rules: rules, settings: settings)
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: configURL, options: .atomic)
    }

    // MARK: - Log entries

    /// Appends a single entry to the month file matching its timestamp.
    func appendLogEntry(_ entry: LogEntry) {
        let url = logFileURL(for: entry.timestamp)
        var entries = (try? loadLogEntries(from: url)) ?? []
        entries.append(entry)
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// All entries for the month containing `date`.
    func logEntries(forMonthContaining date: Date) -> [LogEntry] {
        (try? loadLogEntries(from: logFileURL(for: date))) ?? []
    }

    /// Convenience: all entries for a specific rule on a specific calendar day.
    func logEntries(for ruleId: UUID, on day: Date, calendar: Calendar = .current) -> [LogEntry] {
        logEntries(forMonthContaining: day).filter {
            $0.ruleId == ruleId && calendar.isDate($0.timestamp, inSameDayAs: day)
        }
    }

    /// Most recent entry for a rule, searching back up to a few months if needed
    /// (used by the scheduler to compute "last completion" for interval rules).
    func mostRecentLogEntry(for ruleId: UUID, before date: Date = Date(), monthsBack: Int = 6) -> LogEntry? {
        var cursor = date
        for _ in 0..<monthsBack {
            let candidates = logEntries(forMonthContaining: cursor)
                .filter { $0.ruleId == ruleId && $0.timestamp <= date }
                .sorted { $0.timestamp > $1.timestamp }
            if let match = candidates.first { return match }
            guard let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: cursor) else { break }
            cursor = prevMonth
        }
        return nil
    }

    /// Removes a single entry by id (used by the "-" button to undo the most
    /// recent log for a rule). `timestamp` is needed to find the right month file.
    func removeLogEntry(id: UUID, timestamp: Date) {
        let url = logFileURL(for: timestamp)
        var entries = (try? loadLogEntries(from: url)) ?? []
        entries.removeAll { $0.id == id }
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func loadLogEntries(from url: URL) throws -> [LogEntry] {
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try decoder.decode([LogEntry].self, from: data)
    }

    // MARK: - Pending snoozes (survive app relaunch)

    func loadPendingSnoozes() -> [PendingSnooze] {
        guard let data = try? Data(contentsOf: snoozesURL),
              let snoozes = try? decoder.decode([PendingSnooze].self, from: data) else {
            return []
        }
        return snoozes
    }

    func savePendingSnoozes(_ snoozes: [PendingSnooze]) {
        guard let data = try? encoder.encode(snoozes) else { return }
        try? data.write(to: snoozesURL, options: .atomic)
    }

    // MARK: - Scheduler state (per-rule "last fired" bookkeeping)

    private var schedulerStateURL: URL {
        appSupportDirectory.appendingPathComponent("scheduler_state.json")
    }

    func loadSchedulerState() -> [UUID: RuleSchedulerState] {
        guard let data = try? Data(contentsOf: schedulerStateURL),
              let list = try? decoder.decode([RuleSchedulerState].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: list.map { ($0.ruleId, $0) })
    }

    func saveSchedulerState(_ state: [UUID: RuleSchedulerState]) {
        guard let data = try? encoder.encode(Array(state.values)) else { return }
        try? data.write(to: schedulerStateURL, options: .atomic)
    }
}

struct RuleSchedulerState: Codable {
    var ruleId: UUID
    var lastFiredAt: Date?
}
