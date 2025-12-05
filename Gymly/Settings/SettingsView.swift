//
//  NewSettingsView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 19.10.2025.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @ObservedObject var crashReporter = CrashReporter.shared
    @EnvironmentObject var config: Config
    @EnvironmentObject var userProfileManager: UserProfileManager
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @State private var weightUpdatedTrigger = false
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAccount = false
    @State private var deleteError: String?
    @State private var showDeleteError = false

    let units: [String] = ["Kg","Lbs"]

    var body: some View {
        NavigationView {
            ZStack {
                FloatingClouds(theme: CloudsTheme.graphite(scheme))
                    .ignoresSafeArea()

                List {
                    // Preferences Section
                    Section("Preferences") {
                        HStack {
                            HStack {
                                Image(systemName: "scalemass")
                                Text("Unit")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Picker(selection: Binding(
                                get: { userProfileManager.currentProfile?.weightUnit ?? "Kg" },
                                set: { userProfileManager.updatePreferences(weightUnit: $0) }
                            ), label: Text("")) {
                                ForEach(units, id: \.self) { unit in
                                    Text(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, -30)
                            .onChange(of: userProfileManager.currentProfile?.weightUnit ?? "Kg") {
                                debugPrint("Selected unit: \(userProfileManager.currentProfile?.weightUnit ?? "Kg")")
                                userProfileManager.updatePreferences(roundSetWeights: true)
                                weightUpdatedTrigger.toggle()
                            }
                        }
                        .frame(width: 300)

                        NavigationLink(destination: NotificationsView()) {
                            Image(systemName: "bell")
                            Text("Notifications")
                        }
                        .frame(width: 300)

                        NavigationLink(destination: AppearanceView()) {

                            HStack {
                                Image(systemName: "paintbrush.fill")
                                Text("Appearance")
                                Spacer()
                                if !config.isPremium {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                }
                            }

                        }
                        .frame(width: 300)
                    }
                    .listRowBackground(Color.black.opacity(0.05))

                    // Integrations Section
                    Section("Integrations") {
                        NavigationLink(destination: ConnectionsView(viewModel: viewModel)) {
                            Image(systemName: "square.2.layers.3d.top.filled")
                            Text("App Connections")
                        }
                        .frame(width: 300)
                    }
                    .listRowBackground(Color.black.opacity(0.05))

                    // Premium Section
                    Section("Premium") {
                        NavigationLink(destination: PremiumSubscriptionView()) {
                            HStack {
                                Image(systemName: config.isPremium ? "checkmark.seal.fill" : "star.fill")
                                    .foregroundColor(config.isPremium ? .green : .yellow)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(config.isPremium ? "ShadowLift Pro" : "Upgrade to Premium")
                                        .foregroundColor(.primary)
                                        .font(.headline)
                                    Text(config.isPremium ? "Manage your subscription" : "Unlock AI summaries, advanced graphs & more")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                Spacer()
                            }
                        }
                        .frame(width: 300)
                    }
                    .listRowBackground(Color.black.opacity(0.05))

                    // Support Section
                    Section("Support") {
                        NavigationLink(destination: HelpFAQView()) {
                            Image(systemName: "questionmark.circle")
                            Text("Help & FAQ")
                        }
                        .frame(width: 300)

                        NavigationLink(destination: ContactSupportView()) {
                            Image(systemName: "envelope.fill")
                            Text("Contact Support")
                        }
                        .frame(width: 300)

                        NavigationLink(destination: CrashReportsView()) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                Text("Crash Reports")
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
                        .frame(width: 300)

                        Button(action: {
                            // TODO: Open App Store rating
                            if let url = URL(string: "https://apps.apple.com/app/id YOUR_APP_ID") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "star.fill")
                                Text("Rate ShadowLift")
                                Spacer()
                            }
                        }
                        .frame(width: 300)

                        NavigationLink(destination: FeedbackView()) {
                            Image(systemName: "bubble.left.and.bubble.right")
                            Text("Send Feedback")
                        }
                        .frame(width: 300)
                    }
                    .listRowBackground(Color.black.opacity(0.05))

                    // Legal Section
                    Section("Legal") {
                        NavigationLink(destination: LegalDocumentView(documentName: "privacy-policy", title: "Privacy Policy")) {
                            Image(systemName: "lock.shield")
                            Text("Privacy Policy")
                        }
                        .frame(width: 300)

                        NavigationLink(destination: LegalDocumentView(documentName: "terms-of-service", title: "Terms of Service")) {
                            Image(systemName: "doc.text")
                            Text("Terms of Service")
                        }
                        .frame(width: 300)

                        NavigationLink(destination: AboutGymlyView()) {
                            Image(systemName: "info.circle")
                            Text("About ShadowLift")
                        }
                        .frame(width: 300)
                    }
                    .listRowBackground(Color.black.opacity(0.05))

                    // Account Section
                    Section("Account") {
                        Button(action: {
                            // Simple logout - just return to sign-in screen, data stays
                            AccountManager.shared.logout(config: config)
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                    .foregroundColor(.red)
                                Text("Log Out")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                        .frame(width: 300)

                        Button(action: {
                            showDeleteAccountAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                Text("Delete Account")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                        .frame(width: 300)
                        .disabled(isDeletingAccount)

                        #if DEBUG
                        NavigationLink(destination: DeveloperTestingView()) {
                            HStack {
                                Image(systemName: "testtube.2")
                                    .foregroundColor(.orange)
                                Text("Developer Testing")
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                        }
                        .frame(width: 300)
                        #endif
                    }
                    .listRowBackground(Color.black.opacity(0.05))

                    // Version Footer
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Text("ShadowLift")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Version 1.0.0")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .navigationTitle("Settings")
            }
        }
        // First confirmation alert
        .alert("Delete Account?", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                showDeleteConfirmation = true
            }
        } message: {
            Text("This will permanently delete ALL your data including workouts, progress photos, and cloud backups. This action cannot be undone.")
        }
        // Second confirmation with text input
        .alert("Final Confirmation", isPresented: $showDeleteConfirmation) {
            TextField("Type DELETE to confirm", text: $deleteConfirmationText)
            Button("Cancel", role: .cancel) {
                deleteConfirmationText = ""
            }
            Button("Delete Forever", role: .destructive) {
                if deleteConfirmationText.uppercased() == "DELETE" {
                    performAccountDeletion()
                } else {
                    deleteError = "You must type DELETE to confirm"
                    showDeleteError = true
                }
                deleteConfirmationText = ""
            }
        } message: {
            Text("Type DELETE (in capital letters) to permanently delete your account and all data.")
        }
        // Error alert
        .alert("Deletion Failed", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteError ?? "Unknown error occurred")
        }
    }

    // MARK: - Account Deletion

    private func performAccountDeletion() {
        isDeletingAccount = true

        Task {
            do {
                // Delete account with CloudKit data
                try await AccountManager.shared.deleteAccount(
                    context: context,
                    config: config,
                    includeCloudKit: true
                )

                debugLog("✅ Account deleted successfully")
                // User is automatically logged out by deleteAccount()
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
