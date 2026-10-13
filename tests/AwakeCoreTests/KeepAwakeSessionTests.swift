import Foundation
import Testing
@testable import AwakeCore

@MainActor
final class RecordingBlocker: SleepBlocker {
    private(set) var modes: [BlockMode] = []
    var current: BlockMode { modes.last ?? .off }
    func apply(_ mode: BlockMode) { modes.append(mode) }
}

@MainActor
final class TestClock {
    var now = Date(timeIntervalSinceReferenceDate: 0)
    func advance(_ seconds: TimeInterval) { now += seconds }
}

@MainActor
final class FakePowerSource: PowerSource {
    var status: BatteryStatus?
    func batteryStatus() -> BatteryStatus? { status }
}

@MainActor
struct KeepAwakeSessionTests {
    let blocker = RecordingBlocker()
    let clock = TestClock()
    let power = FakePowerSource()
    let session: KeepAwakeSession

    init() {
        let clock = clock
        session = KeepAwakeSession(blocker: blocker, powerSource: power, clock: { clock.now })
    }

    @Test func timedSessionBlocksSleepAndDisplayUntilEndDate() {
        session.start(for: 7200)

        #expect(session.isActive)
        #expect(session.endDate == clock.now + 7200)
        #expect(blocker.current == .systemAndDisplay)
    }

    @Test func screenAllowedOffBlocksOnlySystemSleep() {
        session.keepScreenOn = false
        session.start(for: 600)

        #expect(blocker.current == .system)
    }

    @Test func togglingScreenDuringSessionUpdatesBlock() {
        session.start(for: 600)

        session.keepScreenOn = false
        #expect(blocker.current == .system)

        session.keepScreenOn = true
        #expect(blocker.current == .systemAndDisplay)
    }

    @Test func togglingScreenWhileIdleNeverBlocks() {
        session.keepScreenOn = false
        session.keepScreenOn = true

        #expect(blocker.modes.allSatisfy { $0 == .off })
    }

    @Test func remainingCountsDownWithClock() {
        session.start(for: 7200)
        clock.advance(1800)
        session.tick()

        #expect(session.remaining == 5400)
        #expect(session.fractionRemaining == 0.75)
    }

    @Test func sessionEndsWhenTimeRunsOut() {
        session.start(for: 600)
        clock.advance(599)
        session.tick()
        #expect(session.isActive)

        clock.advance(1)
        session.tick()

        #expect(!session.isActive)
        #expect(session.remaining == nil)
        #expect(blocker.current == .off)
    }

    @Test func stopEndsSessionEarly() {
        session.start(for: 600)
        session.stop()

        #expect(!session.isActive)
        #expect(blocker.modes == [.systemAndDisplay, .off])
    }

    @Test func untilStoppedSessionNeverEndsOnItsOwn() {
        session.start(for: nil)
        clock.advance(10 * 24 * 3600)
        session.tick()

        #expect(session.isActive)
        #expect(session.endDate == nil)
        #expect(session.remaining == nil)
        #expect(blocker.current == .systemAndDisplay)
    }

    @Test func snapshotIsNilWhenIdle() {
        #expect(session.snapshot == nil)
    }

    @Test func snapshotCapturesRunningSession() {
        let started = clock.now
        session.keepScreenOn = false
        session.start(for: 7200)
        clock.advance(60)

        #expect(session.snapshot == SessionSnapshot(startDate: started, duration: 7200, keepScreenOn: false))
    }

    @Test func restoreResumesSessionThatHasNotEnded() {
        let started = clock.now
        clock.advance(1800)  // e.g. time spent installing an update

        let resumed = session.restore(SessionSnapshot(startDate: started, duration: 7200, keepScreenOn: true))

        #expect(resumed)
        #expect(session.isActive)
        #expect(session.endDate == started + 7200)
        #expect(session.remaining == 5400)
        #expect(blocker.current == .systemAndDisplay)
    }

    @Test func restoreIgnoresSessionThatAlreadyEnded() {
        let started = clock.now
        clock.advance(7200)

        let resumed = session.restore(SessionSnapshot(startDate: started, duration: 7200, keepScreenOn: true))

        #expect(!resumed)
        #expect(!session.isActive)
        #expect(blocker.modes.allSatisfy { $0 == .off })
    }

    @Test func restoreResumesUntilStoppedSession() {
        let started = clock.now
        clock.advance(5 * 3600)

        let resumed = session.restore(SessionSnapshot(startDate: started, duration: nil, keepScreenOn: true))

        #expect(resumed)
        #expect(session.isActive)
        #expect(session.endDate == nil)
        #expect(session.startDate == started)
    }

    @Test func restoreKeepsScreenSetting() {
        session.restore(SessionSnapshot(startDate: clock.now, duration: 600, keepScreenOn: false))

        #expect(!session.keepScreenOn)
        #expect(blocker.current == .system)
    }

    @Test func startingAgainReplacesPreviousSession() {
        session.start(for: 600)
        clock.advance(300)
        session.start(for: 3600)

        #expect(session.duration == 3600)
        #expect(session.endDate == clock.now + 3600)
    }

    @Test func sessionEndsWhenBatteryDropsToFloor() {
        session.batteryFloor = 20
        session.start(for: nil)

        power.status = BatteryStatus(percent: 21, isOnBattery: true)
        session.tick()
        #expect(session.isActive)

        clock.advance(600)
        power.status = BatteryStatus(percent: 20, isOnBattery: true)
        session.tick()

        #expect(!session.isActive)
        #expect(blocker.current == .off)
        #expect(session.lowBatteryStop == LowBatteryStop(percent: 20, date: clock.now))
    }

    @Test func pluggedInSessionIgnoresBatteryFloor() {
        session.batteryFloor = 20
        session.start(for: nil)

        power.status = BatteryStatus(percent: 10, isOnBattery: false)
        session.tick()

        #expect(session.isActive)
    }

    @Test func sessionWithoutBatteryFloorRunsBatteryDown() {
        session.start(for: nil)

        power.status = BatteryStatus(percent: 3, isOnBattery: true)
        session.tick()

        #expect(session.isActive)
        #expect(session.lowBatteryStop == nil)
    }

    @Test func macWithoutBatteryIgnoresBatteryFloor() {
        session.batteryFloor = 20
        session.start(for: nil)

        power.status = nil
        session.tick()

        #expect(session.isActive)
    }

    @Test func startingAgainForgetsLowBatteryStop() {
        session.batteryFloor = 20
        session.start(for: nil)
        power.status = BatteryStatus(percent: 20, isOnBattery: true)
        session.tick()

        power.status = BatteryStatus(percent: 20, isOnBattery: false)
        session.start(for: 600)

        #expect(session.lowBatteryStop == nil)
    }

    @Test func restoringForgetsLowBatteryStop() {
        session.batteryFloor = 20
        session.start(for: nil)
        power.status = BatteryStatus(percent: 20, isOnBattery: true)
        session.tick()

        power.status = BatteryStatus(percent: 20, isOnBattery: false)
        session.restore(SessionSnapshot(startDate: clock.now, duration: 600, keepScreenOn: true))

        #expect(session.lowBatteryStop == nil)
    }

    @Test func idleTickNeverReportsLowBattery() {
        session.batteryFloor = 20
        power.status = BatteryStatus(percent: 5, isOnBattery: true)

        session.tick()

        #expect(session.lowBatteryStop == nil)
    }
}
