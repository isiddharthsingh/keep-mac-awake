import Foundation
import Observation

/// What's needed to resume a session after the app relaunches, for example to install an update.
public struct SessionSnapshot: Codable, Equatable, Sendable {
    public var startDate: Date
    /// nil means "until stopped".
    public var duration: TimeInterval?
    public var keepScreenOn: Bool

    public init(startDate: Date, duration: TimeInterval?, keepScreenOn: Bool) {
        self.startDate = startDate
        self.duration = duration
        self.keepScreenOn = keepScreenOn
    }
}

/// A session that ended on its own before its time was up, kept so the panel can say why the Mac is allowed to sleep again.
public struct AutoStop: Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        case lowBattery(percent: Int)
        case tooHot
    }

    public var reason: Reason
    public var date: Date

    public init(reason: Reason, date: Date) {
        self.reason = reason
        self.date = date
    }
}

/// One "keep the Mac awake" session: for a fixed duration, or until stopped.
@MainActor
@Observable
public final class KeepAwakeSession {
    public private(set) var isActive = false
    /// Requested length; nil means "until stopped".
    public private(set) var duration: TimeInterval?
    public private(set) var startDate: Date?
    /// Last clock reading, refreshed every second while active so views can count down.
    public private(set) var now: Date
    public var keepScreenOn = true {
        didSet { applyBlock() }
    }
    /// Battery charge, in percent, at which the session ends while on battery; nil means never.
    public var batteryFloor: Int?
    /// Set when the battery floor or the heat ended the last session; cleared when the next one starts.
    public private(set) var autoStop: AutoStop?

    public var endDate: Date? {
        guard isActive, let startDate, let duration else { return nil }
        return startDate + duration
    }

    public var remaining: TimeInterval? {
        endDate.map { max(0, $0.timeIntervalSince(now)) }
    }

    public var fractionRemaining: Double? {
        guard let remaining, let duration, duration > 0 else { return nil }
        return remaining / duration
    }

    @ObservationIgnored private let blocker: SleepBlocker
    @ObservationIgnored private let powerSource: PowerSource
    @ObservationIgnored private let thermalState: () -> ProcessInfo.ThermalState
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var timer: Timer?

    public init(
        blocker: SleepBlocker, powerSource: PowerSource,
        thermalState: @escaping () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState },
        clock: @escaping () -> Date = Date.init
    ) {
        self.blocker = blocker
        self.powerSource = powerSource
        self.thermalState = thermalState
        self.clock = clock
        now = clock()
    }

    public func start(for duration: TimeInterval?) {
        now = clock()
        startDate = now
        self.duration = duration
        isActive = true
        autoStop = nil
        applyBlock()
        startTimer()
    }

    /// The running session, ready to save across a relaunch; nil when idle.
    public var snapshot: SessionSnapshot? {
        guard isActive, let startDate else { return nil }
        return SessionSnapshot(startDate: startDate, duration: duration, keepScreenOn: keepScreenOn)
    }

    /// Resumes a session saved before a relaunch, keeping its original start so the countdown
    /// includes the time the app was gone. Returns false, and stays idle, if its time already ran out.
    @discardableResult
    public func restore(_ snapshot: SessionSnapshot) -> Bool {
        now = clock()
        if let duration = snapshot.duration, snapshot.startDate + duration <= now { return false }
        keepScreenOn = snapshot.keepScreenOn
        startDate = snapshot.startDate
        duration = snapshot.duration
        isActive = true
        autoStop = nil
        applyBlock()
        startTimer()
        return true
    }

    public func stop() {
        isActive = false
        startDate = nil
        duration = nil
        timer?.invalidate()
        timer = nil
        applyBlock()
    }

    /// Advances the countdown; ends the session once its time is up, the battery reaches the floor,
    /// or the Mac gets critically hot. Uses wall-clock time, so it stays correct after the Mac wakes from sleep.
    public func tick() {
        now = clock()
        guard isActive else { return }
        if let endDate, now >= endDate {
            stop()
        } else if let batteryFloor, let battery = powerSource.batteryStatus(), battery.isOnBattery, battery.percent <= batteryFloor {
            stop()
            autoStop = AutoStop(reason: .lowBattery(percent: battery.percent), date: now)
        } else if thermalState() == .critical {
            stop()
            autoStop = AutoStop(reason: .tooHot, date: now)
        }
    }

    private func applyBlock() {
        blocker.apply(isActive ? (keepScreenOn ? .systemAndDisplay : .system) : .off)
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
