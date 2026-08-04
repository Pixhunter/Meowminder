import SwiftUI

// MARK: - Quantity (e.g. water, calories)

struct QuantityAlertView: View {
    let rule: Rule
    let onLog: (Double) -> Void

    @State private var customAmount: String = ""
    @ObservedObject private var store = RuleStore.shared

    var body: some View {
        VStack(spacing: 10) {
            Text(store.progressText(for: rule))
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                ForEach(rule.quickAddPresets, id: \.self) { preset in
                    Button("+\(Int(preset))\(rule.unitLabel)") { onLog(preset) }
                        .buttonStyle(.bordered)
                        .font(.caption)
                }
            }

            HStack(spacing: 6) {
                TextField("Custom amount", text: $customAmount)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                Button("Log & Dismiss") {
                    if let value = Double(customAmount), value > 0 {
                        onLog(value)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(Double(customAmount) == nil)
            }
        }
    }
}

// MARK: - Checkmark (e.g. feed the cat, poop)

struct CheckmarkAlertView: View {
    let rule: Rule
    let onDone: () -> Void

    @ObservedObject private var store = RuleStore.shared

    var body: some View {
        VStack(spacing: 12) {
            Text(store.progressText(for: rule))
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Done") { onDone() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}

// MARK: - Start/Stop (e.g. work session)

struct StartStopAlertView: View {
    let rule: Rule
    let onToggle: (StartStopEvent) -> Void

    @ObservedObject private var store = RuleStore.shared

    var body: some View {
        let started = store.isCurrentlyStarted(for: rule)
        VStack(spacing: 12) {
            Text(store.progressText(for: rule))
                .font(.caption)
                .foregroundColor(.secondary)
            Button(started ? "Stop" : "Start") {
                onToggle(started ? .stopped : .started)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

// MARK: - Timer/Duration (e.g. sleep)

struct TimerAlertView: View {
    let rule: Rule
    let onLog: (Int) -> Void

    @State private var hours: Int
    @State private var minutes: Int

    init(rule: Rule, onLog: @escaping (Int) -> Void) {
        self.rule = rule
        self.onLog = onLog
        _hours = State(initialValue: rule.expectedDurationMinutes / 60)
        _minutes = State(initialValue: rule.expectedDurationMinutes % 60)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Stepper("\(hours)h", value: $hours, in: 0...24)
                Stepper("\(minutes)m", value: $minutes, in: 0...59, step: 5)
            }
            .font(.caption)

            Button("Log & Dismiss") { onLog(hours * 60 + minutes) }
                .buttonStyle(.borderedProminent)
        }
    }
}
