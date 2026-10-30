import Testing
@testable import AwakeCore

/// The dictionaries mirror what IOPSGetPowerSourceDescription returns on a MacBook.
struct BatteryStatusTests {
    @Test func readsInternalBatteryRunningOnBattery() {
        let status = BatteryStatus(powerSource: [
            "Type": "InternalBattery", "Is Present": true, "Power Source State": "Battery Power",
            "Current Capacity": 18, "Max Capacity": 100,
        ])

        #expect(status == BatteryStatus(percent: 18, isOnBattery: true))
    }

    @Test func pluggedInIsNotOnBattery() {
        let status = BatteryStatus(powerSource: [
            "Type": "InternalBattery", "Is Present": true, "Power Source State": "AC Power",
            "Current Capacity": 80, "Max Capacity": 100,
        ])

        #expect(status == BatteryStatus(percent: 80, isOnBattery: false))
    }

    @Test func scalesCapacityThatIsNotAPercentage() {
        let status = BatteryStatus(powerSource: [
            "Type": "InternalBattery", "Is Present": true, "Power Source State": "Battery Power",
            "Current Capacity": 2500, "Max Capacity": 5000,
        ])

        #expect(status?.percent == 50)
    }

    @Test func ignoresUPS() {
        let status = BatteryStatus(powerSource: [
            "Type": "UPS", "Is Present": true, "Power Source State": "Battery Power",
            "Current Capacity": 10, "Max Capacity": 100,
        ])

        #expect(status == nil)
    }

    @Test func ignoresRemovedBattery() {
        let status = BatteryStatus(powerSource: [
            "Type": "InternalBattery", "Is Present": false, "Power Source State": "AC Power",
            "Current Capacity": 0, "Max Capacity": 100,
        ])

        #expect(status == nil)
    }

    /// AppleSmartBattery reports InstantAmperage in mA (negative while draining) and Voltage in mV.
    @Test func dischargeWattsFromAmperageAndVoltage() {
        #expect(BatteryStatus.dischargeWatts(milliamps: -1890, millivolts: 11812) == 1890 * 11812 / 1e6)
    }

    @Test func extremeAmperageDoesNotOverflow() {
        #expect(BatteryStatus.dischargeWatts(milliamps: .min, millivolts: 1) != nil)
    }

    @Test func chargingBatteryHasNoDischargeWatts() {
        #expect(BatteryStatus.dischargeWatts(milliamps: 1500, millivolts: 12600) == nil)
        #expect(BatteryStatus.dischargeWatts(milliamps: 0, millivolts: 12600) == nil)
    }
}
