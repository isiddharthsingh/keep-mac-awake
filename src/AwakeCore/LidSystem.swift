/// The sound output that was playing when the lid closed.
public struct AudioOutput: Equatable, Sendable {
    public var uid: String
    public var isMuted: Bool

    public init(uid: String, isMuted: Bool) {
        self.uid = uid
        self.isMuted = isMuted
    }
}

/// One process, named so it can be told apart from a later process that reuses its pid.
public struct ProcessRecord: Codable, Equatable, Hashable, Sendable {
    public var pid: Int32
    /// When the kernel started it, in microseconds since 1970.
    public var startTime: UInt64

    public init(pid: Int32, startTime: UInt64) {
        self.pid = pid
        self.startTime = startTime
    }
}

/// The parts of macOS that lid mode reads and changes.
@MainActor
public protocol LidSystem: AnyObject {
    /// nil on Macs without a lid.
    func isLidClosed() -> Bool?
    /// Stops (true) or allows again (false) the sleep macOS starts when the lid closes.
    func setLidSleepDisabled(_ disabled: Bool)
    func hasExternalDisplay() -> Bool
    func turnOffDisplay()
    func currentOutput() -> AudioOutput?
    func setMuted(_ muted: Bool, outputUID: String)
    /// True only when Docker Desktop answers and no container is running.
    func isDockerIdle() -> Bool
    /// The running processes of these apps, each app's main process and everything it started,
    /// leaving out any process something else already stopped.
    func runningProcesses(ofApps bundleIDs: [String]) -> [ProcessRecord]
    func pause(_ process: ProcessRecord)
    /// Resumes the process only if its pid still belongs to the process that was paused.
    func resume(_ process: ProcessRecord)
}
