import AppKit
import AwakeCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let session = KeepAwakeSession(blocker: PowerAssertionBlocker(reason: "\(AppInfo.name) is keeping the Mac awake"))
let pendingSessions = PendingSessionStore()
// If an update relaunch handed over a running timer, pick it back up before the menu bar shows.
if let saved = pendingSessions.take() { session.restore(saved) }
let statusBar = StatusBarController(session: session, pendingSessions: pendingSessions)
app.run()
