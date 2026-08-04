import SwiftUI

/// Single sectioned form used for both creating and editing a rule. Fields
/// are shown/hidden based on the selected template. The template itself is
/// locked once a rule exists, since it defines the shape of that rule's
/// logged history.
struct RuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = RuleStore.shared

    private let existingRule: Rule?
    private let isEditing: Bool

    @State private var name: String
    @State private var icon: String
    @State private var template: RuleTemplate
    @State private var overlayDisplayMode: OverlayDisplayMode

    @State private var triggerKind: TriggerKind
    @State private var fixedTimes: [Date]
    @State private var intervalMinutes: Int
    @State private var timesPerDay: Int
    @State private var windowStart: Date
    @State private var windowEnd: Date

    @State private var allowsReschedule: Bool
    @State private var snoozeOptionsText: String

    @State private var unitLabel: String
    @State private var dailyTargetAmount: String
    @State private var quickAddPresetsText: String
    @State private var dailyTargetCount: Int
    @State private var expectedDurationMinutes: Int

    init(existingRule: Rule?) {
        self.existingRule = existingRule
        self.isEditing = existingRule != nil
        let r = existingRule ?? Rule(name: "", icon: "⏰", template: .quantity, trigger: .spread(times: 3, startMinutes: 480, endMinutes: 1320))

        _name = State(initialValue: r.name)
        _icon = State(initialValue: r.icon)
        _template = State(initialValue: r.template)
        _overlayDisplayMode = State(initialValue: r.overlayDisplayMode)

        _triggerKind = State(initialValue: r.trigger.kind)
        _fixedTimes = State(initialValue: r.trigger.fixedTimesOfDayMinutes.map { Self.date(fromMinutes: $0) })
        _intervalMinutes = State(initialValue: r.trigger.intervalMinutes)
        _timesPerDay = State(initialValue: r.trigger.timesPerDay)
        _windowStart = State(initialValue: Self.date(fromMinutes: r.trigger.activeWindowStartMinutes))
        _windowEnd = State(initialValue: Self.date(fromMinutes: r.trigger.activeWindowEndMinutes))

        _allowsReschedule = State(initialValue: r.reschedule.allowsReschedule)
        _snoozeOptionsText = State(initialValue: r.reschedule.snoozeOptionsMinutes.map(String.init).joined(separator: ", "))

        _unitLabel = State(initialValue: r.unitLabel)
        _dailyTargetAmount = State(initialValue: r.dailyTargetAmount > 0 ? String(r.dailyTargetAmount) : "")
        _quickAddPresetsText = State(initialValue: r.quickAddPresets.map { String(Int($0)) }.joined(separator: ", "))
        _dailyTargetCount = State(initialValue: r.dailyTargetCount)
        _expectedDurationMinutes = State(initialValue: r.expectedDurationMinutes)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Rule" : "New Rule")
                .font(.headline)
                .padding(.top, 16)

            Form {
                Section("Basics") {
                    TextField("Name", text: $name)
                    TextField("Icon (emoji)", text: $icon)
                    Picker("Type", selection: $template) {
                        ForEach(RuleTemplate.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .disabled(isEditing)
                    Text(template.describesWhatItTracks)
                        .font(.caption2).foregroundColor(.secondary)
                }

                templateSpecificSection

                Section("When") {
                    Picker("Trigger", selection: $triggerKind) {
                        ForEach(TriggerKind.allCases) { k in
                            Text(k.displayName).tag(k)
                        }
                    }
                    triggerFields
                }

                Section("Reschedule") {
                    Toggle("Allow snooze", isOn: $allowsReschedule)
                    if allowsReschedule {
                        TextField("Snooze options (minutes, comma-separated)", text: $snoozeOptionsText)
                    }
                }

                Section("Alert Display") {
                    Picker("Show on", selection: $overlayDisplayMode) {
                        ForEach(OverlayDisplayMode.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                if isEditing {
                    Button("Delete", role: .destructive) {
                        if let id = existingRule?.id { store.deleteRule(id: id) }
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding([.horizontal, .bottom], 16)
        }
        .frame(width: 420, height: 560)
    }

    @ViewBuilder
    private var triggerFields: some View {
        switch triggerKind {
        case .fixedTimes:
            ForEach(fixedTimes.indices, id: \.self) { idx in
                HStack {
                    DatePicker("", selection: $fixedTimes[idx], displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Button(role: .destructive) { fixedTimes.remove(at: idx) } label: {
                        Image(systemName: "minus.circle")
                    }
                }
            }
            Button("Add time") { fixedTimes.append(Date()) }

        case .interval:
            Stepper("Every \(intervalMinutes) min", value: $intervalMinutes, in: 5...480, step: 5)

        case .spreadPerDay:
            Stepper("\(timesPerDay) times per day", value: $timesPerDay, in: 1...20)
            DatePicker("Active window start", selection: $windowStart, displayedComponents: .hourAndMinute)
            DatePicker("Active window end", selection: $windowEnd, displayedComponents: .hourAndMinute)
        }
    }

    @ViewBuilder
    private var templateSpecificSection: some View {
        switch template {
        case .quantity:
            Section("Quantity") {
                TextField("Unit label (e.g. ml, kcal)", text: $unitLabel)
                TextField("Daily target", text: $dailyTargetAmount)
                TextField("Quick-add presets (comma-separated)", text: $quickAddPresetsText)
            }
        case .checkmark:
            Section("Checkmark") {
                Stepper("\(dailyTargetCount) times per day", value: $dailyTargetCount, in: 1...20)
            }
        case .startStop:
            EmptyView()
        case .timer:
            Section("Timer") {
                Stepper("Expected duration: \(expectedDurationMinutes / 60)h \(expectedDurationMinutes % 60)m",
                        value: $expectedDurationMinutes, in: 0...1440, step: 15)
            }
        }
    }

    private func save() {
        let trigger: TriggerConfig
        switch triggerKind {
        case .fixedTimes:
            trigger = .fixedTimes(fixedTimes.map { Self.minutes(fromDate: $0) })
        case .interval:
            trigger = .interval(intervalMinutes)
        case .spreadPerDay:
            trigger = .spread(times: timesPerDay,
                               startMinutes: Self.minutes(fromDate: windowStart),
                               endMinutes: Self.minutes(fromDate: windowEnd))
        }

        let reschedule = RescheduleConfig(
            allowsReschedule: allowsReschedule,
            snoozeOptionsMinutes: allowsReschedule
                ? snoozeOptionsText.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                : []
        )

        var rule = existingRule ?? Rule(name: name, icon: icon, template: template, trigger: trigger)
        rule.name = name
        rule.icon = icon
        rule.trigger = trigger
        rule.reschedule = reschedule
        rule.overlayDisplayMode = overlayDisplayMode
        rule.unitLabel = unitLabel
        rule.dailyTargetAmount = Double(dailyTargetAmount) ?? 0
        rule.quickAddPresets = quickAddPresetsText.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        rule.dailyTargetCount = dailyTargetCount
        rule.expectedDurationMinutes = expectedDurationMinutes

        if isEditing {
            store.updateRule(rule)
        } else {
            rule.template = template
            store.addRule(rule)
        }
        dismiss()
    }

    private static func date(fromMinutes minutes: Int) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    private static func minutes(fromDate date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}
