import AppKit
import Darwin

/// One process as the kernel reports it.
struct ProcessEntry: Equatable, Sendable {
    var pid: Int32
    var ppid: Int32
    /// Microseconds since 1970; together with the pid it names one process for good.
    var startTime: UInt64
    var isStopped: Bool

    var record: ProcessRecord { ProcessRecord(pid: pid, startTime: startTime) }
}

/// Pauses whole apps with SIGSTOP and resumes them with SIGCONT. Signals to the user's own processes need no root.
enum AppProcesses {
    /// Each running app's main process and every process it started.
    static func records(ofApps bundleIDs: [String]) -> [ProcessRecord] {
        let roots = bundleIDs
            .flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0) }
            .map(\.processIdentifier)
        guard !roots.isEmpty else { return [] }
        return tree(from: roots, in: allProcesses()).map(\.record)
    }

    /// The roots and their descendants, parents before children. A process that is already stopped
    /// was stopped by something else (a debugger, the user), so it is left out and never resumed by us.
    static func tree(from roots: [Int32], in table: [ProcessEntry]) -> [ProcessEntry] {
        let children = Dictionary(grouping: table, by: \.ppid)
        let byPID = Dictionary(table.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [ProcessEntry] = []
        var queue = roots.compactMap { byPID[$0] }
        var seen = Set<Int32>()
        while !queue.isEmpty {
            let entry = queue.removeFirst()
            guard seen.insert(entry.pid).inserted else { continue }
            if !entry.isStopped { result.append(entry) }
            queue += children[entry.pid] ?? []
        }
        return result
    }

    static func entry(pid: Int32) -> ProcessEntry? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return ProcessEntry(
            pid: pid, ppid: Int32(info.pbi_ppid),
            startTime: info.pbi_start_tvsec * 1_000_000 + info.pbi_start_tvusec,
            isStopped: info.pbi_status == SSTOP)
    }

    static func pause(_ record: ProcessRecord) { signal(record, SIGSTOP) }

    static func resume(_ record: ProcessRecord) { signal(record, SIGCONT) }

    /// Signals only the process the record names, never a newer one that was given the same pid.
    private static func signal(_ record: ProcessRecord, _ signal: Int32) {
        guard record.pid > 1, record.pid != getpid(), entry(pid: record.pid)?.startTime == record.startTime else { return }
        kill(record.pid, signal)
    }

    private static func allProcesses() -> [ProcessEntry] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        // Leave room for processes started between the two calls.
        var pids = [Int32](repeating: 0, count: Int(count) + 64)
        let found = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        return pids.prefix(Int(max(found, 0))).compactMap(entry(pid:))
    }
}
