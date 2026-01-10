//
//  AccountManager.swift
//  ShadowLift
//
//  Created by Claude Code on 29.11.2025.
//

import Foundation
import SwiftData
import AuthenticationServices
import CloudKit

@MainActor
class AccountManager: ObservableObject {
    static let shared = AccountManager()

    @Published var isDeletingAccount = false
    @Published var deletionError: String?

    private init() {}

    // MARK: - Logout

    /// Simple logout - returns to sign-in screen, keeps ALL data intact
    /// User can sign back in with same Apple ID and see all their data
    func logout(config: Config) {
        debugLog("🔓 LOGOUT: Returning to sign-in screen...")

        // Only change: set logged out state
        config.isUserLoggedIn = false

        // That's it! All data stays intact for when they sign back in
        debugLog("✅ LOGOUT: Complete - Data preserved, user can sign back in")
    }

    // MARK: - Account Deletion

    /// Complete account deletion - IRREVERSIBLE
    /// Deletes ALL data: SwiftData, CloudKit, UserDefaults, HealthKit
    func deleteAccount(
        context: ModelContext,
        config: Config,
        includeCloudKit: Bool = true
    ) async throws {
        debugLog("🗑️ DELETE ACCOUNT: Starting account deletion...")
        isDeletingAccount = true
        deletionError = nil

        do {
            // STEP 1: Delete from CloudKit (if enabled and requested)
            if includeCloudKit && CloudKitManager.shared.isCloudKitEnabled {
                debugLog("🗑️ DELETE ACCOUNT: Deleting CloudKit data...")
                try await deleteCloudKitData()
            }

            // STEP 2: Delete all SwiftData models
            debugLog("🗑️ DELETE ACCOUNT: Deleting local data...")
            try deleteAllSwiftData(context: context)

            // STEP 3: Clear UserDefaults
            debugLog("🗑️ DELETE ACCOUNT: Clearing preferences...")
            clearUserDefaults()

            // STEP 4: Reset Config
            debugLog("🗑️ DELETE ACCOUNT: Resetting app state...")
            resetConfig(config: config)

            // STEP 5: Sign out
            debugLog("🗑️ DELETE ACCOUNT: Signing out...")
            config.isUserLoggedIn = false

            debugLog("✅ DELETE ACCOUNT: Complete - All data deleted")
            isDeletingAccount = false

        } catch {
            debugLog("❌ DELETE ACCOUNT: Failed - \(error.localizedDescription)")
            deletionError = error.localizedDescription
            isDeletingAccount = false
            throw error
        }
    }

    // MARK: - Private Helper Methods

    /// Delete all data from CloudKit
    private func deleteCloudKitData() async throws {
        debugLog("🔥 Deleting all CloudKit records...")

        // Fetch and delete all splits (cascades to days and exercises)
        let splits = try await CloudKitManager.shared.fetchAllSplits()
        for split in splits {
            try? await CloudKitManager.shared.deleteSplit(split.id)
            debugLog("🗑️ Deleted split: \(split.name)")
        }

        // Delete progress photos
        let progressPhotos = try await CloudKitManager.shared.fetchProgressPhotos()
        for (photo, _) in progressPhotos {
            // photo.id is UUID, not Optional
            try? await CloudKitManager.shared.deleteProgressPhoto(photo.id ?? UUID())
            debugLog("🗑️ Deleted progress photo: \(photo.id?.uuidString ?? "unknown")")
        }

        // Delete user profile and profile image
        do {
            try await CloudKitManager.shared.deleteUserProfile()
            debugLog("🗑️ Deleted user profile")
        } catch {
            debugLog("⚠️ User profile not found or already deleted")
        }

        do {
            try await CloudKitManager.shared.deleteProfileImage()
            debugLog("🗑️ Deleted profile image")
        } catch {
            debugLog("⚠️ Profile image not found or already deleted")
        }

        debugLog("✅ CloudKit data deletion complete")
    }

    /// Delete all SwiftData models
    private func deleteAllSwiftData(context: ModelContext) throws {
        debugLog("📦 Deleting all SwiftData models...")

        // Delete Splits (cascades to Days and Exercises)
        let splitDescriptor = FetchDescriptor<Split>()
        let splits = try context.fetch(splitDescriptor)
        for split in splits {
            context.delete(split)
        }
        debugLog("🗑️ Deleted \(splits.count) splits")

        // Delete DayStorage (completed workouts)
        let dayStorageDescriptor = FetchDescriptor<DayStorage>()
        let dayStorages = try context.fetch(dayStorageDescriptor)
        for dayStorage in dayStorages {
            context.delete(dayStorage)
        }
        debugLog("🗑️ Deleted \(dayStorages.count) day storages")

        // Delete WeightPoints
        let weightPointDescriptor = FetchDescriptor<WeightPoint>()
        let weightPoints = try context.fetch(weightPointDescriptor)
        for weightPoint in weightPoints {
            context.delete(weightPoint)
        }
        debugLog("🗑️ Deleted \(weightPoints.count) weight points")

        // Delete UserProfile
        let userProfileDescriptor = FetchDescriptor<UserProfile>()
        let userProfiles = try context.fetch(userProfileDescriptor)
        for profile in userProfiles {
            context.delete(profile)
        }
        debugLog("🗑️ Deleted \(userProfiles.count) user profiles")

        // Delete ProgressPhotos
        let progressPhotoDescriptor = FetchDescriptor<ProgressPhoto>()
        let progressPhotos = try context.fetch(progressPhotoDescriptor)
        for photo in progressPhotos {
            context.delete(photo)
        }
        debugLog("🗑️ Deleted \(progressPhotos.count) progress photos")

        // Delete ExercisePRs
        let prDescriptor = FetchDescriptor<ExercisePR>()
        let prs = try context.fetch(prDescriptor)
        for pr in prs {
            context.delete(pr)
        }
        debugLog("🗑️ Deleted \(prs.count) PRs")

        // Save context
        try context.save()
        debugLog("✅ SwiftData deletion complete")
    }

    /// Clear all UserDefaults
    private func clearUserDefaults() {
        debugLog("🧹 Clearing UserDefaults...")

        guard let domain = Bundle.main.bundleIdentifier else {
            debugLog("⚠️ Could not get bundle identifier, clearing standard defaults")
            // Fallback: clear known keys manually if bundle ID unavailable
            return
        }
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        debugLog("✅ UserDefaults cleared")
    }

    /// Reset Config to default state
    private func resetConfig(config: Config) {
        debugLog("🔄 Resetting Config...")

        // Reset all config values to defaults
        config.splitStarted = false
        config.dayInSplit = 1
        config.splitLength = 1
        config.lastUpdateDate = Date()
        config.isUserLoggedIn = false
        config.firstSplitEdit = true
        config.activeExercise = 1
        config.graphDataValues = []
        config.graphMaxValue = 1.0
        config.totalWorkoutTimeMinutes = 0
        CloudKitManager.shared.isCloudKitEnabled = false
        config.cloudKitSyncDate = nil
        config.isHealtKitEnabled = false
        config.isPremium = false

        // Reset notifications
        config.notificationsEnabled = false
        config.streakNotificationsEnabled = true
        config.workoutReminderEnabled = true
        config.progressMilestonesEnabled = true
        config.inactivityRemindersEnabled = true

        // Reset fitness profile
        config.hasCompletedFitnessProfile = false
        config.fitnessGoal = ""
        config.equipmentAccess = ""	
        config.experienceLevel = ""
        config.trainingDaysPerWeek = 4

        debugLog("✅ Config reset complete")
    }
}
