import AwakeCore
import Foundation
import UserNotifications

/// Posts "5 minutes left" before a timed session ends. macOS delivers it on the wall clock,
/// so it still shows on time if the app is napping or the Mac slept in between.
@MainActor
final class ReminderScheduler: NSObject, UNUserNotificationCenterDelegate {
    private static let lead: TimeInterval = 5 * 60
    private static let identifier = "fiveMinutesLeft"
    private let session: KeepAwakeSession
    private var askedForPermission = false

    /// `UNUserNotificationCenter.current()` traps in a binary that isn't inside an app bundle, such as `swift run`.
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleURL.pathExtension == "app" ? .current() : nil
    }

    init(session: KeepAwakeSession) {
        self.session = session
        super.init()
        center?.delegate = self
        followEndDate()
    }

    /// Withdraws a pending reminder, for example because the app is quitting and the session ends with it.
    func cancel() {
        center?.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }

    private func followEndDate() {
        withObservationTracking {
            schedule(for: session.endDate)
        } onChange: { [weak self] in
            Task { @MainActor in self?.followEndDate() }
        }
    }

    private func schedule(for endDate: Date?) {
        cancel()
        guard let center, let endDate, endDate.timeIntervalSinceNow > Self.lead + 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "5 minutes left"
        content.body = "Your Mac can sleep again at \(endDate.formatted(date: .omitted, time: .shortened))."
        content.sound = .default
        // The time zone pins the trigger to this moment, even across a DST change or a trip to another zone.
        let fireDate = Calendar.current.dateComponents(
            [.timeZone, .year, .month, .day, .hour, .minute, .second], from: endDate - Self.lead)
        let request = UNNotificationRequest(
            identifier: Self.identifier, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: fireDate, repeats: false))
        let askFirst = !askedForPermission
        askedForPermission = true
        Task {
            // The first time, wait for the answer, so the reminder isn't added before notifications are allowed.
            if askFirst { _ = try? await center.requestAuthorization(options: [.alert, .sound]) }
            // The session may have stopped or changed while the prompt was up.
            guard session.endDate == endDate else { return }
            try? await center.add(request)
        }
    }

    // Shows the banner even while the panel has made the app active.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
