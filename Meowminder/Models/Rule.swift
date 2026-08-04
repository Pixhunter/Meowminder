import Foundation

/// A single user-configured reminder rule.
struct Rule: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var icon: String            // an emoji or SF Symbol name, kept as a string for simplicity
    var template: RuleTemplate
    var isEnabled: Bool

    var trigger: TriggerConfig
    var reschedule: RescheduleConfig
    var overlayDisplayMode: OverlayDisplayMode

    // MARK: Template-specific configuration
    // Only the fields relevant to `template` are meaningful; the rest sit unused.
    // Kept flat (rather than an enum with associated values) so the whole struct
    // stays trivially Codable and easy to edit from a single form.

    /// Quantity template: unit label shown next to numbers, e.g. "ml" or "kcal".
    var unitLabel: String
    /// Quantity template: daily target amount.
    var dailyTargetAmount: Double
    /// Quantity template: quick-add buttons offered on the alert (in the same unit).
    var quickAddPresets: [Double]

    /// Checkmark template: how many completions count as "done" for the day.
    var dailyTargetCount: Int

    /// Timer template: default/expected duration in minutes, used as a starting point in the picker.
    var expectedDurationMinutes: Int

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        template: RuleTemplate,
        isEnabled: Bool = true,
        trigger: TriggerConfig,
        reschedule: RescheduleConfig = .default,
        overlayDisplayMode: OverlayDisplayMode = .useAppDefault,
        unitLabel: String = "",
        dailyTargetAmount: Double = 0,
        quickAddPresets: [Double] = [],
        dailyTargetCount: Int = 1,
        expectedDurationMinutes: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.template = template
        self.isEnabled = isEnabled
        self.trigger = trigger
        self.reschedule = reschedule
        self.overlayDisplayMode = overlayDisplayMode
        self.unitLabel = unitLabel
        self.dailyTargetAmount = dailyTargetAmount
        self.quickAddPresets = quickAddPresets
        self.dailyTargetCount = dailyTargetCount
        self.expectedDurationMinutes = expectedDurationMinutes
    }

    static func exampleWater() -> Rule {
        Rule(
            name: "Drink Water",
            icon: "💧",
            template: .quantity,
            trigger: .spread(times: 6, startMinutes: 480, endMinutes: 1320),
            unitLabel: "ml",
            dailyTargetAmount: 1000,
            quickAddPresets: [100, 250, 500]
        )
    }

    static func exampleFeedCat() -> Rule {
        Rule(
            name: "Feed the Cat",
            icon: "🐱",
            template: .checkmark,
            trigger: .fixedTimes([480, 1140]),
            dailyTargetCount: 2
        )
    }
}
