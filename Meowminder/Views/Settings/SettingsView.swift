import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = RuleStore.shared
    @State private var selectedTab: Tab = .general

    enum Tab: String, CaseIterable, Identifiable, Hashable {
        case general = "General", alerts = "Alerts", data = "Data"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .alerts: return "bell"
            case .data: return "tray.full"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Tab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedTab == tab ? Color.accentColor.opacity(0.18) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(8)
            .frame(width: 130)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            Group {
                switch selectedTab {
                case .general: generalTab
                case .alerts: alertsTab
                case .data: dataTab
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 460, height: 340)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var generalTab: some View {
        Form {
            Toggle("Launch at Login", isOn: Binding(
                get: { store.settings.launchAtLogin },
                set: { newValue in
                    var s = store.settings
                    s.launchAtLogin = newValue
                    store.updateSettings(s)
                    LaunchAtLoginManager.shared.setEnabled(newValue)
                }
            ))
            Text("Start automatically when you log in.")
                .font(.caption2).foregroundColor(.secondary)

            Picker("Default Overlay Display", selection: Binding(
                get: { store.settings.defaultOverlayDisplayMode },
                set: { var s = store.settings; s.defaultOverlayDisplayMode = $0; store.updateSettings(s) }
            )) {
                Text("Main display only").tag(OverlayDisplayMode.mainDisplayOnly)
                Text("All displays").tag(OverlayDisplayMode.allDisplays)
            }
            Text("Can be overridden per rule.")
                .font(.caption2).foregroundColor(.secondary)

            Stepper("Wake cooldown: \(store.settings.wakeCooldownSeconds)s", value: Binding(
                get: { store.settings.wakeCooldownSeconds },
                set: { var s = store.settings; s.wakeCooldownSeconds = $0; store.updateSettings(s) }
            ), in: 0...300, step: 15)
            Text("Delay before alerts resume after the Mac wakes.")
                .font(.caption2).foregroundColor(.secondary)
        }
    }

    private var alertsTab: some View {
        Form {
            Toggle("Pause All Reminders", isOn: Binding(
                get: { store.settings.allRemindersPaused },
                set: { var s = store.settings; s.allRemindersPaused = $0; store.updateSettings(s) }
            ))
            Text("Mutes every alert temporarily without disabling individual rules.")
                .font(.caption2).foregroundColor(.secondary)
        }
    }

    private var dataTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rules and history are stored locally as JSON files in:")
                .font(.caption)
            Text("~/Library/Application Support/Meowminder/")
                .font(.caption.monospaced())
                .foregroundColor(.secondary)

            Button("Reveal in Finder") {
                let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("Meowminder")
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }
}
