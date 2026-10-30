import AppKit
import AwakeCore

let lidJournal = LidJournalStore(
    url: URL.applicationSupportDirectory.appending(path: AppInfo.name).appending(path: "lid-journal.json"))
// While lid mode runs, a second copy of the app watches this one; that copy never gets past this line.
LidWatchdog.runIfRequested(journal: lidJournal)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let powerSource = IOPowerSource()
let lidSystem = MacLidSystem()
// Undo whatever a crashed run left changed, before a restored session sets lid mode up again.
LidMode.recover(system: lidSystem, journal: lidJournal)
let lid = LidMode(system: lidSystem, journal: lidJournal)
let preferences = Preferences()
lid.isEnabled = preferences.stayAwakeWithLidClosed
lid.options = preferences.lidCloseOptions
let session = KeepAwakeSession(
    blocker: PowerAssertionBlocker(reason: "\(AppInfo.name) is keeping the Mac awake"), powerSource: powerSource, lid: lid)
session.keepScreenOn = preferences.keepScreenOn
session.batteryFloor = preferences.batteryFloor
let pendingSessions = PendingSessionStore()
// If an update relaunch handed over a running timer, pick it back up before the menu bar shows.
if let saved = pendingSessions.take() { session.restore(saved) }
let reminders = ReminderScheduler(session: session)
let statusBar = StatusBarController(
    session: session, pendingSessions: pendingSessions, preferences: preferences,
    hasBattery: powerSource.batteryStatus() != nil)
// Power assertions end with the process, but lid sleep and paused apps don't, so quitting ends the session first.
NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
    MainActor.assumeIsolated {
        session.stop()
        reminders.cancel()
    }
}
app.run()
