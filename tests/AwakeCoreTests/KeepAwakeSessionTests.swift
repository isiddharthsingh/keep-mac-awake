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
struct KeepAwakeSessionTests {
    let blocker = RecordingBlocker()
    let clock = TestClock()
    let session: KeepAwakeSession

    init() {
        let clock = clock
        session = KeepAwakeSession(blocker: blocker, clock: { clock.now })
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

    @Test func startingAgainReplacesPreviousSession() {
        session.start(for: 600)
        clock.advance(300)
        session.start(for: 3600)

        #expect(session.duration == 3600)
        #expect(session.endDate == clock.now + 3600)
    }
}
