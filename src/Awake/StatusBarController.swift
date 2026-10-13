import AppKit
import AwakeCore
import Sparkle
import SwiftUI

/// Owns the menu bar icon and the glass panel that drops down from it.
@MainActor
final class StatusBarController: NSObject {
    private let session: KeepAwakeSession
    private let preferences: Preferences
    private let loginItem = LoginItem()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = GlassPanel(cornerRadius: 18)
    private let sessionKeeper: UpdateSessionKeeper
    /// Checks the appcast daily (SUFeedURL in Info.plist) and on "Check for Updates…".
    private let updater: SPUStandardUpdaterController
    private var panelSize = CGSize.zero
    private var isPanelOpen = false
    private var clickMonitor: Any?

    init(session: KeepAwakeSession, pendingSessions: PendingSessionStore, preferences: Preferences, hasBattery: Bool) {
        self.session = session
        self.preferences = preferences
        sessionKeeper = UpdateSessionKeeper(session: session, store: pendingSessions)
        updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: sessionKeeper, userDriverDelegate: nil)
        super.init()
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePanel)
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .medium)
        }
        panel.onCancel = { [weak self] in self?.closePanel() }
        panel.setContent(
            PanelView(
                session: session, loginItem: loginItem, hasBattery: hasBattery,
                onCheckForUpdates: { [weak self] in self?.checkForUpdates() })
                .fixedSize()
                .onGeometryChange(for: CGSize.self, of: { $0.size }) { [weak self] size in
                    guard let self else { return }
                    panelSize = size
                    // This runs inside SwiftUI's update. Resizing the window from here makes AppKit apply the
                    // height change to the glass view twice, leaving the content shifted off the top edge.
                    // Resize on the next main-actor turn instead, once SwiftUI has finished.
                    if isPanelOpen { Task { @MainActor [weak self] in self?.positionPanel() } }
                }
        )
        updateButton()
        savePreferences()
    }

    /// Empty mug when idle; steaming cup plus time left while keeping the Mac awake.
    private func updateButton() {
        guard let button = statusItem.button else { return }
        withObservationTracking {
            button.image = NSImage(
                systemSymbolName: session.isActive ? "cup.and.heat.waves.fill" : "mug",
                accessibilityDescription: AppInfo.name)
            button.title = session.remaining.map { DurationFormat.menuBar($0) } ?? ""
        } onChange: { [weak self] in
            Task { @MainActor in self?.updateButton() }
        }
    }

    /// Writes the panel's settings back each time one changes, so the next launch starts the same way.
    private func savePreferences() {
        withObservationTracking {
            preferences.keepScreenOn = session.keepScreenOn
            preferences.batteryFloor = session.batteryFloor
        } onChange: { [weak self] in
            Task { @MainActor in self?.savePreferences() }
        }
    }

    private func checkForUpdates() {
        closePanel()
        NSApp.activate()
        updater.checkForUpdates(nil)
    }

    @objc private func togglePanel() {
        panel.isVisible ? closePanel() : openPanel()
    }

    private func openPanel() {
        isPanelOpen = true  // set first, so a size SwiftUI reports while the panel is opening still applies
        loginItem.refresh()
        if panelSize == .zero { panel.layoutContentIfNeeded() }  // reports the size through onGeometryChange
        positionPanel()
        panel.makeKeyAndOrderFront(nil)
        statusItem.button?.highlight(true)
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleClickElsewhere() }
        }
    }

    /// The menu bar is drawn by the Window Server, so clicks on our own icon also reach the global
    /// monitor. Leave those to `togglePanel`; otherwise the monitor closes the panel on mouse-down
    /// and the icon's action reopens it on mouse-up.
    private func handleClickElsewhere() {
        if let item = statusItem.button?.window, item.frame.contains(NSEvent.mouseLocation) { return }
        closePanel()
    }

    private func closePanel() {
        isPanelOpen = false
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
    }

    /// Hangs the panel just below the icon, kept on screen, with its top edge fixed as the height changes.
    private func positionPanel() {
        // The item's own window spans the full menu bar height, unlike the button inside it.
        guard panelSize != .zero, let item = statusItem.button?.window else { return }
        let screen = (item.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let x = min(item.frame.minX, screen.maxX - panelSize.width - 8)
        let y = item.frame.minY - 6 - panelSize.height
        panel.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: true)
        panel.invalidateShadow()
    }
}

/// Borderless, see-through panel whose only background is a rounded Liquid Glass shape.
final class GlassPanel: NSPanel {
    var onCancel: (() -> Void)?
    private let glass = NSGlassEffectView()

    init(cornerRadius: CGFloat) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        glass.cornerRadius = cornerRadius

        // The glass view also paints a faint layer over its whole rectangle, and macOS builds the
        // window shadow from every non-transparent pixel, so without this clip the shadow's dark
        // rim outlines a rectangle around the rounded glass.
        let clip = NSView()
        clip.wantsLayer = true
        clip.layer?.cornerRadius = cornerRadius
        clip.layer?.cornerCurve = .continuous
        clip.layer?.masksToBounds = true
        glass.autoresizingMask = [.width, .height]
        clip.addSubview(glass)
        contentView = clip
    }

    /// Lays out the SwiftUI content now, so its size is known before the panel is first shown.
    func layoutContentIfNeeded() { glass.contentView?.layoutSubtreeIfNeeded() }

    func setContent(_ view: some View) {
        let host = NSHostingView(rootView: view)
        // StatusBarController sizes the window from SwiftUI's measured size. If the hosting view also
        // published size constraints, AppKit's layout pass would resize the window too, at a different
        // moment, and the window and its content could end up a whole state change apart.
        host.sizingOptions = []
        host.frame = glass.bounds
        host.autoresizingMask = [.width, .height]
        glass.contentView = host
    }

    // Borderless windows can't become key by default; the panel needs it for ⌘Q and Esc.
    override var canBecomeKey: Bool { true }

    // Esc
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}
