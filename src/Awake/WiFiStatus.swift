import Network
import Observation

/// Whether Wi-Fi has a working connection, for the panel's status line. Event-driven, so it costs nothing between changes.
@MainActor
@Observable
final class WiFiStatus {
    private(set) var isConnected = false
    @ObservationIgnored private let monitor = NWPathMonitor(requiredInterfaceType: .wifi)

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in self?.isConnected = connected }
        }
        monitor.start(queue: .main)
    }
}
