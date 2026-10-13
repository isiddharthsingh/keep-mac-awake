import Foundation
import IOKit.pwr_mgt
import Testing
@testable import AwakeCore

/// Talks to the real power manager: checks the assertions macOS reports for this process.
@MainActor
struct PowerAssertionBlockerTests {
    let reason = "AwakeCoreTests \(UUID().uuidString)"

    @Test func createsAndReleasesRealAssertions() {
        let blocker = PowerAssertionBlocker(reason: reason)

        blocker.apply(.systemAndDisplay)
        #expect(heldAssertionTypes() == ["PreventUserIdleSystemSleep", "PreventUserIdleDisplaySleep"])

        blocker.apply(.system)
        #expect(heldAssertionTypes() == ["PreventUserIdleSystemSleep"])

        blocker.apply(.off)
        #expect(heldAssertionTypes().isEmpty)
    }

    private func heldAssertionTypes() -> Set<String> {
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&unmanaged) == kIOReturnSuccess,
              let byPID = unmanaged?.takeRetainedValue() as? [NSNumber: [[String: Any]]]
        else { return [] }
        let mine = byPID[NSNumber(value: ProcessInfo.processInfo.processIdentifier)] ?? []
        return Set(mine.filter { $0["AssertName"] as? String == reason }.compactMap { $0["AssertType"] as? String })
    }
}
