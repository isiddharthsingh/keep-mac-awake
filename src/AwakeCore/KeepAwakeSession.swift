import Foundation
import Observation

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
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var timer: Timer?

    public init(blocker: SleepBlocker, clock: @escaping () -> Date = Date.init) {
        self.blocker = blocker
        self.clock = clock
        now = clock()
    }

    public func start(for duration: TimeInterval?) {
        now = clock()
        startDate = now
        self.duration = duration
        isActive = true
        applyBlock()
        startTimer()
    }

    public func stop() {
        isActive = false
        startDate = nil
        duration = nil
        timer?.invalidate()
        timer = nil
        applyBlock()
    }

    /// Advances the countdown; ends the session once its time is up.
    /// Uses wall-clock time, so it stays correct after the Mac wakes from a lid-close sleep.
    public func tick() {
        now = clock()
        if let endDate, now >= endDate { stop() }
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
