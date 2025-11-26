//
//  NotificationsView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 25.11.2025.
//

import SwiftUI
import SwiftData

struct NotificationsView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var config: Config
    @EnvironmentObject var userProfileManager: UserProfileManager
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showPermissionAlert = false

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.graphite(scheme))
                .ignoresSafeArea()

            Form {
                // Permission Status Section
                Section(header: Text("Permission")) {
                    HStack {
                        Image(systemName: notificationManager.isAuthorized ? "checkmark.circle.fill" : "bell.slash.fill")
                            .foregroundStyle(notificationManager.isAuthorized ? .green : .orange)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status")
                                .font(.headline)
                            Text(notificationManager.isAuthorized ? "Granted" : "Not granted")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if !notificationManager.isAuthorized {
                            Button("Enable") {
                                Task {
                                    await requestPermission()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.05))

                    if !notificationManager.isAuthorized {
                        Text("Allow Gymly to send you helpful reminders and motivational notifications")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.black.opacity(0.05))
                    }

                    if notificationManager.isAuthorized {
                        Toggle("Enable Notifications", isOn: $config.notificationsEnabled)
                            .onChange(of: config.notificationsEnabled) { oldValue, newValue in
                                handleNotificationToggle(enabled: newValue)
                            }
                            .listRowBackground(Color.black.opacity(0.05))
                    }
                }

                if notificationManager.isAuthorized && config.notificationsEnabled {
                    // Streak Protection
                    Section(header: Text("Motivation")) {
                        Toggle(isOn: $config.streakNotificationsEnabled) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Streak Protection")
                                    Text("Get reminded before your streak breaks")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onChange(of: config.streakNotificationsEnabled) { _, _ in
                            StreakNotificationManager.shared.rescheduleAllStreakNotifications()
                        }
                        .listRowBackground(Color.black.opacity(0.05))
                    }

                    // Workout Reminders
                    Section(header: Text("Workout Reminders")) {
                        Toggle(isOn: $config.workoutReminderEnabled) {
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Daily Reminder")
                                    Text("Get reminded to work out")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))

                        if config.workoutReminderEnabled {
                            DatePicker(
                                "Reminder Time",
                                selection: $config.workoutReminderTime,
                                displayedComponents: .hourAndMinute
                            )
                            .listRowBackground(Color.black.opacity(0.05))
                        }
                    }

                    // Progress Tracking
                    Section(header: Text("Progress")) {
                        Toggle(isOn: $config.progressMilestonesEnabled) {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Milestones")
                                    Text("Celebrate PRs and achievements")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))
                    }

                    // Re-engagement
                    Section(header: Text("Re-engagement")) {
                        Toggle(isOn: $config.inactivityRemindersEnabled) {
                            HStack {
                                Image(systemName: "clock.badge.exclamationmark.fill")
                                    .foregroundStyle(.purple)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Inactivity Reminders")
                                    Text("Get notified if you've been inactive")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))

                        Text("We'll send you a gentle reminder if you haven't worked out in a few days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.black.opacity(0.05))
                    }
                }

                #if DEBUG
                // Debug Testing Section
                if notificationManager.isAuthorized && config.notificationsEnabled {
                    Section(header: Text("🧪 Testing (Debug Only)")) {
                        Button("Test Streak Warning") {
                            Task {
                                await NotificationTestHelper.shared.testStreakWarningNotification()
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))

                        Button("Test Streak Saved") {
                            Task {
                                await NotificationTestHelper.shared.testStreakSavedNotification()
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))

                        Button("Test Milestone") {
                            Task {
                                await NotificationTestHelper.shared.testStreakMilestoneNotification()
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))

                        Button("Simulate Streak At Risk") {
                            NotificationTestHelper.shared.simulateStreakAtRisk(userProfileManager: userProfileManager, config: config)
                        }
                        .listRowBackground(Color.black.opacity(0.05))

                        Button("List Pending Notifications") {
                            Task {
                                await NotificationTestHelper.shared.listPendingNotifications()
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))

                        Button("Clear Test Notifications", role: .destructive) {
                            NotificationTestHelper.shared.clearAllTestNotifications()
                        }
                        .listRowBackground(Color.black.opacity(0.05))
                    }

                    Section(header: Text("🏋️ Workout Reminders")) {
                        Button("Test Monday Workout Reminder") {
                            Task {
                                await testWorkoutReminder(weekday: 2, dayName: "Monday")
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))

                        Button("Test Rest Day Reminder") {
                            Task {
                                await testRestDayReminder()
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))

                        Button("Analyze Workout Patterns") {
                            Task {
                                await WorkoutReminderManager.shared.scheduleSmartWorkoutReminders()
                                print("✅ TEST: Reanalyzed workout patterns and rescheduled reminders")
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))
                    }

                    Section(header: Text("🏆 Milestones & Achievements")) {
                        Button("Test Weight PR Notification") {
                            Task {
                                await testPRNotification(type: .weight)
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))

                        Button("Test 1RM PR Notification") {
                            Task {
                                await testPRNotification(type: .oneRM)
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))

                        Button("Test Volume PR Notification") {
                            Task {
                                await testPRNotification(type: .volume)
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))

                        Button("Test Workout Count Milestone") {
                            MilestoneNotificationManager.shared.sendWorkoutCountMilestone(count: 50)
                        }
                        .listRowBackground(Color.black.opacity(0.05))
                    }

                    Section(header: Text("😴 Inactivity Reminders")) {
                        Button("Test 4-Day Inactivity") {
                            Task {
                                await testInactivityReminder(days: 4)
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))

                        Button("Test 7-Day Inactivity") {
                            Task {
                                await testInactivityReminder(days: 7)
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))

                        Button("Test 14-Day Inactivity") {
                            Task {
                                await testInactivityReminder(days: 14)
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.05))

                        Button("Check Current Inactivity Status") {
                            InactivityReminderManager.shared.checkAndScheduleInactivityReminder()
                        }
                        .listRowBackground(Color.black.opacity(0.05))
                    }
                }
                #endif
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notificationManager.checkAuthorizationStatus()
        }
        .alert("Notification Permission Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                notificationManager.openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable notifications in Settings to receive workout reminders and progress updates.")
        }
    }

    private func requestPermission() async {
        do {
            try await notificationManager.requestAuthorization()
            if notificationManager.isAuthorized {
                await MainActor.run {
                    config.notificationsEnabled = true
                }
            }
        } catch {
            await MainActor.run {
                showPermissionAlert = true
            }
        }
    }

    private func handleNotificationToggle(enabled: Bool) {
        if !enabled {
            // Cancel all pending notifications when disabled
            Task {
                notificationManager.cancelAllNotifications()
            }
        }
    }

    #if DEBUG
    // MARK: - Test Functions

    private func testWorkoutReminder(weekday: Int, dayName: String) async {
        // Get actual workout name for the test
        let (isRestDay, workoutName) = await getWorkoutNameForTesting(weekday: weekday)

        let title = isRestDay ? "Rest Day Today 💤" : "Time to Crush Your Workout! 💪"
        let body: String

        if isRestDay {
            body = "Take time to recover and rebuild your muscles!"
        } else if let workout = workoutName {
            body = "It's \(workout) day. Your muscles are ready. Let's get stronger!"
        } else {
            body = "Your muscles are ready. Let's get stronger today!"
        }

        do {
            try await notificationManager.scheduleNotification(
                id: "test_workout_reminder",
                title: title,
                body: body,
                timeInterval: 5,
                categoryIdentifier: NotificationManager.NotificationCategory.workoutReminder,
                userInfo: ["type": "test", "weekday": weekday]
            )
            print("✅ TEST: \(dayName) workout reminder scheduled in 5 seconds - '\(body)'")
        } catch {
            print("❌ TEST: Failed to schedule workout reminder - \(error)")
        }
    }

    private func getWorkoutNameForTesting(weekday: Int) async -> (isRestDay: Bool, workoutName: String?) {
        // Calculate which day in split corresponds to this weekday
        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)

        var daysUntilTarget = weekday - currentWeekday
        if daysUntilTarget < 0 {
            daysUntilTarget += 7
        }

        // Get current day in split and project forward
        let currentDayInSplit = config.dayInSplit

        do {
            let descriptor = FetchDescriptor<Split>(
                predicate: #Predicate<Split> { split in
                    split.isActive
                }
            )
            let splits = try modelContext.fetch(descriptor)

            guard let activeSplit = splits.first,
                  let days = activeSplit.days,
                  !days.isEmpty else {
                return (false, nil)
            }

            let targetDayInSplit = ((currentDayInSplit - 1 + daysUntilTarget) % days.count) + 1

            guard let day = days.first(where: { $0.dayOfSplit == targetDayInSplit }) else {
                return (false, nil)
            }

            let isRestDay = day.name.lowercased().contains("rest")
            return (isRestDay, isRestDay ? nil : day.name)
        } catch {
            print("❌ TEST: Failed to fetch split info - \(error)")
            return (false, nil)
        }
    }

    private func testRestDayReminder() async {
        do {
            try await notificationManager.scheduleNotification(
                id: "test_rest_day",
                title: "Rest Day Today 💤",
                body: "Take time to recover and rebuild your muscles!",
                timeInterval: 5,
                categoryIdentifier: NotificationManager.NotificationCategory.workoutReminder,
                userInfo: ["type": "test", "rest_day": true]
            )
            print("✅ TEST: Rest day reminder scheduled in 5 seconds")
        } catch {
            print("❌ TEST: Failed to schedule rest day reminder - \(error)")
        }
    }

    private func testPRNotification(type: PRNotification.PRType) async {
        let notification: PRNotification

        switch type {
        case .weight:
            notification = PRNotification(
                exerciseName: "Bench Press",
                type: .weight,
                value: 100,
                reps: 8,
                date: Date()
            )
        case .oneRM:
            notification = PRNotification(
                exerciseName: "Deadlift",
                type: .oneRM,
                value: 180,
                reps: 1,
                date: Date()
            )
        case .volume:
            notification = PRNotification(
                exerciseName: "Squat",
                type: .volume,
                value: 5000,
                sets: 4,
                date: Date()
            )
        default:
            notification = PRNotification(
                exerciseName: "Test Exercise",
                type: type,
                value: 100,
                reps: 10,
                date: Date()
            )
        }

        MilestoneNotificationManager.shared.sendPRNotification(prNotification: notification)
        print("✅ TEST: Sent \(type) PR notification")
    }

    private func testInactivityReminder(days: Int) async {
        let title: String
        let body: String

        switch days {
        case 4:
            title = "We Miss You! 😊"
            body = "It's been 4 days since your last workout. Ready to get back?"
        case 7:
            title = "One Week Break 😔"
            body = "A week since your last session. Every rep counts - let's go!"
        case 14:
            title = "We Believe in You! 🌟"
            body = "14 days away. One workout is all it takes to restart!"
        default:
            title = "Time for a Fresh Start! 🚀"
            body = "Ready to begin again? Your fitness journey is waiting!"
        }

        do {
            try await notificationManager.scheduleNotification(
                id: "test_inactivity",
                title: title,
                body: body,
                timeInterval: 5,
                categoryIdentifier: NotificationManager.NotificationCategory.inactivity,
                userInfo: ["type": "test", "days_since_workout": days]
            )
            print("✅ TEST: Inactivity reminder (\(days) days) scheduled in 5 seconds")
        } catch {
            print("❌ TEST: Failed to schedule inactivity reminder - \(error)")
        }
    }
    #endif
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environmentObject(Config())
    }
}
