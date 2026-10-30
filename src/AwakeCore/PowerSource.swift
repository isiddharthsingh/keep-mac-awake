import Foundation
import IOKit
import IOKit.ps

/// The Mac's internal battery at one moment.
public struct BatteryStatus: Equatable, Sendable {
    public var percent: Int
    /// False while plugged in, even if the battery is not charging.
    public var isOnBattery: Bool
    /// Power the Mac is drawing from the battery; nil while plugged in or when the battery doesn't say.
    public var watts: Double?

    public init(percent: Int, isOnBattery: Bool, watts: Double? = nil) {
        self.percent = percent
        self.isOnBattery = isOnBattery
        self.watts = watts
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

    /// Watts drawn from the battery, from AppleSmartBattery's current (negative while draining) and voltage.
    static func dischargeWatts(milliamps: Int64, millivolts: Int64) -> Double? {
        milliamps < 0 ? -Double(milliamps) * Double(millivolts) / 1e6 : nil
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
    /// Kept once found: the battery is read every second during a session. A failed lookup is tried again next time.
    private var smartBattery = io_service_t(IO_OBJECT_NULL)

    public init() {}

    public func batteryStatus() -> BatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              var status = sources.lazy
                  .compactMap({ IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] })
                  .compactMap(BatteryStatus.init(powerSource:))
                  .first
        else { return nil }
        if status.isOnBattery { status.watts = dischargeWatts() }
        return status
    }

    /// The power source list reports no current on Apple silicon, so read the battery driver instead.
    private func dischargeWatts() -> Double? {
        if smartBattery == IO_OBJECT_NULL {
            smartBattery = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("AppleSmartBattery"))
        }
        let battery = smartBattery
        guard battery != IO_OBJECT_NULL else { return nil }
        func read(_ key: String) -> Int64? {
            (IORegistryEntryCreateCFProperty(battery, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? NSNumber)?.int64Value
        }
        guard let milliamps = read("InstantAmperage"), let millivolts = read("Voltage") else { return nil }
        return BatteryStatus.dischargeWatts(milliamps: milliamps, millivolts: millivolts)
    }
}
