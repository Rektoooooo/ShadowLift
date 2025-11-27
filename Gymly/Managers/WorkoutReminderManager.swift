//
//  WorkoutReminderManager.swift
//  Gymly
//
//  Created by Claude Code on 26.11.2025.
//

import Foundation
import SwiftData

@MainActor
class WorkoutReminderManager: ObservableObject {
    static let shared = WorkoutReminderManager()

    private let notificationManager = NotificationManager.shared
    private var modelContext: ModelContext?
    private var config: Config?

    private init() {}

    // MARK: - Setup

    func setup(modelContext: ModelContext, config: Config) {
        self.modelContext = modelContext
        self.config = config
    }

    // MARK: - Workout Pattern Analysis

    /// Analyze workout patterns for each weekday and schedule reminders
    func scheduleSmartWorkoutReminders() {
        guard let config = config,
              let context = modelContext else {
            #if DEBUG
            print("⚠️ WORKOUT REMINDER: Missing dependencies")
            #endif
            return
        }

        // Check if workout reminders are enabled
        guard config.notificationsEnabled && config.workoutReminderEnabled else {
            #if DEBUG
            print("🔔 WORKOUT REMINDER: Disabled in settings")
            #endif
            cancelAllWorkoutReminders()
            return
        }

        #if DEBUG
        print("🔄 WORKOUT REMINDER: Analyzing workout patterns...")
        #endif

        // Analyze each weekday separately
        for weekday in 1...7 { // 1 = Sunday, 2 = Monday, ..., 7 = Saturday
            analyzeAndScheduleForWeekday(weekday, context: context, config: config)
        }
    }

