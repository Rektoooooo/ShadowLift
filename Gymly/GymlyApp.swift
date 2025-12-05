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
        }
        .modelContainer(for: [Split.self, Exercise.self, Day.self, DayStorage.self, WeightPoint.self, UserProfile.self, ExercisePR.self, ProgressPhoto.self])
    }
    
    private func handleIncomingFile(_ url: URL, config: Config) {
        debugLog("📂 Opened file: \(url)")

        guard let modelContainer = try? ModelContainer(for: Split.self, Exercise.self, Day.self, DayStorage.self, WeightPoint.self, UserProfile.self, ExercisePR.self, ProgressPhoto.self) else {
            debugLog("❌ Failed to create ModelContainer")
            importError = ImportError.corruptData("Unable to initialize database")
            showImportError = true
            return
        }

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
}

extension Notification.Name {
    static let importSplit = Notification.Name("importSplit")
    static let cloudKitDataSynced = Notification.Name("cloudKitDataSynced")
}
