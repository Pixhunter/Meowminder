import Foundation
import AppKit

/// Background engine that decides when rules become due and hands them off
/// to the AlertQueueManager. Owns no UI. Re-derives "is this due?" from
/// persisted state on every check rather than relying on live timers, so
/// nothing is lost across app relaunches — and reconciles explicitly on
/// wake, since sleep suspends the periodic timer entirely.
final class RuleScheduler: NSObject {
    static let shared = RuleScheduler()

    private let store = RuleStore.shared
    private let persistence = PersistenceStore.shared
    private var checkTimer: Timer?
    private var schedulerState: [UUID: RuleSchedulerState]
    private var pendingSnoozes: [PendingSnooze]

    /// Set right after a wake event; due-checks are suppressed until this passes,
    /// giving the "wake cooldown" behavior (queue can fill silently, overlay
    /// only appears once things settle).
    private var suppressPresentationUntil: Date?

    private override init() {
        schedulerState = persistence.loadSchedulerState()
        pendingSnoozes = persistence.loadPendingSnoozes()
    }

    func start() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkDueRules()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(handleWake), name: NSWorkspace.didWakeNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(handleSleep), name: NSWorkspace.willSleepNotification, object: nil
        )
        checkDueRules() // catch anything that became due while the app was closed
    }

    @objc private func handleSleep() {
        // Nothing to pause explicitly — the OS suspends our timer for us.
    }

    @objc private func handleWake() {
        let cooldown = TimeInterval(store.settings.wakeCooldownSeconds)
        suppressPresentationUntil = Date().addingTimeInterval(cooldown)
        AlertQueueManager.shared.setPresentationSuppressed(until: suppressPresentationUntil!)
        // Reconcile immediately so missed rules get queued (but not presented
        // until the cooldown above elapses) rather than waiting up to 30s.
        checkDueRules()
    }

    // MARK: - Due-check

    func checkDueRules() {
        guard !store.settings.allRemindersPaused else { return }
        let now = Date()

        // 1. Resolve any pending snoozes that have come due.
        var stillPending: [PendingSnooze] = []
        for snooze in pendingSnoozes {
            if snooze.fireAt <= now, let rule = store.rules.first(where: { $0.id == snooze.ruleId && $0.isEnabled }) {
                fire(rule: rule, now: now)
            } else {
                stillPending.append(snooze)
            }
        }
        if stillPending.count != pendingSnoozes.count {
            pendingSnoozes = stillPending
            persistence.savePendingSnoozes(pendingSnoozes)
        }

        // 2. Regular trigger-based due checks.
        for rule in store.rules where rule.isEnabled {
            // Don't double-queue a rule that's currently snoozed.
            if pendingSnoozes.contains(where: { $0.ruleId == rule.id }) { continue }

            // A rule we've never seen before (brand new, or first check ever
            // after a fresh install) gets armed silently instead of firing
            // immediately — no alert on first launch. It'll fire at its next
            // naturally scheduled time from here on.
            guard schedulerState[rule.id]?.lastFiredAt != nil else {
                schedulerState[rule.id] = RuleSchedulerState(ruleId: rule.id, lastFiredAt: now)
                persistence.saveSchedulerState(schedulerState)
                continue
            }

            if isDue(rule: rule, now: now) {
                fire(rule: rule, now: now)
            }
        }
    }

    private func isDue(rule: Rule, now: Date) -> Bool {
        // Safe to force a non-nil default here — checkDueRules() always arms
        // a rule (setting lastFiredAt) before isDue() is ever called on it.
        let lastFired = schedulerState[rule.id]?.lastFiredAt ?? now
        let calendar = Calendar.current

        switch rule.trigger.kind {
        case .interval:
            return now.timeIntervalSince(lastFired) >= Double(rule.trigger.intervalMinutes * 60)

        case .fixedTimes:
            let todaysFireTimes = rule.trigger.fixedTimesOfDayMinutes.compactMap {
                startOfDay(now, calendar: calendar).addingTimeInterval(Double($0 * 60))
            }
            // Due if there's a scheduled time today that has passed and we
            // haven't fired since it occurred. Collapses any number of missed
            // slots into a single "due" check — we fire once, not once per slot.
            guard let mostRecentDueSlot = todaysFireTimes.filter({ $0 <= now }).max() else { return false }
            return lastFired < mostRecentDueSlot

        case .spreadPerDay:
            let windowStart = startOfDay(now, calendar: calendar).addingTimeInterval(Double(rule.trigger.activeWindowStartMinutes * 60))
            let windowEnd = startOfDay(now, calendar: calendar).addingTimeInterval(Double(rule.trigger.activeWindowEndMinutes * 60))
            guard rule.trigger.timesPerDay > 0, windowEnd > windowStart else { return false }
            let step = windowEnd.timeIntervalSince(windowStart) / Double(rule.trigger.timesPerDay)
            let slots = (0..<rule.trigger.timesPerDay).map { windowStart.addingTimeInterval(Double($0) * step) }
            guard let mostRecentDueSlot = slots.filter({ $0 <= now }).max() else { return false }
            return lastFired < mostRecentDueSlot
        }
    }

    private func fire(rule: Rule, now: Date) {
        schedulerState[rule.id] = RuleSchedulerState(ruleId: rule.id, lastFiredAt: now)
        persistence.saveSchedulerState(schedulerState)
        AlertQueueManager.shared.enqueue(rule: rule)
    }

    private func startOfDay(_ date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }

    // MARK: - Called by the alert manager when the user taps Reschedule

    func snooze(ruleId: UUID, minutes: Int) {
        let fireAt = Date().addingTimeInterval(Double(minutes * 60))
        pendingSnoozes.append(PendingSnooze(ruleId: ruleId, fireAt: fireAt))
        persistence.savePendingSnoozes(pendingSnoozes)
    }
}
