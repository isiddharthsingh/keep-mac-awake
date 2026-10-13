import Foundation

/// Hands a running session from the app that is about to relaunch to the one that starts next.
public struct PendingSessionStore {
    private static let key = "pendingSession"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Saves the session for the next launch, or clears it when nil.
    public func save(_ snapshot: SessionSnapshot?) {
        guard let snapshot, let data = try? JSONEncoder().encode(snapshot) else {
            defaults.removeObject(forKey: Self.key)
            return
        }
        defaults.set(data, forKey: Self.key)
    }

    /// Returns the saved session once, then forgets it.
    public func take() -> SessionSnapshot? {
        defer { defaults.removeObject(forKey: Self.key) }
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(SessionSnapshot.self, from: data)
    }
}
