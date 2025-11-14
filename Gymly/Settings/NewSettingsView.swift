//
//  NewSettingsView.swift
//  ShadowLift
//
//  Created by Sebastián Kučera on 19.10.2025.
//

import SwiftUI
import SwiftData

struct NewSettingsView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @EnvironmentObject var config: Config
    @EnvironmentObject var userProfileManager: UserProfileManager
    @Environment(\.colorScheme) private var scheme
    @State private var weightUpdatedTrigger = false

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

                        NavigationLink(destination: Text("Notifications (Coming Soon)")) {
                            Image(systemName: "bell.fill")
                            Text("Notifications")
                        }
                        .frame(width: 300)

                        NavigationLink(destination: AppearanceView()) {

                            HStack {
                                Image(systemName: "paintbrush.fill")
                                Text("Appearance")
                                Spacer()
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
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
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Upgrade to Premium")
                                        .foregroundColor(.primary)
                                        .font(.headline)
                                    Text("Unlock AI summaries, advanced graphs & more")
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

                        Button(action: {
                            // TODO: Open App Store rating
                            if let url = URL(string: "https://apps.apple.com/app/id YOUR_APP_ID") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "star.fill")
                                Text("Rate Gymly")
                                Spacer()
                            }
                        }
                        .frame(width: 300)

                        NavigationLink(destination: Text("Send Feedback (Coming Soon)")) {
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
                            Text("About Gymly")
                        }
                        .frame(width: 300)
                    }
                    .listRowBackground(Color.black.opacity(0.05))

                    // Account Section
                    Section("Account") {
                        Button(action: {
                            // TODO: Handle logout
                            config.isUserLoggedIn = false
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
                            // TODO: Handle account deletion
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
    }
}
