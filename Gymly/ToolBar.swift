//
//  ToolBar.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 13.05.2024.
//

import SwiftUI
import HealthKit
import SwiftData

struct ToolBar: View {
    @EnvironmentObject var config: Config
    @Environment(\.modelContext) private var context
    @State private var loginRefreshTrigger = false
    @StateObject private var userProfileManager = UserProfileManager.shared
    @StateObject private var appearanceManager = AppearanceManager.shared
    @StateObject private var prManager = PRManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var streakNotificationManager = StreakNotificationManager.shared
    @StateObject private var workoutReminderManager = WorkoutReminderManager.shared
    @StateObject private var milestoneNotificationManager = MilestoneNotificationManager.shared
    @StateObject private var inactivityReminderManager = InactivityReminderManager.shared
    @State private var todayViewModel: WorkoutViewModel?
    @State private var calendarViewModel: WorkoutViewModel?
    @State private var settingsViewModel: WorkoutViewModel?
    @State private var signInViewModel: WorkoutViewModel?
    @State private var showFitnessProfileSetup = false
    @State private var showTutorial = false
    @State private var hasRequestedNotificationPermission = false

    var body: some View {
        Group {
            if config.isUserLoggedIn {
                // Only show TabView when user is logged in
                if let todayVM = todayViewModel, let settingsVM = settingsViewModel, let calendarVM = calendarViewModel {
                    TabView {
                        TodayWorkoutView(viewModel: todayVM, loginRefreshTrigger: loginRefreshTrigger)
                            .tabItem {
                                Label("Routine", systemImage: "dumbbell")
                            }
                            .tag(1)
                        CalendarView(viewModel: calendarVM)
                            .tabItem {
                                Label("Calendar", systemImage: "calendar")
                            }
                            .tag(2)
                        SettingsView(viewModel: settingsVM)
                            .tabItem {
                                Label("Settings", systemImage: "gearshape")
                            }
                            .tag(3)
                            .toolbar(.visible, for: .tabBar)
                            .toolbarBackground(.black, for: .tabBar)
                    }
                    .tint(appearanceManager.accentColor.color)
                    .fullScreenCover(isPresented: $showFitnessProfileSetup) {
                        FitnessProfileSetupView()
                    }
                    .fullScreenCover(isPresented: $showTutorial) {
                        TutorialView()
                            .environmentObject(config)
                            .environmentObject(appearanceManager)
                    }
                    .onChange(of: config.hasCompletedFitnessProfile) { _, hasCompleted in
                        // If user hasn't completed profile, show setup
                        if !hasCompleted {
                            showFitnessProfileSetup = true
                        } else if !config.hasSeenTutorial {
                            // Show tutorial after fitness profile is completed
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showTutorial = true
                            }
                        }
                    }
                    .onChange(of: config.isUserLoggedIn) { _, isLoggedIn in
                        // Request notification permission after first login
                        if isLoggedIn && !hasRequestedNotificationPermission {
                            Task {
                                // Small delay to let UI settle after login
                                try? await Task.sleep(for: .seconds(1))
                                await requestNotificationPermissionIfNeeded()
                            }
                        }
                    }
                    .onAppear {
                        // Check if profile needs to be shown on initial load
                        if !config.hasCompletedFitnessProfile {
                            showFitnessProfileSetup = true
                        } else if !config.hasSeenTutorial {
                            // Show tutorial for existing users who haven't seen it yet
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showTutorial = true
                            }
                        }
                    }
                }
            } else {
                // Show sign-in view when not logged in
                if let signInVM = signInViewModel {
                    SignInView(viewModel: signInVM)
                }
            }
        }
        .environmentObject(config)
        .environmentObject(userProfileManager)
        .environmentObject(appearanceManager)
        .task {
            // Initialize UserProfileManager with SwiftData context
            userProfileManager.setup(modelContext: context)

            // Initialize iCloudSyncManager with Config
            iCloudSyncManager.shared.setup(config: config)

            // Initialize PRManager with SwiftData context
            prManager.setup(modelContext: context, userProfileManager: userProfileManager)

            // Initialize StreakNotificationManager
            streakNotificationManager.setup(userProfileManager: userProfileManager, config: config)

            // Initialize WorkoutReminderManager
            workoutReminderManager.setup(modelContext: context, config: config)

            // Initialize MilestoneNotificationManager
            milestoneNotificationManager.setup(config: config)

            // Initialize InactivityReminderManager
            inactivityReminderManager.setup(userProfileManager: userProfileManager, config: config)

            // Initialize WorkoutViewModels and connect userProfileManager
            let todayVM = WorkoutViewModel(config: config, context: context)
            let settingsVM = WorkoutViewModel(config: config, context: context)
            let signInVM = WorkoutViewModel(config: config, context: context)
            let calendarVM = WorkoutViewModel(config: config, context: context)

            todayVM.setUserProfileManager(userProfileManager)
            settingsVM.setUserProfileManager(userProfileManager)
            signInVM.setUserProfileManager(userProfileManager)
            calendarVM.setUserProfileManager(userProfileManager)
            
            todayViewModel = todayVM
            settingsViewModel = settingsVM
            calendarViewModel = calendarVM
            signInViewModel = signInVM

            debugLog("✅ TOOLBAR: Connected userProfileManager to all ViewModels")

            // Load profile if user is already logged in (app reopen)
            if config.isUserLoggedIn {
                debugLog("🔄 TOOLBAR: User already logged in, checking for existing profile...")

                // Try to load existing profile first
                let descriptor = FetchDescriptor<UserProfile>()
                let profiles = try? context.fetch(descriptor)

                if let existingProfile = profiles?.first {
                    // Profile exists in SwiftData - use it
                    userProfileManager.currentProfile = existingProfile
                    debugLog("✅ TOOLBAR: Loaded existing profile for \(existingProfile.username)")
                } else {
                    // No local profile - try CloudKit first before creating default
                    debugLog("🔍 TOOLBAR: No local profile found, checking CloudKit...")

                    if CloudKitManager.shared.isCloudKitEnabled {
                        await userProfileManager.syncFromCloudKit()

                        if userProfileManager.currentProfile != nil {
                            debugLog("✅ TOOLBAR: Restored profile from CloudKit")
                        } else {
                            // CloudKit had no data - create default profile
                            debugLog("⚠️ TOOLBAR: No CloudKit data, creating default profile")
                            userProfileManager.loadOrCreateProfile()
                        }
                    } else {
                        // CloudKit not available - create default profile
                        debugLog("⚠️ TOOLBAR: CloudKit not available, creating default profile")
                        userProfileManager.loadOrCreateProfile()
                    }
                }

                // CRITICAL: Sync workout data from CloudKit on app launch
                // This ensures multi-device sync works properly
                if CloudKitManager.shared.isCloudKitEnabled {
                    debugLog("🔄 TOOLBAR: Syncing workout data from CloudKit...")
                    await CloudKitManager.shared.fetchAndMergeData(context: context, config: config)
                    debugLog("✅ TOOLBAR: CloudKit workout data sync complete")
                }

                // Check streak status on app launch
                userProfileManager.checkStreakStatus()

                // Schedule streak protection notifications
                streakNotificationManager.scheduleStreakProtection()

                // Schedule smart workout reminders
                workoutReminderManager.scheduleSmartWorkoutReminders()

                // Check for inactivity and schedule reminder if needed
                inactivityReminderManager.checkAndScheduleInactivityReminder()
            }
        }
    }

    // MARK: - Helper Functions

    /// Request notification permission on first login
    private func requestNotificationPermissionIfNeeded() async {
        // Check if permission has already been determined
        await notificationManager.checkAuthorizationStatus()

        // Only request if not yet determined (first time)
        if notificationManager.authorizationStatus == .notDetermined {
            do {
                try await notificationManager.requestAuthorization()
                hasRequestedNotificationPermission = true

                // Enable notifications by default if granted
                if notificationManager.isAuthorized {
                    await MainActor.run {
                        config.notificationsEnabled = true
                    }
                    #if DEBUG
                    debugLog("✅ TOOLBAR: Notification permission granted on first login")
                    #endif
                }
            } catch {
                #if DEBUG
                debugLog("⚠️ TOOLBAR: Failed to request notification permission: \(error)")
                #endif
            }
        } else {
            hasRequestedNotificationPermission = true
            #if DEBUG
            debugLog("🔔 TOOLBAR: Notification permission already determined: \(notificationManager.authorizationStatus.rawValue)")
            #endif
        }
    }
}

