import Foundation
import Testing
@testable import AwakeCore

/// Records what lid mode asked the Mac to do, in order.
@MainActor
final class FakeLidSystem: LidSystem {
    var lidClosed: Bool? = false
    var externalDisplay = false
    var output: AudioOutput? = AudioOutput(uid: "speakers", isMuted: false)
    var dockerIdle = false
    var processesByApp: [String: [ProcessRecord]] = [:]
    private(set) var events: [String] = []
    /// Runs as each process is paused, to look at what the journal held by then.
    var onPause: ((ProcessRecord) -> Void)?

    /// The argument of each setLidSleepDisabled call: true when lid sleep was turned off.
    var lidSleepDisabledCalls: [Bool] {
        events.compactMap { $0 == "lid sleep disabled" ? true : $0 == "lid sleep allowed" ? false : nil }
    }

    func isLidClosed() -> Bool? { lidClosed }
    func setLidSleepDisabled(_ disabled: Bool) { events.append(disabled ? "lid sleep disabled" : "lid sleep allowed") }
    func hasExternalDisplay() -> Bool { externalDisplay }
    func turnOffDisplay() { events.append("display off") }
    func currentOutput() -> AudioOutput? { output }
    func setMuted(_ muted: Bool, outputUID: String) {
        if output?.uid == outputUID { output?.isMuted = muted }
        events.append("\(muted ? "mute" : "unmute") \(outputUID)")
    }
    func isDockerIdle() -> Bool { dockerIdle }
    func runningProcesses(ofApps bundleIDs: [String]) -> [ProcessRecord] {
        bundleIDs.flatMap { processesByApp[$0] ?? [] }
    }
    func pause(_ process: ProcessRecord) {
        onPause?(process)
        events.append("pause \(process.pid)")
    }
    func resume(_ process: ProcessRecord) { events.append("resume \(process.pid)") }
}

func temporaryJournal() -> LidJournalStore {
    LidJournalStore(url: FileManager.default.temporaryDirectory
        .appendingPathComponent("AwakeCoreTests-\(UUID().uuidString)/lid-journal.json"))
}

