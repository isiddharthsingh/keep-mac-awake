import Foundation
import Testing
@testable import AwakeCore

struct PreferencesTests {
    let suite = "AwakeCoreTests.\(UUID().uuidString)"

    @Test func firstLaunchKeepsScreenOnWithNoBatteryFloor() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)

        #expect(preferences.keepScreenOn)
        #expect(preferences.batteryFloor == nil)
    }

    @Test func screenSettingSurvivesRelaunch() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        Preferences(defaults: defaults).keepScreenOn = false

        #expect(!Preferences(defaults: defaults).keepScreenOn)
    }

    @Test func batteryFloorSurvivesRelaunch() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        Preferences(defaults: defaults).batteryFloor = 20

        #expect(Preferences(defaults: defaults).batteryFloor == 20)
    }

    @Test func turningBatteryFloorOffSurvivesRelaunch() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)

        preferences.batteryFloor = 20
        preferences.batteryFloor = nil

        #expect(Preferences(defaults: defaults).batteryFloor == nil)
    }

    @Test func outOfRangeBatteryFloorReadsAsOff() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(100, forKey: "batteryFloor")

        #expect(Preferences(defaults: defaults).batteryFloor == nil)
    }
}
