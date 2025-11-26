//
//  NotificationManager.swift
//  Gymly
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    /// Check current notification authorization status
    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized

        #if DEBUG
        print("🔔 Notification Status: \(authorizationStatus.rawValue)")
        #endif
    }

    /// Request notification permissions from user
    func requestAuthorization() async throws {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await checkAuthorizationStatus()

            #if DEBUG
            print(granted ? "✅ Notification permission granted" : "❌ Notification permission denied")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to request notification authorization: \(error)")
            #endif
            throw error
        }
    }

    /// Open app settings for user to manually enable notifications
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Scheduling Notifications

    /// Schedule a notification with specified parameters
    func scheduleNotification(
        id: String,
        title: String,
        body: String,
        date: Date,
        repeats: Bool = false,
        categoryIdentifier: String? = nil,
        userInfo: [String: Any] = [:]
    ) async throws {
        guard isAuthorized else {
            #if DEBUG
            print("⚠️ Cannot schedule notification - not authorized")
            #endif
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        if let category = categoryIdentifier {
            content.categoryIdentifier = category
        }

        content.userInfo = userInfo

        // Create date components from date
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await center.add(request)
            #if DEBUG
            print("✅ Scheduled notification '\(id)' for \(date)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to schedule notification '\(id)': \(error)")
            #endif
            throw error
        }
    }

    /// Schedule a notification with custom DateComponents (for repeating weekday notifications)
    func scheduleNotification(
        id: String,
        title: String,
        body: String,
        dateComponents: DateComponents,
        repeats: Bool = false,
        categoryIdentifier: String? = nil,
        userInfo: [String: Any] = [:]
    ) async throws {
        guard isAuthorized else {
            #if DEBUG
            print("⚠️ Cannot schedule notification - not authorized")
            #endif
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        if let category = categoryIdentifier {
            content.categoryIdentifier = category
        }

        content.userInfo = userInfo

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await center.add(request)
            #if DEBUG
            print("✅ Scheduled notification '\(id)' with date components (repeats: \(repeats))")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to schedule notification '\(id)': \(error)")
            #endif
            throw error
        }
    }

    /// Schedule a notification after a time interval
    func scheduleNotification(
        id: String,
        title: String,
        body: String,
        timeInterval: TimeInterval,
        repeats: Bool = false,
        categoryIdentifier: String? = nil,
        userInfo: [String: Any] = [:]
    ) async throws {
        guard isAuthorized else {
            #if DEBUG
            print("⚠️ Cannot schedule notification - not authorized")
            #endif
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        if let category = categoryIdentifier {
            content.categoryIdentifier = category
        }

        content.userInfo = userInfo

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await center.add(request)
            #if DEBUG
            print("✅ Scheduled notification '\(id)' in \(timeInterval) seconds")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to schedule notification '\(id)': \(error)")
            #endif
            throw error
        }
    }

    // MARK: - Managing Notifications

    /// Cancel a specific notification by ID
    func cancelNotification(withId id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        #if DEBUG
        print("🗑️ Cancelled notification '\(id)'")
        #endif
    }

    /// Cancel all pending notifications
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        #if DEBUG
        print("🗑️ Cancelled all pending notifications")
        #endif
    }

    /// Get all pending notifications
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }

    /// Check if a specific notification is scheduled
    func isNotificationScheduled(withId id: String) async -> Bool {
        let pending = await getPendingNotifications()
        return pending.contains { $0.identifier == id }
    }

    // MARK: - Badge Management

    /// Set app badge number
    func setBadgeCount(_ count: Int) {
        center.setBadgeCount(count)
    }

    /// Clear app badge
    func clearBadge() {
        center.setBadgeCount(0)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle user interaction with notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        #if DEBUG
        print("📬 User tapped notification: \(userInfo)")
        #endif

        // Handle different notification actions here
        // TODO: Add deep linking based on notification type

        completionHandler()
    }
}

// MARK: - Notification Identifiers

extension NotificationManager {
    /// Notification identifier constants
    enum NotificationID {
        // Streak notifications
        static let streakWarning = "streak_warning"
        static let streakSaved = "streak_saved"
        static let streakMilestone = "streak_milestone"

        // Workout reminders
        static let workoutReminder = "workout_reminder"
        static let restDayReminder = "rest_day_reminder"

        // Split progression
        static let nextWorkoutPreview = "next_workout_preview"
        static let splitCompleted = "split_completed"

        // Progress milestones
        static let newPR = "new_pr"
        static let volumeMilestone = "volume_milestone"
        static let workoutMilestone = "workout_milestone"

        // Inactivity
        static let inactivityReminder = "inactivity_reminder"
        static let inactive3Days = "inactive_3_days"
        static let inactive7Days = "inactive_7_days"
        static let inactive14Days = "inactive_14_days"

        // Weekly summary
        static let weeklySummary = "weekly_summary"

        // Rest warnings
        static let overtrainingWarning = "overtraining_warning"

        // Incomplete workout
        static let incompleteWorkout = "incomplete_workout"
    }

    /// Notification categories for grouping
    enum NotificationCategory {
        static let streak = "STREAK_CATEGORY"
        static let workout = "WORKOUT_CATEGORY"
        static let workoutReminder = "WORKOUT_REMINDER_CATEGORY"
        static let progress = "PROGRESS_CATEGORY"
        static let inactivity = "INACTIVITY_CATEGORY"
    }
}