extension LidJournalStore {
    /// Removes the test's own temporary folder.
    func removeFolder() {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

@MainActor
final class LidModeTests {
    let system = FakeLidSystem()
    let journal = temporaryJournal()
    let lid: LidMode
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let slack = ProcessRecord(pid: 501, startTime: 11)
    let slackHelper = ProcessRecord(pid: 502, startTime: 12)
    let discord = ProcessRecord(pid: 601, startTime: 21)
    let docker = ProcessRecord(pid: 701, startTime: 31)

    init() {
        lid = LidMode(system: system, journal: journal)
        system.processesByApp = [
            "com.tinyspeck.slackmacgap": [slack, slackHelper],
            "com.hnc.Discord": [discord],
            "com.docker.docker": [docker],
        ]
    }

    deinit { journal.removeFolder() }

    /// Starts a session with lid mode on and the lid open, then forgets the setup calls.
    private func runSessionWithLidOpen() -> FakeLidSystem {
        lid.isEnabled = true
        lid.sessionDidStart()
        lid.update(now: start)
        return system
    }

    private func closeLid(at seconds: TimeInterval = 1) {
        system.lidClosed = true
        lid.update(now: start + seconds)
    }

    private func openLid(at seconds: TimeInterval = 2) {
        system.lidClosed = false
        lid.update(now: start + seconds)
    }

    @Test func reportsMacWithoutLid() {
        system.lidClosed = nil

        #expect(!LidMode(system: system, journal: journal).hasLid)
        #expect(lid.hasLid)
    }

    @Test func enabledLidModeStopsLidSleepDuringSession() {
        lid.isEnabled = true
        lid.sessionDidStart()
        lid.update(now: start)

        #expect(system.lidSleepDisabledCalls == [true])
    }

    @Test func disabledLidModeLeavesLidSleepAlone() {
        lid.sessionDidStart()
        lid.update(now: start)
        closeLid()

        #expect(system.events.isEmpty)
    }

    @Test func macWithoutLidNeverTouchesLidSleep() {
        system.lidClosed = nil
        let lid = LidMode(system: system, journal: journal)
        lid.isEnabled = true  // e.g. settings carried over from a laptop
        lid.sessionDidStart()
        lid.update(now: start)

        #expect(system.events.isEmpty)
        #expect(journal.load() == LidJournal())
    }

    @Test func enablingLidModeWhileIdleChangesNothing() {
        lid.isEnabled = true

        #expect(system.events.isEmpty)
    }

    @Test func stopsLidSleepAgainOnEveryUpdate() {
        _ = runSessionWithLidOpen()
        lid.update(now: start + 1)
        lid.update(now: start + 2)

        // powerd resets the flag when the charger or a display changes, so each update sets it again.
        #expect(system.lidSleepDisabledCalls == [true, true, true])
    }

    @Test func endingSessionAllowsLidSleepAgain() {
        _ = runSessionWithLidOpen()
        lid.sessionDidStop()

        #expect(system.lidSleepDisabledCalls.last == false)
    }

    @Test func turningLidModeOffDuringSessionAllowsLidSleepAtOnce() {
        _ = runSessionWithLidOpen()
        lid.isEnabled = false

        #expect(system.lidSleepDisabledCalls.last == false)
    }

    @Test func turningLidModeOnDuringSessionStopsLidSleepAtOnce() {
        lid.sessionDidStart()
        lid.update(now: start)
        lid.isEnabled = true

        #expect(system.lidSleepDisabledCalls == [true])
    }

    @Test func closingLidMutesTurnsScreenOffAndPausesChatApps() {
        _ = runSessionWithLidOpen()
        closeLid()

        #expect(system.output?.isMuted == true)
        #expect(system.events.contains("display off"))
        #expect(system.events.filter { $0.hasPrefix("pause") } == ["pause 501", "pause 502", "pause 601"])
        #expect(lid.isActingOnClosedLid)
    }

    @Test func closedLidActionsRunOnce() {
        _ = runSessionWithLidOpen()
        closeLid(at: 1)
        lid.update(now: start + 2)
        lid.update(now: start + 3)

        #expect(system.events.filter { $0 == "display off" }.count == 1)
        #expect(system.events.filter { $0 == "pause 501" }.count == 1)
    }

    @Test func openingLidUndoesActions() {
        _ = runSessionWithLidOpen()
        closeLid()
        openLid()

        #expect(system.output?.isMuted == false)
        #expect(system.events.filter { $0.hasPrefix("resume") } == ["resume 501", "resume 502", "resume 601"])
        #expect(!lid.isActingOnClosedLid)
        #expect(system.lidSleepDisabledCalls.last == true)
    }

    @Test func externalDisplayLeavesScreenSoundAndAppsAlone() {
        system.externalDisplay = true
        _ = runSessionWithLidOpen()
        closeLid()

        #expect(system.events.allSatisfy { $0.hasPrefix("lid sleep") })
        #expect(!lid.isActingOnClosedLid)
    }

    @Test func unpluggingExternalDisplayWithLidClosedStartsActions() {
        system.externalDisplay = true
        _ = runSessionWithLidOpen()
        closeLid(at: 1)

        system.externalDisplay = false
        lid.update(now: start + 2)

        #expect(system.events.contains("display off"))
        #expect(lid.isActingOnClosedLid)
    }

    @Test func outputThatWasAlreadyMutedStaysMuted() {
        system.output = AudioOutput(uid: "speakers", isMuted: true)
        _ = runSessionWithLidOpen()
        closeLid()
        openLid()

        #expect(system.output?.isMuted == true)
        #expect(!system.events.contains { $0.hasPrefix("mute") || $0.hasPrefix("unmute") })
    }

    @Test func optionsChooseWhichActionsRun() {
        lid.options = LidCloseOptions(turnOffScreen: false, muteSound: false, pauseChatApps: false, pauseIdleDocker: false)
        _ = runSessionWithLidOpen()
        closeLid()

        #expect(system.events.allSatisfy { $0.hasPrefix("lid sleep") })
        #expect(lid.isActingOnClosedLid)
    }

    @Test func dockerIsPausedOnlyWhenChosenAndIdle() {
        lid.options = LidCloseOptions(turnOffScreen: false, muteSound: false, pauseChatApps: false, pauseIdleDocker: true)
        _ = runSessionWithLidOpen()

        closeLid(at: 1)
        #expect(!system.events.contains("pause 701"))

        openLid(at: 2)
        system.dockerIdle = true
        closeLid(at: 3)
        #expect(system.events.contains("pause 701"))
    }

    @Test func dockerIsLeftRunningByDefault() {
        system.dockerIdle = true
        _ = runSessionWithLidOpen()
        closeLid()

        #expect(!system.events.contains("pause 701"))
    }

    @Test func journalNamesEachProcessBeforeItIsPaused() {
        var journaledAtPause: [[ProcessRecord]] = []
        let journal = journal
        system.onPause = { _ in journaledAtPause.append(journal.load().pausedProcesses) }
        _ = runSessionWithLidOpen()
        closeLid()

        #expect(journaledAtPause.allSatisfy { $0 == [slack, slackHelper, discord] })
    }

    @Test func journalNamesOutputBeforeItIsMuted() {
        _ = runSessionWithLidOpen()
        closeLid()

        #expect(journal.load().mutedOutputUID == "speakers")
        #expect(journal.load().lidSleepDisabled)
    }

    @Test func journalIsClearedWhenSessionEnds() {
        _ = runSessionWithLidOpen()
        closeLid()
        lid.sessionDidStop()

        #expect(journal.load() == LidJournal())
    }

    @Test func endingSessionWithLidClosedUndoesActionsBeforeAllowingSleep() {
        _ = runSessionWithLidOpen()
        closeLid()
        lid.sessionDidStop()

        let tail = system.events.suffix(5)
        #expect(Array(tail) == ["resume 501", "resume 502", "resume 601", "unmute speakers", "lid sleep allowed"])
        #expect(!lid.isActingOnClosedLid)
    }

    @Test func recoverUndoesWhatAnEndedRunLeftBehind() {
        journal.save(LidJournal(lidSleepDisabled: true, mutedOutputUID: "speakers", pausedProcesses: [slack, discord]))
        system.output = AudioOutput(uid: "speakers", isMuted: true)

        LidMode.recover(system: system, journal: journal)

        #expect(system.events == ["resume 501", "resume 601", "unmute speakers", "lid sleep allowed"])
        #expect(journal.load() == LidJournal())
    }

    @Test func actionsAreSkippedWhenJournalCannotBeWritten() throws {
        // A file where the journal's folder should be, so every save fails.
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent("AwakeCoreTests-\(UUID().uuidString)")
        try Data().write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }
        let lid = LidMode(system: system, journal: LidJournalStore(url: blocker.appendingPathComponent("lid-journal.json")))
        lid.isEnabled = true
        lid.sessionDidStart()
        lid.update(now: start)
        system.lidClosed = true
        lid.update(now: start + 1)

        // Nothing could be undone after a crash, so nothing is muted or paused.
        #expect(system.output?.isMuted == false)
        #expect(!system.events.contains { $0.hasPrefix("pause") || $0.hasPrefix("mute") })
    }

    @Test func recoverAfterLidModeAllowsLidSleepEvenWithEmptyJournal() {
        LidMode.recover(system: system, journal: journal, lidSleepWasDisabled: true)

        #expect(system.lidSleepDisabledCalls == [false])
    }

    @Test func recoverWithNothingJournaledChangesNothing() {
        LidMode.recover(system: system, journal: journal)

        #expect(system.events.isEmpty)
    }

    @Test func countsTimeTheLidStaysClosed() {
        _ = runSessionWithLidOpen()
        system.lidClosed = true
        for second in 1...120 { lid.update(now: start + TimeInterval(second)) }

        #expect(lid.closedTime == 120)
    }

    @Test func longGapWhileClosedIsNotCounted() {
        _ = runSessionWithLidOpen()
        closeLid(at: 1)
        lid.update(now: start + 3600)  // the Mac slept, so no updates ran in between

        #expect(lid.closedTime < 60)
    }

    @Test func newSessionStartsClosedTimeAtZero() {
        _ = runSessionWithLidOpen()
        closeLid(at: 1)
        lid.update(now: start + 2)
        lid.sessionDidStop()

        lid.sessionDidStart()
        #expect(lid.closedTime == 0)
    }
}

struct LidJournalStoreTests {
    @Test func savedJournalReadsBack() {
        let store = temporaryJournal()
        defer { store.removeFolder() }
        let journal = LidJournal(lidSleepDisabled: true, mutedOutputUID: "speakers",
                                 pausedProcesses: [ProcessRecord(pid: 1, startTime: 2)])

        store.save(journal)

        #expect(store.load() == journal)
    }

