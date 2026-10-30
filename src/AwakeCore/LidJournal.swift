import Foundation

/// Everything lid mode changed outside the app. Each change is written here before it is made,
/// so it can still be undone if the app crashes: by the watchdog process, or at the next launch.
public struct LidJournal: Codable, Equatable, Sendable {
    public var lidSleepDisabled = false
    public var mutedOutputUID: String?
    public var pausedProcesses: [ProcessRecord] = []

    public init(lidSleepDisabled: Bool = false, mutedOutputUID: String? = nil, pausedProcesses: [ProcessRecord] = []) {
        self.lidSleepDisabled = lidSleepDisabled
        self.mutedOutputUID = mutedOutputUID
        self.pausedProcesses = pausedProcesses
    }
}

/// Keeps the journal in a file rather than UserDefaults, so the watchdog process reads exactly what the app wrote.
public struct LidJournalStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// A missing or unreadable file reads as an empty journal.
    public func load() -> LidJournal {
        guard let data = try? Data(contentsOf: url) else { return LidJournal() }
        return (try? JSONDecoder().decode(LidJournal.self, from: data)) ?? LidJournal()
    }

    /// Writes the journal, or removes the file once there is nothing left to undo.
    /// Returns false if the file doesn't hold the journal afterwards.
    @discardableResult
    public func save(_ journal: LidJournal) -> Bool {
        guard journal != LidJournal() else {
            try? FileManager.default.removeItem(at: url)
            return !FileManager.default.fileExists(atPath: url.path)
        }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(journal).write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
