//
//  SignInView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 28.01.2025.
//

import SwiftUI
import AuthenticationServices
import Foundation
import SwiftData

struct SignInView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @EnvironmentObject var config: Config
    @EnvironmentObject var userProfileManager: UserProfileManager
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) var colorScheme
    @State private var isSyncingFromCloud = false
    @State private var syncProgress: Double = 0.0
    @State private var iCloudSync: iCloudSyncManager?

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.graphite(colorScheme))
                .ignoresSafeArea()

            // Loading overlay when syncing from iCloud
            if isSyncingFromCloud {
                ZStack {
                    FloatingClouds(theme: CloudsTheme.iCloud(colorScheme))
                        .ignoresSafeArea()

                    VStack(spacing: 30) {
                        // Cloud icon with animation
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 120, height: 120)

                            Image(.shadowICloud)
                                .resizable()
                                .frame(width: 300, height: 300)
                        }

                        VStack(spacing: 12) {
                            Text("Syncing from iCloud")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)

                            Text("Shadow is collecting your profile and workouts...")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.8))

                            ProgressView(value: syncProgress, total: 1.0)
                                .progressViewStyle(.linear)
                                .tint(.white)
                                .frame(width: 200)
                                .padding(.top, 8)

                            Text("\(Int(syncProgress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .ignoresSafeArea()
                .zIndex(1)
            }

            VStack(spacing: 40) {
                VStack(spacing: 16) {
                    Text("ShadowLift")
                        .bold()
                        .font(.largeTitle)
                        .foregroundStyle(Color.primary)
                    Text("Track your workouts and progress")
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                }

                VStack(spacing: 20) {
                    /// Sign in with apple id
                    SignInWithAppleButton(.signUp) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                // IMMEDIATELY show loading overlay BEFORE any async work
                                // DON'T set config.isUserLoggedIn yet - wait until sync completes
                                isSyncingFromCloud = true
                                print("🔥 SHOWING SYNC OVERLAY")

                                if let userCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                    print("User ID: \(userCredential.user)")

                                    // Store email in UserProfile if available (but don't override existing)
                                    if let email = userCredential.email {
                                        print("User Email: \(email)")
                                        // Only update email if current profile doesn't have a valid email
                                        let currentEmail = userProfileManager.currentProfile?.email ?? ""
                                        if currentEmail.isEmpty || currentEmail == "user@example.com" {
                                            userProfileManager.updateEmail(email)
                                        }
                                    } else {
                                        print("Email not available (User has logged in before)")
                                    }

                                    // Store username from Apple ID, but only as fallback (will be overridden by CloudKit if available)
                                    if let fullName = userCredential.fullName,
                                       let givenName = fullName.givenName {
                                        print("🔥 APPLE ID USERNAME: \(givenName)")
                                        // Only update username if current profile has default username
                                        let currentUsername = userProfileManager.currentProfile?.username ?? ""
                                        if currentUsername.isEmpty || currentUsername == "User" {
                                            userProfileManager.updateUsername(givenName)
                                        }
                                    }
                                }

                                // Store the first-time login status outside the credential scope
                                let isFirstTimeLogin = (authorization.credential as? ASAuthorizationAppleIDCredential)?.fullName != nil
                                print("🔥 IS FIRST TIME LOGIN: \(isFirstTimeLogin)")

                                // Trigger CloudKit sync after successful login
                                Task {
                                    // Small delay to ensure overlay renders before heavy sync work
                                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                                    print("🔥 STARTING CLOUDKIT SYNC PROCESS")
                                    await CloudKitManager.shared.checkCloudKitStatus()

                                    // Set config iCloud sync state based on CloudKit availability
                                    await MainActor.run {
                                        config.isCloudKitEnabled = CloudKitManager.shared.isCloudKitEnabled
                                        print("🔥 CLOUDKIT MANAGER STATE: \(CloudKitManager.shared.isCloudKitEnabled)")
                                        print("🔥 CONFIG STATE: \(config.isCloudKitEnabled)")
                                        if CloudKitManager.shared.isCloudKitEnabled {
                                            print("🔥 CLOUDKIT IS ENABLED")
                                        } else {
                                            print("🔥 CLOUDKIT IS NOT AVAILABLE")
                                        }
                                    }

                                    if config.isCloudKitEnabled {
                                        print("🔥 STARTING USERPROFILE CLOUDKIT SYNC")

                                        // Fetch UserProfile (picture/name) from CloudKit
                                        await userProfileManager.syncFromCloudKit()

                                        print("🔥 USERPROFILE CLOUDKIT SYNC COMPLETED")
                                        print("🔥 CURRENT USERNAME: \(userProfileManager.currentProfile?.username ?? "none")")

                                        // Fetch Fitness Profile from iCloud Key-Value Store
                                        print("🔥 FETCHING FITNESS PROFILE FROM ICLOUD")
                                        if iCloudSync == nil {
                                            iCloudSync = iCloudSyncManager(config: config)
                                        }
                                        await iCloudSync?.fetchFromiCloudWithTimeout(timeout: 2.0)
                                        print("🔥 FITNESS PROFILE FETCH COMPLETED")
                                    }

                                    // NOTE: Workout data (splits/exercises/days) syncs automatically via SwiftData iCloud
                                    // We don't need custom CloudKit sync for workout data - SwiftData handles it!

                                    // Wait for SwiftData to sync from iCloud automatically
                                    // Poll for splits instead of blind wait - actively check until data appears
                                    print("🔥 WAITING FOR SWIFTDATA ICLOUD SYNC...")

                                    var attempts = 0
                                    let maxAttempts = 20 // 20 attempts × 0.5 seconds = 10 seconds max
                                    var splitsFound = false

                                    while attempts < maxAttempts {
                                        // Update progress bar
                                        await MainActor.run {
                                            syncProgress = Double(attempts) / Double(maxAttempts)
                                        }

                                        // Check if splits exist in database
                                        do {
                                            let descriptor = FetchDescriptor<Split>()
                                            let splits = try context.fetch(descriptor)

                                            if !splits.isEmpty {
                                                print("🔥 FOUND \(splits.count) SPLITS IN DATABASE AFTER \(attempts) ATTEMPTS")
                                                splitsFound = true

                                                // Complete progress bar
                                                await MainActor.run {
                                                    syncProgress = 1.0
                                                }

                                                // Small delay to show 100% before dismissing
                                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                                break
                                            }
                                        } catch {
                                            print("⚠️ Error checking for splits: \(error.localizedDescription)")
                                        }

                                        // Wait before next attempt
                                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                        attempts += 1
                                    }

                                    if splitsFound {
                                        print("🔥 SWIFTDATA ICLOUD SYNC COMPLETED - SPLITS FOUND")
                                    } else {
                                        print("⚠️ SWIFTDATA ICLOUD SYNC TIMEOUT - NO SPLITS FOUND AFTER \(attempts) ATTEMPTS")
                                        // Complete progress bar anyway
                                        await MainActor.run {
                                            syncProgress = 1.0
                                        }
                                    }

                                    // Post notification to refresh views after all syncs complete
                                    await MainActor.run {
                                        NotificationCenter.default.post(name: Notification.Name.cloudKitDataSynced, object: nil)
                                    }

                                    // Hide loading overlay and mark user as logged in
                                    // Setting config.isUserLoggedIn will trigger ToolBar to switch from SignInView to TabView
                                    await MainActor.run {
                                        isSyncingFromCloud = false
                                        config.isUserLoggedIn = true
                                        print("🔥 SIGNIN: All syncs completed, transitioning to main app")
                                    }
                                }

                            case .failure(let error):
                                print("Could not authenticate: \(error.localizedDescription)")
                            }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(width: 280, height: 50)
                    .cornerRadius(25)
                }
                .padding(.horizontal, 40)
            }
        }
    }
    
    func ColorSchemeAdaptiveColor(light: Color, dark: Color) -> Color {
        return Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }
}
