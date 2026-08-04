import AppKit
import SwiftUI

/// Owns the NSStatusItem (the icon in the menu bar) and the popover that
/// drops down from it. Uses .semitransient behavior so interior clicks
/// (checkbox toggles, manual log buttons) don't dismiss it — only clicking
/// outside or switching apps does.
final class StatusItemController: NSObject, NSPopoverDelegate {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    // MARK: - Walking cat animation

    private let walkFrames: [NSImage] = (0..<8).compactMap { i in
        guard let url = Bundle.main.url(forResource: "cat_walk_\(i)", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 20, height: 20) // logical menu-bar size; PNG is 2x for retina crispness
        image.isTemplate = true // auto light/dark tint + click-highlight, matching native menu bar icons
        return image
    }
    private var walkFrameIndex = 0
    private var walkTimer: Timer?

    func install() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = walkFrames.first ?? NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "Meowminder")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.behavior = .semitransient
        popover.delegate = self
        popover.contentSize = NSSize(width: 300, height: 360)
        popover.contentViewController = NSHostingController(rootView: PopoverView())

        startWalking()
    }

    private func startWalking() {
        guard !walkFrames.isEmpty else { return } // frames missing from the bundle — falls back to the static first image
        walkTimer?.invalidate()
        walkTimer = Timer.scheduledTimer(withTimeInterval: 0.11, repeats: true) { [weak self] _ in
            self?.advanceWalkFrame()
        }
    }

    private func advanceWalkFrame() {
        guard let button = statusItem.button else { return }
        walkFrameIndex = (walkFrameIndex + 1) % walkFrames.count
        button.image = walkFrames[walkFrameIndex]
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
