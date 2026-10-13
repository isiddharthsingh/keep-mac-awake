import AppKit
import AwakeCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let statusBar = StatusBarController(
    session: KeepAwakeSession(blocker: PowerAssertionBlocker(reason: "\(AppInfo.name) is keeping the Mac awake")))
app.run()