    /// Analyze workout pattern for a specific weekday and schedule reminder
    private func analyzeAndScheduleForWeekday(_ weekday: Int, context: ModelContext, config: Config) {
        let calendar = Calendar.current
        let today = Date()

        // Get last 4 occurrences of this weekday
        var workoutTimes: [Date] = []
        var checkDate = today
        var foundCount = 0
        let maxWeeksBack = 8 // Look back up to 8 weeks to find 4 occurrences

        for _ in 0..<(maxWeeksBack * 7) {
            let components = calendar.dateComponents([.weekday], from: checkDate)
            if components.weekday == weekday {
                // Check if user worked out on this day
                if let workoutTime = getFirstSetTimeForDate(checkDate, context: context) {
                    workoutTimes.append(workoutTime)
                    foundCount += 1

                    if foundCount >= 4 {
                        break
                    }
                }
            }

            // Go back one day
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        #if DEBUG
        let weekdayName = calendar.weekdaySymbols[weekday - 1]
        print("📊 WORKOUT REMINDER: \(weekdayName) - Found \(workoutTimes.count) workouts in last 4 occurrences")
        #endif

        // Calculate optimal reminder time for this weekday
        if workoutTimes.count >= 2 { // Need at least 2 data points
            let averageWorkoutTime = calculateAverageTime(from: workoutTimes)
            scheduleReminderForWeekday(weekday, optimalTime: averageWorkoutTime, config: config)
        } else {
            // Not enough data, use fallback time from config
            scheduleReminderForWeekday(weekday, optimalTime: config.workoutReminderTime, config: config)
        }
    }

    /// Get the time of the first set logged on a specific date
    private func getFirstSetTimeForDate(_ date: Date, context: ModelContext) -> Date? {
        let calendar = Calendar.current

        // Format date string to match DayStorage format (e.g., "28 November 2025")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMMM yyyy"
        let dateString = dateFormatter.string(from: date)

        do {
            // Query DayStorage for this date (permanent record of completed workouts)
            let descriptor = FetchDescriptor<DayStorage>(
                predicate: #Predicate<DayStorage> { storage in
                    storage.date == dateString
                }
            )
            let dayStorages = try context.fetch(descriptor)

            guard let dayStorage = dayStorages.first else {
                #if DEBUG
                print("🔍 WORKOUT REMINDER: No DayStorage found for \(dateString)")
                #endif
                return nil
            }

            // Fetch the associated Day object to get exercises
            let dayId = dayStorage.dayId
            let dayDescriptor = FetchDescriptor<Day>(
                predicate: #Predicate<Day> { day in
                    day.id == dayId
                }
            )
            let days = try context.fetch(dayDescriptor)

            guard let day = days.first,
                  let exercises = day.exercises else {
                #if DEBUG
                print("🔍 WORKOUT REMINDER: No exercises found for \(dateString)")
                #endif
                return nil
            }

            // Find the earliest set time across all exercises
            var earliestTime: Date?

            for exercise in exercises {
                guard let sets = exercise.sets, !sets.isEmpty else { continue }

                for set in sets where !set.time.isEmpty {
                    // Parse set time (format: "HH:mm" or "H:mm")
                    if let setTime = parseSetTime(set.time, on: date) {
                        if earliestTime == nil || setTime < earliestTime! {
                            earliestTime = setTime
                        }
                    }
                }
            }

            #if DEBUG
            if let earliestTime = earliestTime {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                print("✅ WORKOUT REMINDER: Found workout at \(timeFormatter.string(from: earliestTime)) on \(dateString)")
            }
            #endif

            return earliestTime
        } catch {
            #if DEBUG
            print("❌ WORKOUT REMINDER: Failed to fetch workout data - \(error)")
            #endif
            return nil
        }
    }

    /// Calculate average time from multiple workout times
    private func calculateAverageTime(from times: [Date]) -> Date {
        let calendar = Calendar.current

        // Convert times to seconds since midnight
        let secondsSinceMidnight = times.map { date -> Int in
            let components = calendar.dateComponents([.hour, .minute, .second], from: date)
            return (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)
        }

        // Calculate average
        let averageSeconds = secondsSinceMidnight.reduce(0, +) / secondsSinceMidnight.count

        // Convert back to Date (today with that time)
        let hours = averageSeconds / 3600
        let minutes = (averageSeconds % 3600) / 60

        let today = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: hours, minute: minutes, second: 0, of: today) ?? Date()
    }

    /// Schedule reminder for a specific weekday
    private func scheduleReminderForWeekday(_ weekday: Int, optimalTime: Date, config: Config) {
        let calendar = Calendar.current
        let weekdayName = calendar.weekdaySymbols[weekday - 1]

        // Calculate reminder time (2 hours before optimal workout time)
        let reminderTime = calendar.date(byAdding: .hour, value: -2, to: optimalTime) ?? optimalTime

        // Get time components
        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)

        #if DEBUG
        let optimalComponents = calendar.dateComponents([.hour, .minute], from: optimalTime)
        print("📅 WORKOUT REMINDER: \(weekdayName) - Optimal workout time: \(optimalComponents.hour!):\(String(format: "%02d", optimalComponents.minute!))")
        print("⏰ WORKOUT REMINDER: \(weekdayName) - Reminder at: \(components.hour!):\(String(format: "%02d", components.minute!))")
        #endif

        // Create notification request for this weekday
        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute

        // Check if this is a rest day and get today's workout name
        let (isRestDay, workoutName) = getTodayWorkoutInfo(weekday: weekday, config: config)

        #if DEBUG
        print("🏋️ WORKOUT REMINDER: \(weekdayName) - isRestDay: \(isRestDay), workoutName: \(workoutName ?? "nil")")
        #endif

        let notificationID = "workout_reminder_\(weekday)"
        let title: String
        let body: String

        if isRestDay {
            title = "Rest Day Today 💤"
            body = "Take time to recover and rebuild your muscles!"
        } else {
            title = "Time to Crush Your Workout! 💪"
            if let workout = workoutName {
                body = "It's \(workout) day. Your muscles are ready. Let's get stronger!"
            } else {
                body = "Your muscles are ready. Let's get stronger today!"
            }
        }

        Task {
            do {
                try await notificationManager.scheduleNotification(
                    id: notificationID,
                    title: title,
                    body: body,
                    dateComponents: dateComponents,
                    repeats: true, // Repeat weekly
                    categoryIdentifier: NotificationManager.NotificationCategory.workoutReminder,
                    userInfo: ["weekday": weekday, "type": "workout_reminder"]
                )

                #if DEBUG
                print("✅ WORKOUT REMINDER: Scheduled for \(weekdayName)")
                #endif
            } catch {
                #if DEBUG
                print("❌ WORKOUT REMINDER: Failed to schedule for \(weekdayName) - \(error)")
                #endif
            }
        }
    }

    /// Get workout info for a specific weekday (rest day status and workout name)
    private func getTodayWorkoutInfo(weekday: Int, config: Config) -> (isRestDay: Bool, workoutName: String?) {
        guard let context = modelContext else {
            return (false, nil)
        }

        do {
            // Fetch active split
            let descriptor = FetchDescriptor<Split>(
                predicate: #Predicate<Split> { split in
                    split.isActive == true
                }
            )
            let splits = try context.fetch(descriptor)

            guard let activeSplit = splits.first,
                  let days = activeSplit.days,
                  !days.isEmpty else {
                return (false, nil)
            }

            // Calculate how many days from today until the target weekday
            let calendar = Calendar.current
            let today = Date()
            let currentWeekday = calendar.component(.weekday, from: today)

            var daysUntilTarget = weekday - currentWeekday
            if daysUntilTarget < 0 {
                daysUntilTarget += 7 // Next week
            }

            // Calculate which day in split it will be
            let currentDayInSplit = config.dayInSplit // 1-indexed
            let targetDayInSplit = ((currentDayInSplit - 1 + daysUntilTarget) % days.count) + 1

            // Find the day in the split
            guard let day = days.first(where: { $0.dayOfSplit == targetDayInSplit }) else {
                return (false, nil)
            }

            // Use explicit isRestDay property instead of checking name
            let isRestDay = day.isRestDay

            return (isRestDay, isRestDay ? nil : day.name)
        } catch {
            #if DEBUG
            print("❌ WORKOUT REMINDER: Failed to fetch split info - \(error)")
            #endif
            return (false, nil)
        }
    }

    /// Cancel a workout reminder if already worked out today
    func cancelTodayReminderIfWorkoutCompleted() {
        guard let context = modelContext else { return }

        let calendar = Calendar.current
        let today = Date()

        // Format today's date to match DayStorage format (e.g., "28 November 2025")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMMM yyyy"
        let dateString = dateFormatter.string(from: today)

        do {
            // Check if DayStorage exists for today (indicates completed workout)
            let descriptor = FetchDescriptor<DayStorage>(
                predicate: #Predicate<DayStorage> { storage in
                    storage.date == dateString
                }
            )
            let dayStorages = try context.fetch(descriptor)

            if !dayStorages.isEmpty {
                // Workout completed, cancel today's reminder
                let weekday = calendar.component(.weekday, from: today)
                let notificationID = "workout_reminder_\(weekday)"
                notificationManager.cancelNotification(withId: notificationID)

                #if DEBUG
                print("🗑️ WORKOUT REMINDER: Cancelled today's reminder (workout completed)")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ WORKOUT REMINDER: Failed to check workout status - \(error)")
            #endif
        }
    }

    /// Cancel all workout reminders
    private func cancelAllWorkoutReminders() {
        for weekday in 1...7 {
            let notificationID = "workout_reminder_\(weekday)"
            notificationManager.cancelNotification(withId: notificationID)
        }

        #if DEBUG
        print("🗑️ WORKOUT REMINDER: Cancelled all workout reminders")
        #endif
    }

    // MARK: - Helper Functions

    /// Format date as "yyyy-MM-dd"
    private func formatDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Parse set time string (HH:mm or H:mm) into Date on specific day
    private func parseSetTime(_ timeString: String, on date: Date) -> Date? {
        let components = timeString.split(separator: ":")
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }

        let second = components.count >= 3 ? (Int(components[2]) ?? 0) : 0

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(bySettingHour: hour, minute: minute, second: second, of: startOfDay)
    }
}
