import AppKit
import AwakeCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let powerSource = IOPowerSource()
let session = KeepAwakeSession(
    blocker: PowerAssertionBlocker(reason: "\(AppInfo.name) is keeping the Mac awake"), powerSource: powerSource)
let preferences = Preferences()
session.keepScreenOn = preferences.keepScreenOn
session.batteryFloor = preferences.batteryFloor
let pendingSessions = PendingSessionStore()
// If an update relaunch handed over a running timer, pick it back up before the menu bar shows.
if let saved = pendingSessions.take() { session.restore(saved) }
let reminders = ReminderScheduler(session: session)
let statusBar = StatusBarController(
    session: session, pendingSessions: pendingSessions, preferences: preferences,
    hasBattery: powerSource.batteryStatus() != nil)
// The session ends with the app, so a pending reminder must not fire after it.
NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
    MainActor.assumeIsolated { reminders.cancel() }
}
app.run()
