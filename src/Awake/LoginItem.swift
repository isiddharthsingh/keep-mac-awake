import Observation
import ServiceManagement

/// "Open at login", read from and written to the Login Items list in System Settings, so the two always agree.
@MainActor
@Observable
final class LoginItem {
    private(set) var isEnabled = false

    init() { refresh() }

    /// Picks up changes made in System Settings while the panel was closed.
    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        // Match the switch the user just flipped, so the refresh below is a real change and flips it back if this fails.
        isEnabled = enabled
        // Fails if the user switched MacAwake off in System Settings; the status then asks for their approval there.
        try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        if enabled, SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        refresh()
    }
}
