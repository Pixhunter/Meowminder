import Foundation
import AppKit

/// Coordinates the FIFO queue of due rules and the lifecycle of the overlay
/// window(s) presenting them. Only one rule's overlay is ever on screen at a
/// time — if another rule becomes due while one is showing, it waits in line.
final class AlertQueueManager {
    static let shared = AlertQueueManager()

    private var queue: [Rule] = []
    private var currentController: OverlayWindowController?
    private var suppressedUntil: Date?
    private var suppressionTimer: Timer?

    private init() {}

    func enqueue(rule: Rule) {
        queue.append(rule)
        tryPresentNext()
    }

    /// Called by the scheduler right after a wake event. Alerts collected
    /// during this window still get queued, they just won't be shown until
    /// the cooldown elapses.
    func setPresentationSuppressed(until date: Date) {
        suppressedUntil = date
        suppressionTimer?.invalidate()
        let delay = max(0, date.timeIntervalSinceNow)
        suppressionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.suppressedUntil = nil
            self?.tryPresentNext()
        }
    }

    private func tryPresentNext() {
        guard currentController == nil else { return }          // something's already showing
        if let until = suppressedUntil, until > Date() { return } // still cooling down from wake
        guard !queue.isEmpty else { return }
        let rule = queue.removeFirst()
        presentOverlay(for: rule)
    }

    private func presentOverlay(for rule: Rule) {
        let controller = OverlayWindowController(rule: rule) { [weak self] in
            self?.currentController = nil
            self?.tryPresentNext()
        }
        currentController = controller
        controller.show()
    }
}
