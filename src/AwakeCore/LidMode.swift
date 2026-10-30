import Foundation
import Observation

/// What happens while the lid is closed during a session.
public struct LidCloseOptions: Equatable, Sendable {
    public var turnOffScreen = true
    public var muteSound = true
    public var pauseChatApps = true
    public var pauseIdleDocker = false

    public init(turnOffScreen: Bool = true, muteSound: Bool = true, pauseChatApps: Bool = true, pauseIdleDocker: Bool = false) {
        self.turnOffScreen = turnOffScreen
        self.muteSound = muteSound
        self.pauseChatApps = pauseChatApps
        self.pauseIdleDocker = pauseIdleDocker
    }
}

/// Keeps the Mac awake with the lid closed while a session runs, and runs the lid-close actions.
@MainActor
@Observable
public final class LidMode {
    /// Slack, WhatsApp and Discord.
    static let chatApps = ["com.tinyspeck.slackmacgap", "net.whatsapp.WhatsApp", "com.hnc.Discord"]
    static let dockerApp = "com.docker.docker"
    /// Updates run every second. A longer gap means the Mac slept, which is not time spent awake with the lid closed.
    private static let maxCountedGap: TimeInterval = 5

    /// Off by default: a closed Mac that stays awake can overheat in a bag.
    public var isEnabled = false {
        didSet { if isSessionActive { refresh() } }
    }
    public var options = LidCloseOptions()
    /// nil on Macs without a lid.
    public private(set) var isClosed: Bool?
    /// How long the lid has been closed during this session.
    public private(set) var closedTime: TimeInterval = 0
    /// True while the lid is closed with no other display connected, so the lid-close actions are in effect.
    public private(set) var isActingOnClosedLid = false

    public var hasLid: Bool { isClosed != nil }

    @ObservationIgnored private let system: LidSystem
    @ObservationIgnored private let journalStore: LidJournalStore
    @ObservationIgnored private var journal: LidJournal
    @ObservationIgnored private var isSessionActive = false
    @ObservationIgnored private var lastUpdate: Date?

    public init(system: LidSystem, journal: LidJournalStore) {
        self.system = system
        journalStore = journal
        self.journal = journal.load()
        isClosed = system.isLidClosed()
    }

    /// Puts back whatever an earlier run left changed, for example after a crash. A caller that knows lid sleep
    /// was off (the watchdog only runs then) passes `lidSleepWasDisabled`, so it is allowed again even if
    /// the journal never recorded it.
    public static func recover(system: LidSystem, journal store: LidJournalStore, lidSleepWasDisabled: Bool = false) {
        var journal = store.load()
        undo(&journal, system: system)
        if journal.lidSleepDisabled || lidSleepWasDisabled { system.setLidSleepDisabled(false) }
        store.save(LidJournal())
    }

    func sessionDidStart() {
        isSessionActive = true
        closedTime = 0
        lastUpdate = nil
    }

    /// Runs every second during a session.
    func update(now: Date) {
        isClosed = system.isLidClosed()
        if isClosed == true, let lastUpdate {
            closedTime += min(max(0, now.timeIntervalSince(lastUpdate)), Self.maxCountedGap)
        }
        lastUpdate = now
        refresh()
    }

    /// Puts everything back once the session ends: the lid actions first, then lid sleep, which may sleep the Mac at once.
    func sessionDidStop() {
        isSessionActive = false
        lastUpdate = nil
        undoActions()
        allowLidSleep()
    }

    private func refresh() {
        // A Mac without a lid can still carry the setting over from a laptop, with no switch to turn it off.
        guard isEnabled, hasLid else {
            undoActions()
            allowLidSleep()
            return
        }
        // powerd resets this whenever the charger, a display or a wake changes things, so set it every time.
        if !journal.lidSleepDisabled {
            journal.lidSleepDisabled = true
            journalStore.save(journal)
        }
        system.setLidSleepDisabled(true)

        // With another display connected, a closed lid is ordinary clamshell mode and the Mac is in use.
        let shouldAct = isClosed == true && !system.hasExternalDisplay()
        if shouldAct, !isActingOnClosedLid {
            applyActions()
        } else if !shouldAct, isActingOnClosedLid {
            undoActions()
        }
    }

    /// Mutes and pauses only once the journal holds the change, since a crash could not undo it otherwise.
    private func applyActions() {
        isActingOnClosedLid = true
        if options.muteSound, let output = system.currentOutput(), !output.isMuted {
            journal.mutedOutputUID = output.uid
            if journalStore.save(journal) {
                system.setMuted(true, outputUID: output.uid)
            } else {
                journal.mutedOutputUID = nil
            }
        }
        var apps = options.pauseChatApps ? Self.chatApps : []
        if options.pauseIdleDocker, system.isDockerIdle() { apps.append(Self.dockerApp) }
        let processes = system.runningProcesses(ofApps: apps)
        if !processes.isEmpty {
            journal.pausedProcesses += processes
            if journalStore.save(journal) {
                processes.forEach(system.pause)
            } else {
                journal.pausedProcesses.removeLast(processes.count)
            }
        }
        if options.turnOffScreen { system.turnOffDisplay() }
    }

    private func undoActions() {
        isActingOnClosedLid = false
        guard journal.mutedOutputUID != nil || !journal.pausedProcesses.isEmpty else { return }
        Self.undo(&journal, system: system)
        journalStore.save(journal)
    }

    private func allowLidSleep() {
        guard journal.lidSleepDisabled else { return }
        system.setLidSleepDisabled(false)
        journal.lidSleepDisabled = false
        journalStore.save(journal)
    }

    private static func undo(_ journal: inout LidJournal, system: LidSystem) {
        journal.pausedProcesses.forEach(system.resume)
        journal.pausedProcesses = []
        if let uid = journal.mutedOutputUID { system.setMuted(false, outputUID: uid) }
        journal.mutedOutputUID = nil
    }
}
