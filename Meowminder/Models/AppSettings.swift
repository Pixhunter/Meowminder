import Foundation

struct AppSettings: Codable, Equatable {
    var launchAtLogin: Bool
    var defaultOverlayDisplayMode: OverlayDisplayMode
    var wakeCooldownSeconds: Int
    var allRemindersPaused: Bool

    static let `default` = AppSettings(
        launchAtLogin: true,
        defaultOverlayDisplayMode: .allDisplays,
        wakeCooldownSeconds: 45,
        allRemindersPaused: false
    )
}
