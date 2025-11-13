//
//  ConnectionsView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 29.01.2025.
//

import SwiftUI
import HealthKit
import CloudKit
import Foundation

extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

struct ConnectionsView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @StateObject var healthKitManager = HealthKitManager()
    @StateObject var cloudKitManager = CloudKitManager.shared
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var config: Config
    @Environment(\.colorScheme) var scheme
    @State private var isCloudKitAvailable = false
    @State private var isHealthKitSyncing = false
    @State private var showHealthKitSettingsAlert = false
    private let healthStore = HKHealthStore()

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.graphite(scheme))
                .ignoresSafeArea()
            Form {
            Section(header: Text("Apple Health")) {
                Toggle("Enable Apple Health", isOn: Binding(
                    get: { config.isHealtKitEnabled },
                    set: { newValue in
                        if newValue {
                            // Optimistic UI: Enable toggle immediately for instant feedback
                            config.isHealtKitEnabled = true

                            // Request authorization asynchronously
                            requestHealthKitAuthorizationOptimistic()
                        } else {
                            // User wants to disable - just update the flag
                            config.isHealtKitEnabled = false
                            print("🩺 HEALTH: HealthKit disabled by user")
                        }
                    }
                ))

                if isHealthKitSyncing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Syncing health data...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text("To fully revoke permissions, disable HealthKit access in Settings > Privacy & Security > Health > Gymly")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)

            }
            .listRowBackground(Color.black.opacity(0.05))

            Section(header: Text("iCloud Sync")) {
                Toggle("Enable iCloud Sync", isOn: Binding(
                    get: { config.isCloudKitEnabled },
                    set: { newValue in
                        Task {
                            if newValue && isCloudKitAvailable {
                                cloudKitManager.setCloudKitEnabled(true)
                                config.isCloudKitEnabled = true
                                viewModel.performFullCloudKitSync()
                            } else if !newValue {
                                cloudKitManager.setCloudKitEnabled(false)
                                config.isCloudKitEnabled = false
                            } else {
                                // CloudKit not available but user wants to enable it
                                print("❌ CloudKit not available, cannot enable sync")
                            }
                        }
                    }
                ))
                    .disabled(!isCloudKitAvailable)

                if cloudKitManager.isSyncing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Syncing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let error = cloudKitManager.syncError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                }

                if let lastSync = cloudKitManager.lastSyncDate {
                    Text("Last synced: \(lastSync, formatter: DateFormatter.shortDateTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if config.isCloudKitEnabled && cloudKitManager.isCloudKitEnabled {
                    Button("Sync Now") {
                        viewModel.performFullCloudKitSync()
                    }
                    .disabled(cloudKitManager.isSyncing)
                }

                Text("Sync your splits, workout history, and settings across all your devices. Requires iCloud to be enabled.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .listRowBackground(Color.black.opacity(0.05))
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .navigationTitle("Connected Apps")
        .task {
            await cloudKitManager.checkCloudKitStatus()
            isCloudKitAvailable = await cloudKitManager.isCloudKitAvailable()
            // Sync the config state with CloudKit manager state
            if cloudKitManager.isCloudKitEnabled && !config.isCloudKitEnabled {
                config.isCloudKitEnabled = true
            }
        }
        .alert("Enable HealthKit in Settings", isPresented: $showHealthKitSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You previously denied HealthKit access. To enable it, go to Settings > Privacy & Security > Health > Gymly and turn on all permissions.")
        }
    }
    

    /// Requests HealthKit authorization with optimistic UI updates
    private func requestHealthKitAuthorizationOptimistic() {
        print("🩺 HEALTH: Requesting HealthKit authorization...")

        let healthDataToRead: Set = [
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!
        ]

        // Request authorization (this shows the system dialog on first attempt)
        // On subsequent attempts, iOS returns cached result immediately
        healthStore.requestAuthorization(toShare: nil, read: healthDataToRead) { success, error in
            // Note: success is always true for read-only permissions due to privacy
            // iOS doesn't tell us if user granted or denied - we must try fetching to find out

            DispatchQueue.main.async {
                print("🩺 HEALTH: Authorization dialog completed, attempting to fetch data...")

                // Show syncing indicator
                self.isHealthKitSyncing = true

                // Try to fetch data - if successful, permissions are granted
                self.fetchHealthKitDataAfterAuthorizationWithValidation()
            }
        }
    }

    /// Fetch HealthKit data with validation (checks if permissions actually work)
    private func fetchHealthKitDataAfterAuthorizationWithValidation() {
        print("📱 HEALTH: Fetching data from HealthKit with validation...")

        // Track completion and success of fetches
        var completedFetches = 0
        var anyDataFetched = false
        let totalFetches = 3

        func checkCompletion() {
            completedFetches += 1
            if completedFetches == totalFetches {
                DispatchQueue.main.async {
                    self.isHealthKitSyncing = false

                    if anyDataFetched {
                        print("✅ HEALTH: Permissions granted - data fetched successfully")
                        // Keep toggle enabled
                    } else {
                        print("❌ HEALTH: No data could be fetched - permissions likely denied")
                        // Revert toggle
                        self.config.isHealtKitEnabled = false
                        self.showHealthKitSettingsAlert = true
                    }
                }
            }
        }

        // Fetch height (parallel)
        healthKitManager.fetchHeight { height in
            DispatchQueue.main.async {
                if let height = height {
                    anyDataFetched = true
                    let heightInCm = height * 100.0
                    self.userProfileManager.updatePhysicalStats(height: heightInCm)
                    print("✅ HEALTH: Fetched height: \(height) m (\(heightInCm) cm)")
                }
                checkCompletion()
            }
        }

        // Fetch age (parallel)
        healthKitManager.fetchAge { age in
            DispatchQueue.main.async {
                if let age = age {
                    anyDataFetched = true
                    self.userProfileManager.updatePhysicalStats(age: age)
                    print("✅ HEALTH: Fetched age: \(age) years")
                }
                checkCompletion()
            }
        }

        // Fetch weight (parallel)
        healthKitManager.fetchWeight { weight in
            DispatchQueue.main.async {
                if let weight = weight {
                    anyDataFetched = true
                    self.userProfileManager.updatePhysicalStats(weight: weight)
                    print("✅ HEALTH: Fetched weight: \(weight) kg")
                }
                checkCompletion()
            }
        }
    }

    /// Fetch HealthKit data immediately after authorization (parallel fetch)
    private func fetchHealthKitDataAfterAuthorization() {
        print("📱 HEALTH: Fetching data from HealthKit after authorization...")

        // Track completion of all three fetches
        var completedFetches = 0
        let totalFetches = 3

        func checkCompletion() {
            completedFetches += 1
            if completedFetches == totalFetches {
                DispatchQueue.main.async {
                    self.isHealthKitSyncing = false
                    print("✅ HEALTH: All data fetched successfully")
                }
            }
        }

        // Fetch height (parallel)
        healthKitManager.fetchHeight { height in
            DispatchQueue.main.async {
                if let height = height {
                    // HealthKit returns height in meters, UserProfile stores in centimeters
                    let heightInCm = height * 100.0
                    self.userProfileManager.updatePhysicalStats(height: heightInCm)
                    print("✅ HEALTH: Fetched height: \(height) m (\(heightInCm) cm)")
                }
                checkCompletion()
            }
        }

        // Fetch age (parallel)
        healthKitManager.fetchAge { age in
            DispatchQueue.main.async {
                if let age = age {
                    self.userProfileManager.updatePhysicalStats(age: age)
                    print("✅ HEALTH: Fetched age: \(age) years")
                }
                checkCompletion()
            }
        }

        // Fetch weight (parallel)
        healthKitManager.fetchWeight { weight in
            DispatchQueue.main.async {
                if let weight = weight {
                    self.userProfileManager.updatePhysicalStats(weight: weight)
                    print("✅ HEALTH: Fetched weight: \(weight) kg")
                }
                checkCompletion()
            }
        }
    }


    /// Check if HealthKit permissions are granted
    private func checkHealthKitPermissions() -> Bool {
        let dateOfBirthType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        let heightType = HKObjectType.quantityType(forIdentifier: .height)!
        let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass)!

        let dateOfBirthStatus = healthStore.authorizationStatus(for: dateOfBirthType)
        let heightStatus = healthStore.authorizationStatus(for: heightType)
        let weightStatus = healthStore.authorizationStatus(for: weightType)

        // Return true if at least one permission is granted
        return dateOfBirthStatus == .sharingAuthorized ||
               heightStatus == .sharingAuthorized ||
               weightStatus == .sharingAuthorized
    }

}
