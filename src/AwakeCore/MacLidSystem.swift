import CoreGraphics
import Foundation
import IOKit

/// The real Mac behind lid mode. Nothing here needs root.
@MainActor
public final class MacLidSystem: LidSystem {
    /// RootDomainUserClient's kPMSetClamshellSleepState method (IOPMLibDefs.h). Unlike a power assertion,
    /// the setting outlives the app, which is why LidWatchdog exists.
    private static let setClamshellSleepState: UInt32 = 12

    /// What `pmset displaysleepnow` calls, with 0 in its first argument register as pmset leaves it.
    /// It is private, so it is looked up at run time and skipped if it is gone.
    private static let requestDisplaysIdle: (@convention(c) (UInt32) -> Int32)? = {
        guard let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let symbol = dlsym(skyLight, "SLSDisplayManagerRequestDisplaysIdle")
        else { return nil }
        return unsafeBitCast(symbol, to: (@convention(c) (UInt32) -> Int32).self)
    }()

    private let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("IOPMrootDomain"))
    private var connection = io_connect_t(0)
    private var activity: NSObjectProtocol?
    private var watchdog: Process?

    public init() {}

    public func isLidClosed() -> Bool? {
        IORegistryEntryCreateCFProperty(rootDomain, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Bool
    }

    public func setLidSleepDisabled(_ disabled: Bool) {
        if disabled {
            startWatchdog()
            // With the lid closed nothing of ours is on screen, and App Nap would delay the once-a-second checks.
            if activity == nil {
                activity = ProcessInfo.processInfo.beginActivity(
                    options: .userInitiatedAllowingIdleSystemSleep, reason: "Keeping the Mac awake with the lid closed")
            }
        }
        if connection == 0 { IOServiceOpen(rootDomain, mach_task_self_, 0, &connection) }
        var input: UInt64 = disabled ? 1 : 0
        IOConnectCallScalarMethod(connection, Self.setClamshellSleepState, &input, 1, nil, nil)
        if !disabled {
            watchdog?.terminate()
            watchdog = nil
            activity.map(ProcessInfo.processInfo.endActivity)
            activity = nil
        }
    }

    public func hasExternalDisplay() -> Bool {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return false }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return false }
        return displays.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) == 0 }
    }

    public func turnOffDisplay() {
        _ = Self.requestDisplaysIdle?(0)
    }

    public func currentOutput() -> AudioOutput? { AudioMute.currentOutput() }

    public func setMuted(_ muted: Bool, outputUID: String) { AudioMute.setMuted(muted, uid: outputUID) }

    public func isDockerIdle() -> Bool { DockerProbe.isIdle() }

    public func runningProcesses(ofApps bundleIDs: [String]) -> [ProcessRecord] { AppProcesses.records(ofApps: bundleIDs) }

    public func pause(_ process: ProcessRecord) { AppProcesses.pause(process) }

    public func resume(_ process: ProcessRecord) { AppProcesses.resume(process) }

    private func startWatchdog() {
        guard watchdog?.isRunning != true, let executable = Bundle.main.executableURL else { return }
        let process = Process()
        process.executableURL = executable
        process.arguments = [LidWatchdog.argument, String(getpid())]
        try? process.run()
        watchdog = process
    }
}
