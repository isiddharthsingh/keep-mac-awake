import IOKit.ps

/// The Mac's internal battery at one moment.
public struct BatteryStatus: Equatable, Sendable {
    public var percent: Int
    /// False while plugged in, even if the battery is not charging.
    public var isOnBattery: Bool

    public init(percent: Int, isOnBattery: Bool) {
        self.percent = percent
        self.isOnBattery = isOnBattery
    }

    /// Reads one entry of IOPSCopyPowerSourcesList; nil unless it is the Mac's internal battery.
    init?(powerSource description: [String: Any]) {
        guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
              description[kIOPSIsPresentKey] as? Bool == true,
              let current = description[kIOPSCurrentCapacityKey] as? Int,
              let max = description[kIOPSMaxCapacityKey] as? Int, max > 0
        else { return nil }
        percent = Int((Double(current) * 100 / Double(max)).rounded())
        isOnBattery = description[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue
    }
}

/// Reports the battery charge, so a session can end before it drains the battery.
@MainActor
public protocol PowerSource: AnyObject {
    /// nil on Macs without a battery.
    func batteryStatus() -> BatteryStatus?
}

/// Reads the internal battery from IOKit, the same source the battery menu uses.
@MainActor
public final class IOPowerSource: PowerSource {
    public init() {}

    public func batteryStatus() -> BatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        return sources.lazy
            .compactMap { IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] }
            .compactMap(BatteryStatus.init(powerSource:))
            .first
    }
}
