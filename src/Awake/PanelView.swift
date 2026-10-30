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
    let loginItem: LoginItem
    /// Desktop Macs have no battery, so they get no battery setting.
    let hasBattery: Bool
    let wifi: WiFiStatus
    let onCheckForUpdates: () -> Void
    @AppStorage("customHours") private var customHours = 1
    @AppStorage("customMinutes") private var customMinutes = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            status.padding(.top, 12)
            if session.isActive { statusDetails.padding(.top, 10) }
            Divider().padding(.vertical, 14)
            sectionLabel("KEEP AWAKE FOR")
            presetGrid
            sectionLabel("CUSTOM").padding(.top, 14)
            customRow
            Divider().padding(.vertical, 14)
            VStack(spacing: 10) {
                switchRow("Keep screen on", isOn: $session.keepScreenOn)
                if hasBattery { batteryFloorRow }
                if let lid = session.lid, lid.hasLid { lidSettings(lid) }
                switchRow("Open at login", isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) }))
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
                subtitle: session.autoStop.map(Self.stopMessage) ?? "Pick a duration to keep your Mac awake")
        }
    }

    private static func stopMessage(_ stop: AutoStop) -> String {
        let time = stop.date.formatted(date: .omitted, time: .shortened)
        switch stop.reason {
        case .lowBattery(let percent): return "Stopped at \(percent)% battery at \(time)"
        case .tooHot: return "Stopped at \(time): the Mac got too hot"
        }
    }

    /// One quiet line under the countdown: the lid, Wi-Fi, and the battery.
    private var statusDetails: some View {
        HStack(spacing: 8) {
            if let lid = session.lid, lid.hasLid {
                detail("laptopcomputer", lidText(lid))
                Spacer(minLength: 0)
            }
            // Only Wi-Fi is watched: it may be off, or joined with no internet, while Ethernet still works.
            detail(wifi.isConnected ? "wifi" : "wifi.slash", wifi.isConnected ? "Connected" : "Wi-Fi offline")
            if let battery = session.battery {
                Spacer(minLength: 0)
                detail(battery.isOnBattery ? "bolt.fill" : "powerplug.fill",
                       battery.watts.map { "\(battery.percent)% · \(Int($0.rounded())) W" } ?? "\(battery.percent)%")
            }
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
    }

    /// After the lid has been closed for a while, how long it stayed awake that way; otherwise the lid's state.
    private func lidText(_ lid: LidMode) -> String {
        if lid.closedTime >= 60 { return "Closed \(DurationFormat.hoursAndMinutes(lid.closedTime))" }
        return lid.isClosed == true ? "Lid closed" : "Lid open"
    }

    private func detail(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).imageScale(.small)
            Text(text)
        }
        .lineLimit(1)
        .fixedSize()
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

    private func switchRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
    }

    @ViewBuilder private func lidSettings(_ lid: LidMode) -> some View {
        let lid = Bindable(lid)
        switchRow("Stay awake with lid closed", isOn: lid.isEnabled)
        if lid.wrappedValue.isEnabled {
            Text("Use it on a desk, never in a bag.")
                .font(.system(size: 11.5))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, -6)
            VStack(alignment: .leading, spacing: 7) {
                Text("WHEN THE LID CLOSES")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                checkbox("Turn off the screen", isOn: lid.options.turnOffScreen)
                checkbox("Mute sound", isOn: lid.options.muteSound)
                checkbox("Pause Slack, WhatsApp, Discord", isOn: lid.options.pauseChatApps)
                checkbox("Pause Docker when no container runs", isOn: lid.options.pauseIdleDocker)
            }
            .padding(.leading, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) { Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 2) }
        }
    }

    private func checkbox(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(.checkbox)
            .font(.system(size: 12.5))
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
