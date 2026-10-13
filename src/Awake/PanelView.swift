import AwakeCore
import SwiftUI

private struct Preset: Identifiable {
    let title: String
    let duration: TimeInterval?  // nil = until stopped
    var id: String { title }
}

private let presets = [
    Preset(title: "15 min", duration: 15 * 60),
    Preset(title: "30 min", duration: 30 * 60),
    Preset(title: "1 hour", duration: 3600),
    Preset(title: "2 hours", duration: 2 * 3600),
    Preset(title: "4 hours", duration: 4 * 3600),
    Preset(title: "Until I stop", duration: nil),
]

private let batteryFloors = [10, 20, 30, 50]

/// The panel that drops down from the menu bar icon.
struct PanelView: View {
    @Bindable var session: KeepAwakeSession
    /// Desktop Macs have no battery, so they get no battery setting.
    let hasBattery: Bool
    let onCheckForUpdates: () -> Void
    @State private var customHours = 1
    @State private var customMinutes = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            status.padding(.top, 12)
            Divider().padding(.vertical, 14)
            sectionLabel("KEEP AWAKE FOR")
            presetGrid
            sectionLabel("CUSTOM").padding(.top, 14)
            customRow
            Divider().padding(.vertical, 14)
            VStack(spacing: 10) {
                HStack {
                    Text("Keep screen on")
                    Spacer()
                    Toggle("Keep screen on", isOn: $session.keepScreenOn)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.small)
                }
                if hasBattery { batteryFloorRow }
            }
            Divider().padding(.vertical, 14)
            VStack(spacing: 2) {
                MenuRow(title: "Check for Updates…", trailing: "v\(AppInfo.version)", action: onCheckForUpdates)
                MenuRow(title: "Quit \(AppInfo.name)", trailing: "⌘Q", shortcut: "q") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .font(.system(size: 13))
        .padding(14)
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "cup.and.heat.waves.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor))
            Text(AppInfo.name).font(.system(size: 13.5, weight: .semibold))
            Spacer()
            StatusChip(isOn: session.isActive)
        }
    }

    @ViewBuilder private var status: some View {
        if let remaining = session.remaining, let endDate = session.endDate {
            statusRow(
                Text(DurationFormat.countdown(remaining))
                    .font(.system(size: 30, weight: .semibold).monospacedDigit()),
                subtitle: "left · Mac can sleep at \(endDate.formatted(date: .omitted, time: .shortened))")
            ProgressView(value: session.fractionRemaining ?? 0)
                .progressViewStyle(.linear)
                .padding(.top, 4)
        } else if let startDate = session.startDate {
            statusRow(
                Text("Awake until you stop").font(.system(size: 17, weight: .semibold)),
                subtitle: "Since \(startDate.formatted(date: .omitted, time: .shortened))")
        } else {
            statusRow(
                Text("Sleeping normally").font(.system(size: 17, weight: .semibold)),
                subtitle: session.lowBatteryStop.map {
                    "Stopped at \($0.percent)% battery at \($0.date.formatted(date: .omitted, time: .shortened))"
                } ?? "Pick a duration to keep your Mac awake")
        }
    }

    private func statusRow(_ title: Text, subtitle: String) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                title
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            if session.isActive {
                Button("Stop") { session.stop() }
                    .buttonStyle(PanelButtonStyle(kind: .destructive))
            }
        }
    }

    private var presetGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(presets) { preset in
                let selected = session.isActive && session.duration == preset.duration
                Button(preset.title) { session.start(for: preset.duration) }
                    .buttonStyle(PanelButtonStyle(kind: selected ? .accent : .neutral, fullWidth: true))
            }
        }
    }

    private var customRow: some View {
        let isEmpty = customHours == 0 && customMinutes == 0
        return HStack(spacing: 0) {
            NumberStepper(value: $customHours, range: 0...23, step: 1)
            Text("hr").foregroundStyle(.secondary).padding(.leading, 5).padding(.trailing, 10)
            NumberStepper(value: $customMinutes, range: 0...55, step: 5)
            Text("min").foregroundStyle(.secondary).padding(.leading, 5)
            Spacer()
            Button("Start") {
                session.start(for: TimeInterval(customHours * 3600 + customMinutes * 60))
            }
            .buttonStyle(PanelButtonStyle(kind: .accent))
            .disabled(isEmpty)
            .opacity(isEmpty ? 0.4 : 1)
        }
    }

    private var batteryFloorRow: some View {
        HStack {
            Text("Stop at low battery")
            Spacer()
            Picker("Stop at low battery", selection: $session.batteryFloor) {
                Text("Off").tag(Int?.none)
                ForEach(batteryFloors, id: \.self) { Text("\($0)%").tag(Int?.some($0)) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 7)
    }
}
