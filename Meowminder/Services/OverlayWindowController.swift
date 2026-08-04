import AppKit
import SwiftUI

/// Owns one transparent, click-capturing, full-screen NSWindow per target
/// display for a single rule's alert. All windows share the same resolution
/// state — accepting or snoozing on any one display's card closes all of them.
final class OverlayWindowController {
    private let rule: Rule
    private var windows: [NSWindow] = []
    private let onResolved: () -> Void
    private var resolved = false

    init(rule: Rule, onResolved: @escaping () -> Void) {
        self.rule = rule
        self.onResolved = onResolved
    }

    func show() {
        let mode = resolvedDisplayMode()
        let screens: [NSScreen]
        switch mode {
        case .mainDisplayOnly:
            screens = [NSScreen.main].compactMap { $0 }
        case .allDisplays, .useAppDefault:
            screens = NSScreen.screens
        }

        for screen in screens {
            let window = makeWindow(on: screen)
            windows.append(window)
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func resolvedDisplayMode() -> OverlayDisplayMode {
        rule.overlayDisplayMode == .useAppDefault ? RuleStore.shared.settings.defaultOverlayDisplayMode : rule.overlayDisplayMode
    }

    private func makeWindow(on screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        // .screenSaver sits above nearly everything, including full-screen apps' windows.
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = false // transparent area still captures clicks — nothing passes through to apps below
        window.isReleasedWhenClosed = false

        let content = AlertContentView(
            rule: rule,
            onAccept: { [weak self] amount, duration, event in
                self?.handleAccept(amount: amount, duration: duration, event: event)
            },
            onSnooze: { [weak self] minutes in
                self?.handleSnooze(minutes: minutes)
            }
        )
        window.contentView = NSHostingView(rootView: content)
        return window
    }

    private func handleAccept(amount: Double?, duration: Int?, event: StartStopEvent?) {
        RuleStore.shared.logCompletion(
            ruleId: rule.id, source: .alertAccepted,
            amount: amount, durationMinutes: duration, stateEvent: event
        )
        dismiss()
    }

    private func handleSnooze(minutes: Int) {
        RuleScheduler.shared.snooze(ruleId: rule.id, minutes: minutes)
        dismiss()
    }

    private func dismiss() {
        guard !resolved else { return }
        resolved = true
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        onResolved()
    }
}
