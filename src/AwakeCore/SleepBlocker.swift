/// What the Mac is currently prevented from doing.
public enum BlockMode: Equatable, Sendable {
    case off
    case system
    case systemAndDisplay
}

/// Holds or releases the OS-level "don't sleep" requests.
@MainActor
public protocol SleepBlocker: AnyObject {
    func apply(_ mode: BlockMode)
}
