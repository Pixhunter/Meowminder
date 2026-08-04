import SwiftUI
import AppKit

@main
struct MeowminderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No windows are declared here on purpose — this is a menu-bar-only
        // app. All UI (popover, rule editor, settings) is presented as
        // sheets/popovers from StatusItemController, driven from AppDelegate.
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon, no app switcher entry — pure menu-bar presence.
        NSApp.setActivationPolicy(.accessory)

        StatusItemController.shared.install()
        LaunchAtLoginManager.shared.syncSettingToActualState()
        RuleScheduler.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // closing a sheet/popover should never quit a menu-bar app
    }
}
