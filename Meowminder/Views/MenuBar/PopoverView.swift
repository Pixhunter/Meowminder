import SwiftUI
import AppKit

struct PopoverView: View {
    @ObservedObject private var store = RuleStore.shared
    @State private var editingRule: Rule?
    @State private var isCreatingRule = false
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Reminders").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Divider()

            if store.rules.isEmpty {
                Text("No rules yet")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.rules) { rule in
                            RuleRowView(rule: rule, onEdit: { editingRule = rule })
                            Divider()
                        }
                    }
                }
            }

            HStack {
                Button {
                    isCreatingRule = true
                } label: {
                    Label("Add Rule", systemImage: "plus.circle")
                        .font(.caption).bold()
                }
                .buttonStyle(.plain)

                Spacer()

                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)

                Button { NSApp.terminate(nil) } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
        }
        .frame(width: 300)
        .sheet(item: $editingRule) { rule in
            RuleEditorView(existingRule: rule)
        }
        .sheet(isPresented: $isCreatingRule) {
            RuleEditorView(existingRule: nil)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

struct RuleRowView: View {
    let rule: Rule
    let onEdit: () -> Void
    @ObservedObject private var store = RuleStore.shared
    @State private var showingDeleteConfirm = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                store.setEnabled(!rule.isEnabled, for: rule.id)
            } label: {
                Image(systemName: rule.isEnabled ? "checkmark.square.fill" : "square")
                    .foregroundColor(rule.isEnabled ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            Text(rule.icon)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name).font(.caption).bold()
                Text(rule.isEnabled ? store.progressText(for: rule) : "Disabled")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .onTapGesture { onEdit() }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    store.undoLastEntry(for: rule.id)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    logManually()
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    showingDeleteConfirm = true
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .confirmationDialog(
            "Remove \"\(rule.name)\"?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                store.deleteRule(id: rule.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This stops tracking it, but keeps its logged history.")
        }
    }

    private func logManually() {
        switch rule.template {
        case .quantity:
            store.logCompletion(ruleId: rule.id, source: .manualEntry, amount: rule.quickAddPresets.first ?? 1)
        case .checkmark:
            store.logCompletion(ruleId: rule.id, source: .manualEntry)
        case .startStop:
            let started = store.isCurrentlyStarted(for: rule)
            store.logCompletion(ruleId: rule.id, source: .manualEntry, stateEvent: started ? .stopped : .started)
        case .timer:
            store.logCompletion(ruleId: rule.id, source: .manualEntry, durationMinutes: rule.expectedDurationMinutes)
        }
    }
}