    @Test func missingJournalReadsAsEmpty() {
        #expect(temporaryJournal().load() == LidJournal())
    }

    @Test func savingEmptyJournalRemovesFile() {
        let store = temporaryJournal()
        defer { store.removeFolder() }
        store.save(LidJournal(lidSleepDisabled: true))

        store.save(LidJournal())

        #expect(!FileManager.default.fileExists(atPath: store.url.path))
    }
}

@MainActor
struct LidWatchdogTests {
    /// kill(0, 0) and kill(-1, 0) succeed (they name process groups), so these must be refused before waiting.
    @Test(arguments: ["0", "-1", "1", "abc"])
    func ignoresArgumentsThatDoNotNameTheApp(pid: String) {
        LidWatchdog.runIfRequested(journal: temporaryJournal(), arguments: ["MacAwake", "--lid-watchdog", pid])
    }

    @Test func watchReportsWhenTheProcessExits() async throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["0.3"]
        try child.run()
        var exited = false
        let source = LidWatchdog.watch(child.processIdentifier) { exited = true }
        defer { source.cancel() }
        #expect(!exited)

        for _ in 0..<100 where !exited { try await Task.sleep(for: .milliseconds(50)) }
        #expect(exited)
    }

    @Test func watchReportsAProcessThatAlreadyExited() throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try child.run()
        child.waitUntilExit()
        var exited = false

        let source = LidWatchdog.watch(child.processIdentifier) { exited = true }
        defer { source.cancel() }

        #expect(exited)
    }
}

