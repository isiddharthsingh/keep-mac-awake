import Foundation

/// Settings that should stay as the user left them across relaunches.
public struct Preferences {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var keepScreenOn: Bool {
        get { defaults.object(forKey: "keepScreenOn") as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: "keepScreenOn") }
    }

    /// Battery charge, in percent, at which a session ends while on battery; nil means never.
    /// Values outside 1...99 read as nil, since they would end every session at once or never.
    public var batteryFloor: Int? {
        get { (defaults.object(forKey: "batteryFloor") as? Int).flatMap { (1...99).contains($0) ? $0 : nil } }
        nonmutating set { defaults.set(newValue, forKey: "batteryFloor") }
    }
}
