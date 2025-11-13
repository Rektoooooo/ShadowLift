//
//  UserProfileManager.swift
//  ShadowLift
//
//  Created by SwiftData Migration on 18.09.2025.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

@MainActor
class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()
    
    @Published var currentProfile: UserProfile?
    @Published var isLoading = false
    @Published var error: String?

    // Computed property to check if profile is ready to use
    var isProfileReady: Bool {
        return currentProfile != nil
    }

    // Get current profile, creating one if necessary (for UI access)
    var profileWithFallback: UserProfile {
        if let profile = currentProfile {
            return profile
        } else {
            ensureProfileExists()
            return currentProfile ?? UserProfile() // Emergency fallback
        }
    }

    // DEBUG: Clear all profiles (for testing fresh install)
    func clearAllProfiles() {
        guard let context = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<UserProfile>()
            let profiles = try context.fetch(descriptor)

            for profile in profiles {
                context.delete(profile)
            }

            try context.save()
            currentProfile = nil
            print("🗑️ DEBUG: Cleared all UserProfiles from database")
        } catch {
            print("❌ DEBUG: Failed to clear profiles - \(error)")
        }
    }

    private var modelContext: ModelContext?
    private var syncTask: Task<Void, Never>?
    private var isSyncing = false
    
    private init() {}
    
    // MARK: - Setup
    
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Profile Management
    
    /// Load existing profile or create a temporary one that can be overridden by CloudKit
    func loadOrCreateProfile() {
        guard let context = modelContext else {
            error = "ModelContext not available"
            return
        }

        do {
            let descriptor = FetchDescriptor<UserProfile>()
            let profiles = try context.fetch(descriptor)

            if let existingProfile = profiles.first {
                currentProfile = existingProfile
                print("✅ USER PROFILE: Loaded existing profile for \(existingProfile.username)")
            } else {
                // Create a temporary profile that will be replaced by CloudKit data if available
                let tempProfile = UserProfile()
                context.insert(tempProfile)
                try context.save()
                currentProfile = tempProfile
                print("✅ USER PROFILE: Created temporary profile (will be replaced by CloudKit if available)")
            }
        } catch {
            self.error = "Failed to load user profile: \(error.localizedDescription)"
            print("❌ USER PROFILE: \(self.error!)")
        }
    }

    /// Create a new profile if none exists (called when needed)
    private func ensureProfileExists() {
        guard currentProfile == nil, let context = modelContext else { return }

        do {
            let newProfile = UserProfile()
            context.insert(newProfile)
            try context.save()
            currentProfile = newProfile
            print("✅ USER PROFILE: Created new profile")
        } catch {
            self.error = "Failed to create user profile: \(error.localizedDescription)"
            print("❌ USER PROFILE: Failed to create profile - \(self.error!)")
        }
    }
    
    /// Save current profile
    func saveProfile() {
        guard let context = modelContext, let profile = currentProfile else {
            error = "No profile or context available"
            return
        }
        
        do {
            profile.markAsUpdated()
            try context.save()
            print("✅ USER PROFILE: Saved profile for \(profile.username)")
            
            // Trigger debounced CloudKit sync if enabled
            if CloudKitManager.shared.isCloudKitEnabled {
                debouncedSyncToCloudKit()
            }
        } catch {
            self.error = "Failed to save profile: \(error.localizedDescription)"
            print("❌ USER PROFILE: Save failed - \(self.error!)")
        }
    }

    private func debouncedSyncToCloudKit() {
        // Cancel existing sync task if running
        syncTask?.cancel()

        // Create new debounced sync task
        syncTask = Task {
            // Wait 2 seconds before syncing to batch multiple changes
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            await syncToCloudKit()
        }
    }
    
    // MARK: - Update Methods
    
    func updateUsername(_ username: String) {
        ensureProfileExists()
        currentProfile?.username = username
        saveProfile()
    }

    func updateEmail(_ email: String) {
        ensureProfileExists()
        currentProfile?.email = email
        saveProfile()
    }

    func updatePhysicalStats(height: Double? = nil, weight: Double? = nil, age: Int? = nil) {
        ensureProfileExists()
        guard let profile = currentProfile else { return }
        
        if let height = height {
            profile.height = height
        }
        if let weight = weight {
            profile.weight = weight
        }
        if let age = age {
            profile.age = age
        }
        
        profile.updateBMI()
        saveProfile()
    }
    
    func updateHealthPermissions(healthEnabled: Bool? = nil) {
        ensureProfileExists()
        guard let profile = currentProfile else { return }
        
        if let healthEnabled = healthEnabled {
            profile.isHealthEnabled = healthEnabled
        }
        
        saveProfile()
    }
    
    func updatePreferences(weightUnit: String? = nil, roundSetWeights: Bool? = nil) {
        ensureProfileExists()
        guard let profile = currentProfile else { return }
        
        if let weightUnit = weightUnit {
            profile.weightUnit = weightUnit
        }
        if let roundSetWeights = roundSetWeights {
            profile.roundSetWeights = roundSetWeights
        }
        
        saveProfile()
    }
    
    func updateProfileImage(_ image: UIImage?) {
        ensureProfileExists()
        guard let profile = currentProfile else { return }

        profile.setProfileImage(image)
        saveProfile()

        // Handle CloudKit image sync separately
        if let image = image {
            Task {
                do {
                    let cloudKitID = try await CloudKitManager.shared.saveProfileImage(image)
                    await MainActor.run {
                        profile.profileImageCloudKitID = cloudKitID
                        try? modelContext?.save()
                    }
                } catch {
                    print("❌ Failed to sync profile image to CloudKit: \(error)")
                }
            }
        }
    }

    func updateRestDays(_ restDays: Int) {
        ensureProfileExists()
        guard let profile = currentProfile else { return }

        profile.restDaysPerWeek = max(0, min(7, restDays)) // Clamp between 0-7
        saveProfile()
    }

    func updateStreak(currentStreak: Int, longestStreak: Int? = nil, lastWorkoutDate: Date? = nil, paused: Bool? = nil) {
        ensureProfileExists()
        guard let profile = currentProfile else { return }

        profile.currentStreak = currentStreak

        if let longestStreak = longestStreak {
            profile.longestStreak = max(profile.longestStreak, longestStreak)
        }

        if let lastWorkoutDate = lastWorkoutDate {
            profile.lastWorkoutDate = lastWorkoutDate
        }

        if let paused = paused {
            profile.streakPaused = paused
        }

        saveProfile()
    }
    
    // MARK: - CloudKit Integration
    
    private func syncToCloudKit() async {
        guard let profile = currentProfile,
              CloudKitManager.shared.isCloudKitEnabled,
              !isSyncing else {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            print("🔄 USER PROFILE: Syncing to CloudKit...")
            try await CloudKitManager.shared.saveUserProfile(profile)
            await MainActor.run {
                profile.markAsSynced()
                try? modelContext?.save()
            }
            print("✅ USER PROFILE: Synced to CloudKit successfully")
        } catch {
            await MainActor.run {
                self.error = "CloudKit sync failed: \(error.localizedDescription)"
            }
            print("❌ USER PROFILE: CloudKit sync failed - \(error)")
        }
    }
    

    func syncFromCloudKit() async {
        guard CloudKitManager.shared.isCloudKitEnabled else {
            print("🔍 USER PROFILE: CloudKit not enabled, skipping sync")
            return
        }
        
        do {
            print("🔄 USER PROFILE: Fetching from CloudKit...")
            if let cloudProfile = try await CloudKitManager.shared.fetchUserProfile() {
                await MainActor.run {
                    if let existingProfile = currentProfile {
                        // Replace all data with CloudKit data (complete restoration)
                        existingProfile.updateFromCloudKit(cloudProfile)
                        try? modelContext?.save()
                        print("✅ USER PROFILE: Completely restored from CloudKit data")

                        // Trigger UI updates by notifying that profile changed
                        objectWillChange.send()
                    } else {
                        // Create new profile from CloudKit data
                        let newProfile = UserProfile()
                        newProfile.updateFromCloudKit(cloudProfile)
                        modelContext?.insert(newProfile)
                        currentProfile = newProfile
                        try? modelContext?.save()
                        print("✅ USER PROFILE: Created from CloudKit data")
                    }
                }
                
                // Load profile image if available
                if let cloudKitID = cloudProfile["profileImageCloudKitID"] as? String,
                   cloudKitID == "cloudkit_profile_image" {
                    if let cloudImage = try? await CloudKitManager.shared.fetchProfileImage() {
                        await MainActor.run {
                            currentProfile?.setProfileImage(cloudImage)
                            try? modelContext?.save()
                        }
                    }
                }
            } else {
                print("🔍 USER PROFILE: No CloudKit data found")
            }
        } catch {
            await MainActor.run {
                self.error = "CloudKit fetch failed: \(error.localizedDescription)"
            }
            print("❌ USER PROFILE: CloudKit fetch failed - \(error)")
        }
    }
    


    // MARK: - Streak Calculation

    /// Calculate and update streak when user completes a workout
    func calculateStreak(workoutDate: Date = Date()) {
        ensureProfileExists()
        guard let profile = currentProfile else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: workoutDate)

        // If this is the first workout ever
        guard let lastWorkout = profile.lastWorkoutDate else {
            print("🔥 STREAK: First workout! Starting streak at 1")
            updateStreak(currentStreak: 1, longestStreak: 1, lastWorkoutDate: today, paused: false)
            return
        }

        let lastWorkoutDay = calendar.startOfDay(for: lastWorkout)

        // Check if already worked out today
        if calendar.isDate(today, inSameDayAs: lastWorkoutDay) {
            print("🔥 STREAK: Already worked out today, keeping streak at \(profile.currentStreak)")
            return
        }

        // Calculate days since last workout
        let daysSinceLastWorkout = calendar.dateComponents([.day], from: lastWorkoutDay, to: today).day ?? 0

        print("🔥 STREAK: Days since last workout: \(daysSinceLastWorkout)")

        if daysSinceLastWorkout == 1 {
            // Consecutive day - increment streak
            let newStreak = profile.currentStreak + 1
            print("🔥 STREAK: Consecutive day! Incrementing streak to \(newStreak)")
            updateStreak(currentStreak: newStreak, longestStreak: newStreak, lastWorkoutDate: today, paused: false)
        } else if daysSinceLastWorkout > 1 {
            // Check if streak should be reset or just paused based on rest days
            let shouldReset = shouldResetStreak(lastWorkoutDate: lastWorkoutDay, currentDate: today, restDaysPerWeek: profile.restDaysPerWeek)

            if shouldReset {
                print("🔥 STREAK: Exceeded rest days! Resetting streak to 1")
                updateStreak(currentStreak: 1, lastWorkoutDate: today, paused: false)
            } else {
                // Within allowed rest days - continue streak
                let newStreak = profile.currentStreak + 1
                print("🔥 STREAK: Within rest days allowance! Continuing streak at \(newStreak)")
                updateStreak(currentStreak: newStreak, longestStreak: newStreak, lastWorkoutDate: today, paused: false)
            }
        }
    }

    /// Check if streak should be reset based on missed days per calendar week
    private func shouldResetStreak(lastWorkoutDate: Date, currentDate: Date, restDaysPerWeek: Int) -> Bool {
        let calendar = Calendar.current

        // Get all calendar weeks between last workout and current date
        var checkDate = lastWorkoutDate
        var maxMissedInAnyWeek = 0

        while checkDate < currentDate {
            // Get the week for checkDate
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: checkDate))!
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

            // Count missed days in this week
            var missedInThisWeek = 0
            var dayInWeek = max(lastWorkoutDate, weekStart)

            while dayInWeek < min(currentDate, weekEnd) {
                let nextDay = calendar.date(byAdding: .day, value: 1, to: dayInWeek)!
                if !calendar.isDate(dayInWeek, inSameDayAs: lastWorkoutDate) {
                    missedInThisWeek += 1
                }
                dayInWeek = nextDay
            }

            maxMissedInAnyWeek = max(maxMissedInAnyWeek, missedInThisWeek)

            // Move to next week
            checkDate = weekEnd
        }

        print("🔥 STREAK: Max missed days in any week: \(maxMissedInAnyWeek), allowed: \(restDaysPerWeek)")

        // Reset if exceeded rest days in any calendar week
        return maxMissedInAnyWeek > restDaysPerWeek
    }

    /// Check streak status on app launch (for pausing logic)
    func checkStreakStatus() {
        ensureProfileExists()
        guard let profile = currentProfile else { return }

        guard let lastWorkout = profile.lastWorkoutDate else {
            // No workout history, nothing to check
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastWorkoutDay = calendar.startOfDay(for: lastWorkout)
        let daysSince = calendar.dateComponents([.day], from: lastWorkoutDay, to: today).day ?? 0

        // If it's been more than one day, check if we need to reset
        if daysSince > 1 {
            let shouldReset = shouldResetStreak(lastWorkoutDate: lastWorkoutDay, currentDate: today, restDaysPerWeek: profile.restDaysPerWeek)

            if shouldReset && !profile.streakPaused {
                print("🔥 STREAK: Streak expired! Resetting to 0")
                updateStreak(currentStreak: 0, paused: false)
            }
            // Note: We no longer auto-pause streaks. User controls pause manually.
        }
    }
}
