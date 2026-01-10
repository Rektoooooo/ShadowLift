//
//  DeveloperTestingView.swift
//  ShadowLift
//
//  Created by Claude Code on 29.11.2025.
//

import SwiftUI
import SwiftData

#if DEBUG
/// Developer-only view for testing account deletion safely
/// This allows testing the deletion flow WITHOUT deleting CloudKit data
struct DeveloperTestingView: View {
    @ObservedObject var crashReporter = CrashReporter.shared
    @EnvironmentObject var config: Config
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.modelContext) private var context
    @State private var showTestDeleteAlert = false
    @State private var showTestDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAccount = false
    @State private var deleteError: String?
    @State private var showDeleteError = false
    @State private var deletionComplete = false
    @State private var showTutorial = false

    var body: some View {
        List {
            Section {
                Text("⚠️ DEVELOPER TESTING MODE")
                    .font(.headline)
                    .foregroundColor(.orange)

                Text("This view allows you to test account deletion WITHOUT deleting CloudKit data. Your iCloud backups will remain safe.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Premium Testing") {
                Toggle(isOn: Binding(
                    get: { storeManager.isPremium },
                    set: { newValue in
                        storeManager.debugSetPremium(newValue)
                    }
                )) {
                    HStack {
                        Image(systemName: storeManager.isPremium ? "star.fill" : "star")
                            .foregroundColor(storeManager.isPremium ? .yellow : .gray)
                        VStack(alignment: .leading) {
                            Text("Premium Status")
                            Text(storeManager.isPremium ? "Pro features enabled" : "Free tier")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Toggle(isOn: Binding(
                    get: { storeManager.hasAIAccess },
                    set: { _ in
                        storeManager.debugToggleAIAccess()
                    }
                )) {
                    HStack {
                        Image(systemName: storeManager.hasAIAccess ? "cpu.fill" : "cpu")
                            .foregroundColor(storeManager.hasAIAccess ? .purple : .gray)
                        VStack(alignment: .leading) {
                            Text("AI Access")
                            Text(storeManager.hasAIAccess ? "Pro+AI tier" : "No AI features")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("These toggles simulate subscription states for testing premium features without purchasing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Safe Test Deletion") {
                Button(action: {
                    showTestDeleteAlert = true
                }) {
                    HStack {
                        Image(systemName: "testtube.2")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text("Test Delete Account")
                                .foregroundColor(.orange)
                            Text("Deletes local data only, keeps CloudKit")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .disabled(isDeletingAccount)
            }

            Section("AI Summary Testing") {
                NavigationLink(destination: AISummaryView(forceMockup: true)) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading) {
                            Text("View AI Summary Mockup")
                            Text("Display example AI summary data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }

            Section("Tutorial Testing") {
                Button(action: {
                    showTutorial = true
                }) {
                    HStack {
                        Image(systemName: "book.pages")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Show Tutorial")
                            Text("Preview the new user tutorial")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }

                Toggle(isOn: Binding(
                    get: { config.hasSeenTutorial },
                    set: { config.hasSeenTutorial = $0 }
                )) {
                    HStack {
                        Image(systemName: config.hasSeenTutorial ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(config.hasSeenTutorial ? .green : .gray)
                        VStack(alignment: .leading) {
                            Text("Tutorial Seen")
                            Text(config.hasSeenTutorial ? "User has completed tutorial" : "Tutorial not yet shown")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Toggle off to show tutorial again on next app launch, or tap 'Show Tutorial' to preview it now.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Crash Reporter Testing") {
                Button(action: {
                    CrashReporter.shared.recordError(
                        NSError(domain: "com.gymly.test", code: 100, userInfo: [
                            NSLocalizedDescriptionKey: "Test error from developer testing"
                        ]),
                        context: ["source": "DeveloperTestingView", "type": "manual"]
                    )
                }) {
                    HStack {
                        Image(systemName: "ant.circle")
                            .foregroundColor(.orange)
                        Text("Simulate Non-Fatal Error")
                        Spacer()
                    }
                }

                Button(action: {
                    CrashReporter.shared.recordCriticalError(
                        "Test critical error - Database corruption simulation",
                        context: [
                            "source": "DeveloperTestingView",
                            "type": "critical",
                            "severity": "high"
                        ]
                    )
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Simulate Critical Error")
                        Spacer()
                    }
                }

                NavigationLink(destination: CrashReportsView()) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                        Text("View Crash Reports")
                        Spacer()
                        if crashReporter.pendingCrashReports.count > 0 {
                            Text("\(crashReporter.pendingCrashReports.count)")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                    }
                }
            }

            if deletionComplete {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)

                        Text("Test Deletion Complete!")
                            .font(.headline)

                        Text("Local data deleted. CloudKit data is SAFE. You can restore by syncing from iCloud.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Restore from iCloud") {
                            Task {
                                await CloudKitManager.shared.fetchAndMergeData(context: context, config: config)
                                deletionComplete = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }

            Section("Instructions") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("1. Tap 'Test Delete Account'", systemImage: "1.circle.fill")
                    Label("2. Confirm twice (just like real deletion)", systemImage: "2.circle.fill")
                    Label("3. All local data will be deleted", systemImage: "3.circle.fill")
                    Label("4. CloudKit data stays SAFE", systemImage: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Label("5. Tap 'Restore from iCloud' to get data back", systemImage: "icloud.and.arrow.down.fill")
                        .foregroundColor(.blue)
                }
                .font(.caption)
            }
        }
        .navigationTitle("Testing Mode")
        .alert("Test Delete Account?", isPresented: $showTestDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Test Delete", role: .destructive) {
                showTestDeleteConfirmation = true
            }
        } message: {
            Text("This will delete LOCAL data only. Your CloudKit backups will remain safe and can be restored.")
        }
        .alert("Final Test Confirmation", isPresented: $showTestDeleteConfirmation) {
            TextField("Type DELETE to confirm", text: $deleteConfirmationText)
            Button("Cancel", role: .cancel) {
                deleteConfirmationText = ""
            }
            Button("Delete Local Data", role: .destructive) {
                if deleteConfirmationText.uppercased() == "DELETE" {
                    performTestDeletion()
                } else {
                    deleteError = "You must type DELETE to confirm"
                    showDeleteError = true
                }
                deleteConfirmationText = ""
            }
        } message: {
            Text("Type DELETE to test the deletion flow. CloudKit data will NOT be deleted.")
        }
        .alert("Test Deletion Failed", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteError ?? "Unknown error occurred")
        }
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialView()
                .environmentObject(config)
                .environmentObject(AppearanceManager.shared)
        }
    }

    private func performTestDeletion() {
        isDeletingAccount = true

        Task {
            do {
                // Delete account but SKIP CloudKit deletion (safe testing!)
                try await AccountManager.shared.deleteAccount(
                    context: context,
                    config: config,
                    includeCloudKit: false  // ← KEY: Don't delete CloudKit!
                )

                await MainActor.run {
                    debugLog("✅ TEST DELETION: Local data deleted, CloudKit safe")
                    isDeletingAccount = false
                    deletionComplete = true

                    // Log back in so user can restore
                    config.isUserLoggedIn = true
                }
            } catch {
                await MainActor.run {
                    deleteError = error.localizedDescription
                    showDeleteError = true
                    isDeletingAccount = false
                }
            }
        }
    }
}

#Preview {
    DeveloperTestingView()
        .environmentObject(Config())
        .environmentObject(StoreManager())
}
#endif
