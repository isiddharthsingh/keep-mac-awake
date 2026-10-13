import Foundation

/// Hands a running session from the app that is about to relaunch to the one that starts next.
public struct PendingSessionStore {
    private static let key = "pendingSession"
    private static let savedAtKey = "pendingSessionSavedAt"
    /// An update relaunch takes seconds. Anything older was saved before a relaunch that never happened,
    /// for example a shutdown mid-update, and must not quietly resume at the next login.
    private static let maxAge: TimeInterval = 5 * 60
    private let defaults: UserDefaults
    private let clock: () -> Date

    public init(defaults: UserDefaults = .standard, clock: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.clock = clock
    }

    /// Saves the session for the next launch, or clears it when nil.
    public func save(_ snapshot: SessionSnapshot?) {
        guard let snapshot, let data = try? JSONEncoder().encode(snapshot) else {
            defaults.removeObject(forKey: Self.key)
            defaults.removeObject(forKey: Self.savedAtKey)
            return
        }
        defaults.set(data, forKey: Self.key)
        defaults.set(clock(), forKey: Self.savedAtKey)
    }

    /// Returns the saved session once, then forgets it.
    public func take() -> SessionSnapshot? {
        defer {
            defaults.removeObject(forKey: Self.key)
            defaults.removeObject(forKey: Self.savedAtKey)
        }
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        // 1.0.4 saved no timestamp; its snapshot is from the relaunch that is starting this version.
        if let savedAt = defaults.object(forKey: Self.savedAtKey) as? Date, clock().timeIntervalSince(savedAt) > Self.maxAge {
            return nil
        }
        return try? JSONDecoder().decode(SessionSnapshot.self, from: data)
    }
}
