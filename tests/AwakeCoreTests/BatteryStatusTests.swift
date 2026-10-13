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
}
