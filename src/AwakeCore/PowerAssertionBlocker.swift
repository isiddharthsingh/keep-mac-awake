import IOKit.pwr_mgt

/// Prevents sleep with IOKit power assertions, the same mechanism `caffeinate` uses.
/// macOS releases the assertions automatically if the app quits or crashes.
@MainActor
public final class PowerAssertionBlocker: SleepBlocker {
    private let reason: String
    private var systemAssertion: IOPMAssertionID?
    private var displayAssertion: IOPMAssertionID?

    public init(reason: String) {
        self.reason = reason
    }

    public func apply(_ mode: BlockMode) {
        update(&systemAssertion, enabled: mode != .off,
               type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString)
        update(&displayAssertion, enabled: mode == .systemAndDisplay,
               type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString)
    }

    private func update(_ assertion: inout IOPMAssertionID?, enabled: Bool, type: CFString) {
        if enabled, assertion == nil {
            var id = IOPMAssertionID(0)
            let result = IOPMAssertionCreateWithName(
                type, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &id)
            if result == kIOReturnSuccess { assertion = id }
        } else if !enabled, let id = assertion {
            IOPMAssertionRelease(id)
            assertion = nil
        }
    }
}
