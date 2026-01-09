//
//  GymlyApp.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 13.05.2024.
//

import SwiftUI
import SwiftData

@main
struct GymlyApp: App {
    @StateObject private var config = Config()
    @StateObject private var storeManager = StoreManager()
    @StateObject private var crashReporter = CrashReporter.shared
    @State private var importError: ImportError?
    @State private var showImportError = false
    @State private var showImportSuccess = false
    @State private var importedSplitName = ""

    // Deep link import preview
    @State private var sharedSplitToPreview: Split?
    @State private var showSharedSplitPreview = false
    @State private var isLoadingSharedSplit = false

    // Data recovery state
    @State private var showDataRecoveryAlert = false
    private let isUsingFallbackContainer: Bool

    // Single shared ModelContainer - DO NOT create new ones elsewhere!
    let modelContainer: ModelContainer

    init() {
        var usingFallback = false
        do {
            modelContainer = try ModelContainer(for: Split.self, Exercise.self, Day.self, DayStorage.self, WeightPoint.self, UserProfile.self, ExercisePR.self, ProgressPhoto.self)
        } catch {
            // Instead of crashing, create an in-memory container as fallback
            // User will be prompted to recover data
            debugLog("❌ Failed to create ModelContainer: \(error)")
            debugLog("🔄 Creating in-memory fallback container...")

            let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                modelContainer = try ModelContainer(for: Split.self, Exercise.self, Day.self, DayStorage.self, WeightPoint.self, UserProfile.self, ExercisePR.self, ProgressPhoto.self, configurations: fallbackConfig)
                usingFallback = true
            } catch let fallbackError {
                // If even in-memory fails, something is fundamentally broken
                fatalError("Critical: Cannot create ModelContainer. Original error: \(error). Fallback error: \(fallbackError)")
            }
        }
        self.isUsingFallbackContainer = usingFallback
    }

    var body: some Scene {
        WindowGroup {
            ToolBar()
                .environmentObject(config)
                .environmentObject(storeManager)
                .onOpenURL { url in
                    handleIncomingFile(url, config: config)
                }
                .onChange(of: storeManager.isPremium) { oldValue, newValue in
                    // Sync premium status from StoreManager to Config
                    debugLog("💎 GymlyApp: StoreManager isPremium changed from \(oldValue) to \(newValue)")
                    config.updatePremiumStatus(from: newValue)
                    debugLog("💎 GymlyApp: Config isPremium is now \(config.isPremium)")
                }
                // Import Error Alert
                .alert("Import Failed", isPresented: $showImportError) {
                    Button("OK") {
                        importError = nil
                    }
                } message: {
                    if let error = importError {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(error.errorDescription ?? "Unknown error")
                            if let suggestion = error.recoverySuggestion {
                                Text("\n\(suggestion)")
                                    .font(.caption)
                            }
                        }
                    }
                }
                // Import Success Alert
                .alert("Split Imported", isPresented: $showImportSuccess) {
                    Button("OK") {}
                } message: {
                    Text("'\(importedSplitName)' has been successfully imported and is ready to use!")
                }
                // Shared Split Preview Sheet
                .sheet(isPresented: $showSharedSplitPreview) {
                    if let split = sharedSplitToPreview {
                        SplitImportPreviewView(split: split) {
                            importSharedSplit(split)
                        }
                        .environmentObject(AppearanceManager())
                    }
                }
                // Loading overlay for fetching shared split
                .overlay {
                    if isLoadingSharedSplit {
                        ZStack {
                            Color.black.opacity(0.5)
                                .ignoresSafeArea()
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)
                                Text("Loading shared split...")
                                    .foregroundColor(.white)
                                    .font(.headline)
                            }
                            .padding(30)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(20)
                        }
                    }
                }
                // Data Recovery Alert - shown when using fallback container
                .alert("Data Recovery Mode", isPresented: $showDataRecoveryAlert) {
                    Button("OK") {}
                } message: {
                    Text("There was an issue loading your workout data. Your data is temporarily stored in memory. Please restart the app to attempt recovery. If the issue persists, contact support.")
                }
                .onAppear {
                    // Show alert if using fallback container
                    if isUsingFallbackContainer {
                        showDataRecoveryAlert = true
                    }
                }
        }
        .modelContainer(modelContainer)
    }

    private func importSharedSplit(_ split: Split) {
        let context = modelContainer.mainContext
        let viewModel = WorkoutViewModel(config: config, context: context)

        do {
            let importedSplit = try viewModel.importSharedSplit(split, context: context)
            importedSplitName = importedSplit.name
            showImportSuccess = true

            // Post notifications to refresh UI
            NotificationCenter.default.post(name: .importSplit, object: importedSplit)
            NotificationCenter.default.post(name: .cloudKitDataSynced, object: nil)
            debugLog("✅ Successfully imported shared split: \(importedSplit.name)")
        } catch {
            debugLog("❌ Failed to import shared split: \(error)")
            importError = ImportError.corruptData("Failed to import: \(error.localizedDescription)")
            showImportError = true
        }

        // Clear the preview state
        sharedSplitToPreview = nil
    }
    
    private func handleIncomingFile(_ url: URL, config: Config) {
        debugLog("📂 Opened URL: \(url)")

        // Check if this is a deep link (shadowlift://import-split/{id})
        if url.scheme == "shadowlift" {
            handleDeepLink(url, config: config)
            return
        }

        // Use the shared modelContainer - DO NOT create a new one!
        let context = modelContainer.mainContext
        let viewModel = WorkoutViewModel(config: config, context: context)

        do {
            let split = try viewModel.importSplit(from: url)
            debugLog("✅ Successfully imported split: \(split.name)")

            DispatchQueue.main.async {
                // Store split name for success alert
                self.importedSplitName = split.name
                self.showImportSuccess = true

                // Post notifications to refresh UI
                NotificationCenter.default.post(name: .importSplit, object: split)
                debugLog("📢 Notification posted for imported split")

                // Also post cloudKitDataSynced to refresh any other views
                NotificationCenter.default.post(name: .cloudKitDataSynced, object: nil)
                debugLog("📢 CloudKit sync notification posted")
            }

        } catch let error as ImportError {
            debugLog("❌ Import failed: \(error.errorDescription ?? "Unknown error")")
            DispatchQueue.main.async {
                self.importError = error
                self.showImportError = true
            }

        } catch {
            debugLog("❌ Unexpected import error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.importError = ImportError.corruptData(error.localizedDescription)
                self.showImportError = true
            }
        }
    }

    private func handleDeepLink(_ url: URL, config: Config) {
        debugLog("🔗 Handling deep link: \(url)")

        // Parse shadowlift://import-split/{id}
        guard url.host == "import-split",
              let shareID = url.pathComponents.dropFirst().first else {
            debugLog("❌ Invalid deep link format")
            importError = ImportError.invalidFormat("Invalid share link format")
            showImportError = true
            return
        }

        debugLog("🔗 Fetching shared split with ID: \(shareID)")

        // Show loading indicator
        isLoadingSharedSplit = true

        Task {
            do {
                // Fetch split from CloudKit public database
                let split = try await CloudKitManager.shared.fetchSharedSplit(shareID: shareID)

                await MainActor.run {
                    isLoadingSharedSplit = false
                    // Store the split and show preview sheet
                    sharedSplitToPreview = split
                    showSharedSplitPreview = true
                    debugLog("✅ Fetched shared split, showing preview: \(split.name)")
                }
            } catch {
                await MainActor.run {
                    isLoadingSharedSplit = false
                    debugLog("❌ Failed to fetch shared split: \(error)")
                    self.importError = ImportError.networkError("Failed to download split: \(error.localizedDescription)")
                    self.showImportError = true
                }
            }
        }
    }
}

extension Notification.Name {
    static let importSplit = Notification.Name("importSplit")
    static let cloudKitDataSynced = Notification.Name("cloudKitDataSynced")
}
