import ServiceManagement

/// Thin wrapper around SMAppService (macOS 13+). `.mainApp` registers this
/// app itself to launch at login — no separate helper target needed, unlike
/// the older SMLoginItemSetEnabled API.
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    private init() {}

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("LaunchAtLoginManager: failed to update login item — \(error)")
        }
    }

    /// Call once at launch to make sure the toggle reflects reality
    /// (e.g. user removed it via System Settings > Login Items directly).
    func syncSettingToActualState() {
        let actual = isEnabled
        var settings = RuleStore.shared.settings
        if settings.launchAtLogin != actual {
            settings.launchAtLogin = actual
            RuleStore.shared.updateSettings(settings)
        }
    }
}
