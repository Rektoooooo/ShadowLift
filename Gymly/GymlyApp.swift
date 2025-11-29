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
                    print("💎 GymlyApp: StoreManager isPremium changed from \(oldValue) to \(newValue)")
                    config.updatePremiumStatus(from: newValue)
                    print("💎 GymlyApp: Config isPremium is now \(config.isPremium)")
                }
        }
        .modelContainer(for: [Split.self, Exercise.self, Day.self, DayStorage.self, WeightPoint.self, UserProfile.self, ExercisePR.self, ProgressPhoto.self])
    }
    
    private func handleIncomingFile(_ url: URL, config: Config) {
        print("Opened file: \(url)")

        if let modelContainer = try? ModelContainer(for: Split.self, Exercise.self, Day.self, DayStorage.self, WeightPoint.self, UserProfile.self, ExercisePR.self, ProgressPhoto.self) {
            let context = modelContainer.mainContext
            let viewModel = WorkoutViewModel(config: config, context: context)
            
            if let split = viewModel.importSplit(from: url) {
                print("✅ Successfully decoded split: \(split.name)") // Debug log
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .importSplit, object: split)
                    print("📢 Notification posted for imported split")

                    // Also post cloudKitDataSynced to refresh any other views
                    NotificationCenter.default.post(name: .cloudKitDataSynced, object: nil)
                    print("📢 CloudKit sync notification posted")
                }
            } else {
                print("❌ Failed to decode split")
            }
        }
    }
}

extension Notification.Name {
    static let importSplit = Notification.Name("importSplit")
    static let cloudKitDataSynced = Notification.Name("cloudKitDataSynced")
}
