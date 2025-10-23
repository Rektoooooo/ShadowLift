//
//  FitnessProfileDetailView.swift
//  Gymly
//
//  Created by Sebastián Kučera on 17.10.2025.
//

import SwiftUI

struct FitnessProfileDetailView: View {
    @EnvironmentObject var config: Config
    @EnvironmentObject var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) var scheme
    @Environment(\.dismiss) var dismiss
    @StateObject private var iCloudSync: iCloudSyncManager
    @State private var showEditProfile = false
    @State private var showResetAlert = false

    init(config: Config) {
        _iCloudSync = StateObject(wrappedValue: iCloudSyncManager(config: config))
    }

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.graphite(scheme))
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if config.hasCompletedFitnessProfile, let profile = config.fitnessProfile {
                        // Header Card
                        VStack(spacing: 16) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 60))
                                .foregroundColor(appearanceManager.accentColor.color)
                                .padding(.top, 20)

                            Text("Your Fitness Profile")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Personalized training recommendations")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 10)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.3))
                        )
                        .padding(.horizontal)

                        // Fitness Goal Section
                        ProfileDetailCard(
                            icon: profile.goal.icon,
                            title: "Fitness Goal",
                            value: profile.goal.displayName,
                            description: profile.goal.description,
                            color: appearanceManager.accentColor.color
                        )

                        // Equipment Access Section
                        ProfileDetailCard(
                            icon: profile.equipment.icon,
                            title: "Equipment Access",
                            value: profile.equipment.displayName,
                            description: profile.equipment.description,
                            color: appearanceManager.accentColor.color
                        )

                        // Experience Level Section
                        ProfileDetailCard(
                            icon: profile.experience.icon,
                            title: "Experience Level",
                            value: profile.experience.displayName,
                            description: profile.experience.description,
                            color: appearanceManager.accentColor.color
                        )

                        // Training Days Section
                        ProfileDetailCard(
                            icon: "calendar",
                            title: "Training Days",
                            value: "\(profile.daysPerWeek) days per week",
                            description: getDaysRecommendation(days: profile.daysPerWeek),
                            color: appearanceManager.accentColor.color
                        )

                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                showEditProfile = true
                            }) {
                                HStack {
                                    Image(systemName: "pencil.circle.fill")
                                    Text("Edit Profile")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(appearanceManager.accentColor.color)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }

                            Button(action: {
                                showResetAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise.circle.fill")
                                    Text("Reset Profile")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(appearanceManager.accentColor.color.opacity(0.2))
                                .foregroundColor(appearanceManager.accentColor.color)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                    } else {
                        // No profile state
                        VStack(spacing: 20) {
                            Image(systemName: "figure.run.circle")
                                .font(.system(size: 80))
                                .foregroundColor(.secondary)

                            Text("No Profile Yet")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Complete your fitness profile to get personalized workout recommendations")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)

                            Button(action: {
                                showEditProfile = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Complete Profile")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(appearanceManager.accentColor.color)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                        }
                        .padding(.top, 100)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Fitness Profile")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showEditProfile) {
            FitnessProfileSetupView(config: config)
        }
        .alert("Reset Fitness Profile", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                iCloudSync.clearProfile()
                dismiss()
            }
        } message: {
            Text("This will clear your fitness profile from both this device and iCloud. You'll need to set it up again.")
        }
    }

    private func getDaysRecommendation(days: Int) -> String {
        switch days {
        case 1...2:
            return "Great for beginners or maintaining fitness"
        case 3...4:
            return "Ideal for balanced muscle growth and recovery"
        case 5...6:
            return "Perfect for experienced lifters seeking maximum gains"
        case 7:
            return "High frequency - ensure adequate recovery between sessions"
        default:
            return ""
        }
    }
}

// MARK: - Profile Detail Card Component
struct ProfileDetailCard: View {
    let icon: String
    let title: String
    let value: String
    let description: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(value)
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                Spacer()
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
        )
        .padding(.horizontal)
    }
}
