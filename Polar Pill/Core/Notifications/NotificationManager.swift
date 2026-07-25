//
//  NotificationManager.swift
//  Polar Pill
//
//  Notification permission, patient dose reminders, and caregiver
//  missed-dose notifications.
//
//  MVP assumption: true remote push (APNs) needs an Apple Developer push key
//  and a provider. Instead, caregiver devices subscribe to alerts via
//  Supabase Realtime and raise a LOCAL notification when one arrives —
//  same UX while the app is running, no push infrastructure.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    /// Set by the caregiver dashboard — invoked when the user taps a
    /// missed-dose notification, deep-linking to the alert screen.
    var onMissedDoseAlertTapped: ((UUID) -> Void)?

    /// Call once at app launch so foreground banners and taps are handled.
    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Asks for alert/sound/badge permission. Safe to call repeatedly —
    /// the system only shows the prompt once.
    @discardableResult
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Patient dose reminders (local, repeating)

    /// Re-schedules local reminders for the patient's medications.
    func scheduleDoseReminders(for medications: [Medication]) async {
        let center = UNUserNotificationCenter.current()

        // Clear previous dose reminders before re-scheduling.
        let pending = await center.pendingNotificationRequests()
        let doseIDs = pending.map(\.identifier).filter { $0.hasPrefix("dose-") }
        center.removePendingNotificationRequests(withIdentifiers: doseIDs)

        for medication in medications where medication.remindersEnabled {
            let time = medication.timeComponents
            let content = UNMutableNotificationContent()
            content.title = "Time for your \(medication.name)"
            content.body = medication.dosage.isEmpty
                ? "Tap your phone to the box or scan the QR code to mark it as taken."
                : "\(medication.dosage) — scan the QR code on the box to mark it as taken."
            content.sound = .default

            switch medication.frequency {
            case .daily:
                var components = DateComponents()
                components.hour = time.hour
                components.minute = time.minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "dose-\(medication.id.uuidString)",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            case .weekly, .custom:
                // Monday-based weekdays (1 = Mon) → Calendar weekdays (1 = Sun).
                let weekdays = medication.customSchedule?.weekdays ?? []
                for weekday in weekdays {
                    var components = DateComponents()
                    components.hour = time.hour
                    components.minute = time.minute
                    components.weekday = weekday == 7 ? 1 : weekday + 1
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let request = UNNotificationRequest(
                        identifier: "dose-\(medication.id.uuidString)-\(weekday)",
                        content: content,
                        trigger: trigger
                    )
                    try? await center.add(request)
                }
            }
        }
    }

    // MARK: - Caregiver missed-dose notifications

    /// Raises an immediate local notification for a new alert (called when
    /// Supabase Realtime delivers an alerts insert).
    func postMissedDoseNotification(alertID: UUID, message: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Polar Pill"
        content.body = message
        content.sound = .default
        content.userInfo = ["alert_id": alertID.uuidString]

        let request = UNNotificationRequest(
            identifier: "alert-\(alertID.uuidString)",
            content: content,
            trigger: nil // deliver immediately
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banners even while the app is in the foreground.
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let idString = userInfo["alert_id"] as? String, let alertID = UUID(uuidString: idString) {
            Task { @MainActor in
                NotificationManager.shared.onMissedDoseAlertTapped?(alertID)
            }
        }
        completionHandler()
    }
}
