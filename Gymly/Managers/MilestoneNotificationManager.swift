//
//  MilestoneNotificationManager.swift
//  Gymly
//
//  Created by Claude Code on 26.11.2025.
//

import Foundation

@MainActor
class MilestoneNotificationManager: ObservableObject {
    static let shared = MilestoneNotificationManager()

    private let notificationManager = NotificationManager.shared
    private var config: Config?

    private init() {}

    // MARK: - Setup

    func setup(config: Config) {
        self.config = config
    }

    // MARK: - Progress Milestone Notifications

    /// Send notification for a new Personal Record
    func sendPRNotification(prNotification: PRNotification) {
        guard let config = config else { return }

        guard config.notificationsEnabled && config.progressMilestonesEnabled else {
            return
        }

        let title: String
        let body: String

        switch prNotification.type {
        case .weight:
            title = "New PR! 💪"
            body = "\(prNotification.exerciseName): \(Int(prNotification.value)) kg × \(prNotification.reps ?? 0) reps - Your strongest yet!"
        case .oneRM:
            title = "New 1RM Record! 🏆"
            body = "\(prNotification.exerciseName): \(Int(prNotification.value)) kg estimated 1RM!"
        case .volume:
            title = "Volume PR! 📈"
            body = "\(prNotification.exerciseName): \(Int(prNotification.value)) kg total volume!"
        case .fiveRM:
            title = "5RM PR! 💪"
            body = "\(prNotification.exerciseName): \(Int(prNotification.value)) kg for 5 reps!"
        case .tenRM:
            title = "10RM PR! 🔥"
            body = "\(prNotification.exerciseName): \(Int(prNotification.value)) kg for 10 reps!"
        }

        Task {
            do {
                try await notificationManager.scheduleNotification(
                    id: "pr_\(UUID().uuidString)",
                    title: title,
                    body: body,
                    timeInterval: 2, // Send immediately (2 seconds)
                    categoryIdentifier: NotificationManager.NotificationCategory.progress,
                    userInfo: ["type": "pr", "exercise": prNotification.exerciseName]
                )

                #if DEBUG
                print("✅ MILESTONE: Sent PR notification - \(title)")
                #endif
            } catch {
                #if DEBUG
                print("❌ MILESTONE: Failed to send PR notification - \(error)")
                #endif
            }
        }
    }

    /// Send notification for streak milestones (handled by StreakNotificationManager)
    /// This is a placeholder for other achievement types

    /// Send notification for workout count milestones
    func sendWorkoutCountMilestone(count: Int) {
        guard let config = config else { return }

        guard config.notificationsEnabled && config.progressMilestonesEnabled else {
            return
        }

        // Only celebrate meaningful milestones
        let milestones = [10, 25, 50, 100, 200, 365, 500, 1000]
        guard milestones.contains(count) else { return }

        let title: String
        let body: String

        switch count {
        case 10:
            title = "10 Workouts Complete! 🎯"
            body = "You're building momentum. Keep going!"
        case 25:
            title = "25 Workouts! 💪"
            body = "A quarter century of dedication!"
        case 50:
            title = "50 Workouts! 🔥"
            body = "You're officially committed to greatness!"
        case 100:
            title = "100 Workouts! 💯"
            body = "Century club! You're unstoppable!"
        case 200:
            title = "200 Workouts! ⭐"
            body = "Double century! Elite dedication!"
        case 365:
            title = "365 Workouts! 🏆"
            body = "A full year of commitment. Legendary status!"
        case 500:
            title = "500 Workouts! 👑"
            body = "Half a thousand workouts. You're a machine!"
        case 1000:
            title = "1000 WORKOUTS! 🎖️"
            body = "Four digits. You've achieved immortality!"
        default:
            title = "\(count) Workouts! 🎉"
            body = "Every rep brings you closer to your goals!"
        }

        Task {
            do {
                try await notificationManager.scheduleNotification(
                    id: "workout_count_\(count)",
                    title: title,
                    body: body,
                    timeInterval: 2,
                    categoryIdentifier: NotificationManager.NotificationCategory.progress,
                    userInfo: ["type": "workout_count", "count": count]
                )

                #if DEBUG
                print("✅ MILESTONE: Sent workout count milestone - \(count) workouts")
                #endif
            } catch {
                #if DEBUG
                print("❌ MILESTONE: Failed to send workout count milestone - \(error)")
                #endif
            }
        }
    }
}
