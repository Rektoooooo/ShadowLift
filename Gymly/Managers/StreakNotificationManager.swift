//
//  StreakNotificationManager.swift
//  Gymly
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation
import SwiftData

@MainActor
class StreakNotificationManager: ObservableObject {
    static let shared = StreakNotificationManager()

    private let notificationManager = NotificationManager.shared
    private var userProfileManager: UserProfileManager?
    private var config: Config?

    private init() {}

    // MARK: - Setup

    func setup(userProfileManager: UserProfileManager, config: Config) {
        self.userProfileManager = userProfileManager
        self.config = config
    }

    // MARK: - Streak Protection Logic

    /// Schedule streak protection notification based on user's workout history and rest days
    func scheduleStreakProtection() {
        guard let config = config,
              let userProfileManager = userProfileManager,
              let profile = userProfileManager.currentProfile else {
            #if DEBUG
            debugLog("⚠️ STREAK NOTIFICATION: Missing dependencies")
            #endif
            return
        }

        // Check if notifications are enabled
        guard config.notificationsEnabled && config.streakNotificationsEnabled else {
            #if DEBUG
            debugLog("🔔 STREAK NOTIFICATION: Disabled in settings")
            #endif
            return
        }

        // Check if user has a streak to protect
        guard profile.currentStreak > 0 else {
            #if DEBUG
            debugLog("🔔 STREAK NOTIFICATION: No streak to protect (streak = 0)")
            #endif
            return
        }

        // Check if streak is paused
        guard !profile.streakPaused else {
            #if DEBUG
            debugLog("🔔 STREAK NOTIFICATION: Streak is paused")
            #endif
            return
        }

        guard let lastWorkoutDate = profile.lastWorkoutDate else {
            #if DEBUG
            debugLog("⚠️ STREAK NOTIFICATION: No last workout date")
            #endif
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastWorkoutDay = calendar.startOfDay(for: lastWorkoutDate)
        let daysSinceLastWorkout = calendar.dateComponents([.day], from: lastWorkoutDay, to: today).day ?? 0

        // Calculate max allowed gap based on rest days per week
        // Must match the streak calculation in UserProfileManager: maxAllowedGap = 1 + restDaysPerWeek
        // This means user can skip up to restDaysPerWeek days, plus 1 day grace period
        let restDaysPerWeek = profile.restDaysPerWeek
        let maxAllowedGap = 1 + restDaysPerWeek

        #if DEBUG
        debugLog("🔥 STREAK NOTIFICATION: Current streak = \(profile.currentStreak)")
        debugLog("🔥 STREAK NOTIFICATION: Days since last workout = \(daysSinceLastWorkout)")
        debugLog("🔥 STREAK NOTIFICATION: Max allowed gap = \(maxAllowedGap) days (rest days per week)")
        #endif

        // Cancel any existing streak notifications first
        notificationManager.cancelNotification(withId: NotificationManager.NotificationID.streakWarning)

        // Calculate days until streak breaks
        let daysUntilBreak = maxAllowedGap - daysSinceLastWorkout

        if daysUntilBreak == 1 {
            // Streak will break tomorrow! Send urgent notification
            scheduleStreakWarningNotification(
                streak: profile.currentStreak,
                daysUntilBreak: 1
            )
        } else if daysUntilBreak == 0 {
            // Streak is breaking today! Send very urgent notification
            scheduleStreakWarningNotification(
                streak: profile.currentStreak,
                daysUntilBreak: 0
            )
        } else if daysUntilBreak < 0 {
            // Streak already broken (should have been reset by checkStreakStatus)
            #if DEBUG
            debugLog("⚠️ STREAK NOTIFICATION: Streak should have been reset (days until break = \(daysUntilBreak))")
            #endif
        } else {
            #if DEBUG
            debugLog("✅ STREAK NOTIFICATION: Streak safe for \(daysUntilBreak) more days")
            #endif
        }
    }

    /// Schedule a streak warning notification
    private func scheduleStreakWarningNotification(streak: Int, daysUntilBreak: Int) {
        let calendar = Calendar.current

        // Calculate when to send the notification
        let notificationDate: Date
        if daysUntilBreak == 0 {
            // Send in 2 hours if breaking today
            notificationDate = calendar.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        } else {
            // Send tomorrow at 9 AM if breaking tomorrow
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.day! += 1
            components.hour = 9
            components.minute = 0
            notificationDate = calendar.date(from: components) ?? Date()
        }

        let title: String
        let body: String

        if daysUntilBreak == 0 {
            // Today is the last day
            title = "Your \(streak)-day streak is at risk! 🔥"
            body = "Work out today to keep your streak alive!"
        } else {
            // Tomorrow is the last day
            title = "Don't break your \(streak)-day streak! 🔥"
            body = "You need to work out tomorrow to maintain your streak"
        }

        Task {
            do {
                try await notificationManager.scheduleNotification(
                    id: NotificationManager.NotificationID.streakWarning,
                    title: title,
                    body: body,
                    date: notificationDate,
                    categoryIdentifier: NotificationManager.NotificationCategory.streak,
                    userInfo: ["type": "streak_warning", "streak": streak]
                )

                #if DEBUG
                debugLog("✅ STREAK NOTIFICATION: Scheduled warning for \(notificationDate)")
                #endif
            } catch {
                #if DEBUG
                debugLog("❌ STREAK NOTIFICATION: Failed to schedule - \(error)")
                #endif
            }
        }
    }

    /// Send notification celebrating streak save
    func sendStreakSavedNotification(newStreak: Int) {
        guard let config = config else { return }

        guard config.notificationsEnabled && config.streakNotificationsEnabled else {
            return
        }

        // Cancel warning since streak was saved
        notificationManager.cancelNotification(withId: NotificationManager.NotificationID.streakWarning)

        let title = "Streak saved! 🎉"
        let body = "\(newStreak) days and counting. You're unstoppable!"

        Task {
            do {
                // Send immediately (5 seconds from now)
                try await notificationManager.scheduleNotification(
                    id: NotificationManager.NotificationID.streakSaved,
                    title: title,
                    body: body,
                    timeInterval: 5,
                    categoryIdentifier: NotificationManager.NotificationCategory.streak,
                    userInfo: ["type": "streak_saved", "streak": newStreak]
                )

                #if DEBUG
                debugLog("✅ STREAK NOTIFICATION: Sent streak saved notification (streak = \(newStreak))")
                #endif
            } catch {
                #if DEBUG
                debugLog("❌ STREAK NOTIFICATION: Failed to send streak saved - \(error)")
                #endif
            }
        }
    }

    /// Send notification celebrating streak milestone
    func sendStreakMilestoneNotification(streak: Int) {
        guard let config = config else { return }

        guard config.notificationsEnabled && config.streakNotificationsEnabled else {
            return
        }

        // Only celebrate meaningful milestones
        let milestones = [7, 14, 30, 50, 100, 365]
        guard milestones.contains(streak) else { return }

        let title: String
        let body: String

        switch streak {
        case 7:
            title = "One Week Streak! 🔥"
            body = "7 days of consistency. Amazing start!"
        case 14:
            title = "Two Weeks Strong! 💪"
            body = "14 days down. You're building a solid habit!"
        case 30:
            title = "30-Day Streak! 🏆"
            body = "One month of dedication. Incredible achievement!"
        case 50:
            title = "50-Day Streak! ⭐"
            body = "You're in the top 1% of consistent trainers!"
        case 100:
            title = "100-Day Streak! 🎖️"
            body = "This is legendary. Keep the fire burning!"
        case 365:
            title = "ONE YEAR STREAK! 👑"
            body = "365 days of pure dedication. You're unstoppable!"
        default:
            return
        }

        Task {
            do {
                try await notificationManager.scheduleNotification(
                    id: NotificationManager.NotificationID.streakMilestone,
                    title: title,
                    body: body,
                    timeInterval: 5,
                    categoryIdentifier: NotificationManager.NotificationCategory.streak,
                    userInfo: ["type": "streak_milestone", "streak": streak]
                )

                #if DEBUG
                debugLog("✅ STREAK NOTIFICATION: Sent milestone notification (streak = \(streak))")
                #endif
            } catch {
                #if DEBUG
                debugLog("❌ STREAK NOTIFICATION: Failed to send milestone - \(error)")
                #endif
            }
        }
    }

    /// Reschedule all streak notifications (call when settings change or app launches)
    func rescheduleAllStreakNotifications() {
        #if DEBUG
        debugLog("🔄 STREAK NOTIFICATION: Rescheduling all streak notifications")
        #endif
        scheduleStreakProtection()
    }
}
