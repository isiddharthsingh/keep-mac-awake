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
}
