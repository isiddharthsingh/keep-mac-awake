import Foundation

/// A second copy of the app, started while lid mode keeps the lid awake. It waits for the app to exit,
/// then undoes whatever the journal still lists. After a normal stop the journal is empty and it just exits;
/// after a crash or a force quit it lets the Mac sleep with the lid closed again and resumes paused apps.
public enum LidWatchdog {
    static let argument = "--lid-watchdog"

    /// When this launch is the watchdog, this never returns. Otherwise it returns at once.
    @MainActor
    public static func runIfRequested(journal: LidJournalStore, arguments: [String] = CommandLine.arguments) {
        // pid 0, -1 and launchd's 1 never name the app, and kill(pid, 0) succeeds for the first two.
        guard arguments.count == 3, arguments[1] == argument, let appPID = pid_t(arguments[2]), appPID > 1 else { return }
        let appExit = watch(appPID) {
            LidMode.recover(system: MacLidSystem(), journal: journal, lidSleepWasDisabled: true)
            exit(0)
        }
        withExtendedLifetime(appExit) { dispatchMain() }
    }

    /// Calls `onExit` on the main queue once the process has exited, at once if it already has.
    @MainActor
    static func watch(_ pid: pid_t, onExit: @escaping @MainActor () -> Void) -> DispatchSourceProcess {
        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated {
                source.cancel()
                onExit()
            }
        }
        source.resume()
        // The process may have exited before the source started watching it.
        if kill(pid, 0) != 0 {
            source.cancel()
            onExit()
        }
        return source
    }
}
