import SwiftUI
import AppKit

/// The full content of one overlay window: transparent background, a pulsing
/// border near the screen edge, and a small centered card (~15-20% of the
/// screen) with the rule's icon/name and template-specific input.
struct AlertContentView: View {
    let rule: Rule
    /// amount (Quantity), durationMinutes (Timer/StartStop), stateEvent (StartStop)
    let onAccept: (_ amount: Double?, _ durationMinutes: Int?, _ event: StartStopEvent?) -> Void
    let onSnooze: (_ minutes: Int) -> Void

    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle()) // ensure the whole transparent area still captures clicks

            pulsingBorder

            VStack(spacing: 14) {
                Text(rule.icon).font(.system(size: 34))
                Text(rule.name).font(.headline)

                templateBody

                if rule.reschedule.allowsReschedule {
                    Divider().padding(.top, 4)
                    HStack(spacing: 10) {
                        ForEach(rule.reschedule.snoozeOptionsMinutes, id: \.self) { minutes in
                            Button("Snooze \(minutes)m") { onSnooze(minutes) }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        // Absorb every click anywhere on the transparent window so nothing reaches apps below.
        .background(ClickCatcher())
    }

    private var pulsingBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(Color.orange, lineWidth: 4)
            .shadow(color: .orange.opacity(pulse ? 0.8 : 0.35), radius: pulse ? 26 : 10)
            .opacity(pulse ? 1 : 0.55)
            .padding(10)
    }

    @ViewBuilder
    private var templateBody: some View {
        switch rule.template {
        case .quantity:
            QuantityAlertView(rule: rule) { amount in onAccept(amount, nil, nil) }
        case .checkmark:
            CheckmarkAlertView(rule: rule) { onAccept(nil, nil, nil) }
        case .startStop:
            StartStopAlertView(rule: rule) { event in onAccept(nil, nil, event) }
        case .timer:
            TimerAlertView(rule: rule) { minutes in onAccept(nil, minutes, nil) }
        }
    }
}

/// A transparent NSView proxy so clicks on empty space within the window are
/// still consumed by the window rather than passing through to apps below.
private struct ClickCatcher: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
