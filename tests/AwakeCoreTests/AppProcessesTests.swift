import Foundation
import Testing
@testable import AwakeCore

struct AppProcessesTests {
    @Test func collectsAppAndEveryDescendant() {
        let table = [
            ProcessEntry(pid: 1, ppid: 0, startTime: 1, isStopped: false),
            ProcessEntry(pid: 10, ppid: 1, startTime: 2, isStopped: false),   // the app
            ProcessEntry(pid: 11, ppid: 10, startTime: 3, isStopped: false),  // its helper
            ProcessEntry(pid: 12, ppid: 11, startTime: 4, isStopped: false),  // the helper's child
            ProcessEntry(pid: 20, ppid: 1, startTime: 5, isStopped: false),   // another app
        ]

        #expect(AppProcesses.tree(from: [10], in: table).map(\.pid) == [10, 11, 12])
    }

    @Test func leavesOutProcessesSomeoneElseStopped() {
        let table = [
            ProcessEntry(pid: 10, ppid: 1, startTime: 2, isStopped: false),
            ProcessEntry(pid: 11, ppid: 10, startTime: 3, isStopped: true),
        ]

        #expect(AppProcesses.tree(from: [10], in: table).map(\.pid) == [10])
    }

    /// Pauses a real child process, so this checks the signals and the kernel's process state.
    @Test func pausesAndResumesARealProcess() throws {
        let child = try startSleep()
        defer {
            kill(child.processIdentifier, SIGCONT)
            child.terminate()
        }
        let record = try #require(AppProcesses.entry(pid: child.processIdentifier)?.record)

        AppProcesses.pause(record)
        #expect(waitUntil { AppProcesses.entry(pid: record.pid)?.isStopped == true })

        AppProcesses.resume(record)
        #expect(waitUntil { AppProcesses.entry(pid: record.pid)?.isStopped == false })
    }

    @Test func neverResumesAProcessThatIsNoLongerTheOnePaused() throws {
        let child = try startSleep()
        defer {
            kill(child.processIdentifier, SIGCONT)
            child.terminate()
        }
        let record = try #require(AppProcesses.entry(pid: child.processIdentifier)?.record)
        AppProcesses.pause(record)
        #expect(waitUntil { AppProcesses.entry(pid: record.pid)?.isStopped == true })

        // Same pid, different start time: the pid now belongs to some other process.
        AppProcesses.resume(ProcessRecord(pid: record.pid, startTime: record.startTime + 1))
        Thread.sleep(forTimeInterval: 0.2)

        #expect(AppProcesses.entry(pid: record.pid)?.isStopped == true)
    }

    private func startSleep() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        try process.run()
        return process
    }

    private func waitUntil(_ condition: () -> Bool) -> Bool {
        for _ in 0..<50 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.02)
        }
        return false
    }
}

/// Docker Desktop answers GET /containers/json with a JSON array of running containers.
struct DockerProbeTests {
    @Test func noRunningContainersIsIdle() {
        #expect(DockerProbe.isIdle(response: "HTTP/1.0 200 OK\r\nContent-Type: application/json\r\n\r\n[]\n"))
    }

    @Test func runningContainerIsBusy() {
        let response = "HTTP/1.0 200 OK\r\nContent-Type: application/json\r\n\r\n[{\"Id\":\"abc\",\"State\":\"running\"}]\n"
        #expect(!DockerProbe.isIdle(response: response))
    }

    @Test func errorAnswerIsNotIdle() {
        #expect(!DockerProbe.isIdle(response: "HTTP/1.0 500 Internal Server Error\r\n\r\n{\"message\":\"boom\"}"))
    }

    @Test func garbageIsNotIdle() {
        #expect(!DockerProbe.isIdle(response: ""))
        #expect(!DockerProbe.isIdle(response: "HTTP/1.0 200 OK\r\n\r\nnot json"))
    }

    @Test func missingSocketIsNotIdle() {
        #expect(!DockerProbe.isIdle(socketPath: "/nonexistent/docker.sock"))
    }
}
