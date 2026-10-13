import AwakeCore
import Sparkle

/// Saves the running session right before Sparkle relaunches the app to finish installing an update,
/// so the new version resumes the timer instead of starting idle.
@MainActor
final class UpdateSessionKeeper: NSObject, SPUUpdaterDelegate {
    private let session: KeepAwakeSession
    private let store: PendingSessionStore

    init(session: KeepAwakeSession, store: PendingSessionStore) {
        self.session = session
        self.store = store
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        store.save(session.snapshot)
    }
}
