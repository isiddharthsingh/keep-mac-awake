import AppKit
import AwakeCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let powerSource = IOPowerSource()
let session = KeepAwakeSession(
    blocker: PowerAssertionBlocker(reason: "\(AppInfo.name) is keeping the Mac awake"), powerSource: powerSource)
let pendingSessions = PendingSessionStore()
// If an update relaunch handed over a running timer, pick it back up before the menu bar shows.
if let saved = pendingSessions.take() { session.restore(saved) }
let statusBar = StatusBarController(
    session: session, pendingSessions: pendingSessions, hasBattery: powerSource.batteryStatus() != nil)
app.run()
