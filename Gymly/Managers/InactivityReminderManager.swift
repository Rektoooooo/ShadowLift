//
//  InactivityReminderManager.swift
//  Gymly
//
//  Created by Claude Code on 26.11.2025.
//

import Foundation
import SwiftData

@MainActor
class InactivityReminderManager: ObservableObject {
    static let shared = InactivityReminderManager()

    private let notificationManager = NotificationManager.shared
    private var userProfileManager: UserProfileManager?
    private var config: Config?

    private init() {}

    // MARK: - Setup

    func setup(userProfileManager: UserProfileManager, config: Config) {
        self.userProfileManager = userProfileManager
        self.config = config
    }

    // MARK: - Inactivity Detection

    /// Check for inactivity and schedule reminder if needed
    func checkAndScheduleInactivityReminder() {
        guard let config = config,
              let userProfileManager = userProfileManager,
              let profile = userProfileManager.currentProfile else {
            #if DEBUG
            print("⚠️ INACTIVITY: Missing dependencies")
            #endif
            return
        }

        // Check if inactivity reminders are enabled
        guard config.notificationsEnabled && config.inactivityRemindersEnabled else {
            #if DEBUG
            print("🔔 INACTIVITY: Disabled in settings")
            #endif
            cancelInactivityReminder()
            return
        }

        // Check if user has worked out recently
        guard let lastWorkoutDate = profile.lastWorkoutDate else {
            // No workout history, don't send reminder yet
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastWorkoutDay = calendar.startOfDay(for: lastWorkoutDate)
        let daysSinceLastWorkout = calendar.dateComponents([.day], from: lastWorkoutDay, to: today).day ?? 0

        #if DEBUG
        print("📊 INACTIVITY: Days since last workout = \(daysSinceLastWorkout)")
        #endif

        // Cancel existing reminder
        cancelInactivityReminder()

        // Send reminder if inactive for 4+ days
        if daysSinceLastWorkout >= 4 {
            scheduleInactivityReminder(daysSinceLastWorkout: daysSinceLastWorkout)
        }
    }

    /// Schedule an inactivity reminder
    private func scheduleInactivityReminder(daysSinceLastWorkout: Int) {
        let title: String
        let body: String

        switch daysSinceLastWorkout {
        case 4:
            title = "We Miss You! 😊"
            body = "It's been 4 days since your last workout. Ready to get back?"
        case 5:
            title = "Time to Return! 💪"
            body = "5 days away. Your muscles are ready for action!"
        case 6:
            title = "Don't Lose Your Progress! 🔥"
            body = "6 days since your last workout. Let's keep the momentum going!"
        case 7:
            title = "One Week Break 😔"
            body = "A week since your last session. Every rep counts - let's go!"
        case 8...13:
            title = "Your Comeback Awaits! 💪"
            body = "It's been \(daysSinceLastWorkout) days. Start today and feel amazing!"
        case 14...20:
            title = "We Believe in You! 🌟"
            body = "\(daysSinceLastWorkout) days away. One workout is all it takes to restart!"
        default:
            title = "Time for a Fresh Start! 🚀"
            body = "Ready to begin again? Your fitness journey is waiting!"
        }

        // Schedule notification for tomorrow at 10 AM
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day! += 1
        components.hour = 10
        components.minute = 0

        guard let notificationDate = calendar.date(from: components) else {
            return
        }

        Task {
            do {
                try await notificationManager.scheduleNotification(
                    id: NotificationManager.NotificationID.inactivityReminder,
                    title: title,
                    body: body,
                    date: notificationDate,
                    categoryIdentifier: NotificationManager.NotificationCategory.inactivity,
                    userInfo: ["type": "inactivity", "days_since_workout": daysSinceLastWorkout]
                )

                #if DEBUG
                print("✅ INACTIVITY: Scheduled reminder for tomorrow at 10 AM (\(daysSinceLastWorkout) days inactive)")
                #endif
            } catch {
                #if DEBUG
                print("❌ INACTIVITY: Failed to schedule reminder - \(error)")
                #endif
            }
        }
    }

    /// Cancel inactivity reminder
    func cancelInactivityReminder() {
        notificationManager.cancelNotification(withId: NotificationManager.NotificationID.inactivityReminder)

        #if DEBUG
        print("🗑️ INACTIVITY: Cancelled reminder")
        #endif
    }

    /// Reschedule inactivity check (call this after workout completion or settings change)
    func rescheduleInactivityCheck() {
        #if DEBUG
        print("🔄 INACTIVITY: Rescheduling inactivity check")
        #endif
        checkAndScheduleInactivityReminder()
    }
}
