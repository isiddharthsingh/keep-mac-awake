import Foundation
import Testing
@testable import AwakeCore

struct PendingSessionStoreTests {
    let suite = "AwakeCoreTests.\(UUID().uuidString)"
    let snapshot = SessionSnapshot(startDate: Date(timeIntervalSinceReferenceDate: 1000), duration: 7200, keepScreenOn: false)

    @Test func takeHandsOverSavedSessionOnce() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PendingSessionStore(defaults: defaults)

        store.save(snapshot)

        #expect(store.take() == snapshot)
        #expect(store.take() == nil)
    }

    @Test func takeIsNilWhenNothingWasSaved() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(PendingSessionStore(defaults: defaults).take() == nil)
    }

    @Test func savingNilClearsPendingSession() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PendingSessionStore(defaults: defaults)

        store.save(snapshot)
        store.save(nil)

        #expect(store.take() == nil)
    }

    @Test func untilStoppedSessionSurvivesTheRoundTrip() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PendingSessionStore(defaults: defaults)
        let forever = SessionSnapshot(startDate: Date(timeIntervalSinceReferenceDate: 1000), duration: nil, keepScreenOn: true)

        store.save(forever)

        #expect(store.take() == forever)
    }

    @Test func takeIgnoresSessionSavedLongAgo() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSinceReferenceDate: 5000)
        let store = PendingSessionStore(defaults: defaults, clock: { now })

        store.save(snapshot)
        now += 6 * 60  // e.g. the Mac shut down mid-update and the app only opens at the next login

        #expect(store.take() == nil)
    }

    @Test func takeAcceptsSessionSavedRightBeforeRelaunch() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = Date(timeIntervalSinceReferenceDate: 5000)
        let store = PendingSessionStore(defaults: defaults, clock: { now })

        store.save(snapshot)
        now += 30

        #expect(store.take() == snapshot)
    }

    @Test func takeAcceptsSessionSavedByVersion104() {
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        // 1.0.4 saved the bare snapshot with no timestamp, right before relaunching into the update.
        defaults.set(try! JSONEncoder().encode(snapshot), forKey: "pendingSession")

        #expect(PendingSessionStore(defaults: defaults).take() == snapshot)
    }
}
