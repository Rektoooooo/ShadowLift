//
//  ExercisePRDetailView.swift
//  Gymly
//
//  Created by Claude Code on 26.11.2025.
//

import SwiftUI

struct ExercisePRDetailView: View {
    let exercisePR: ExercisePR

    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var userProfileManager: UserProfileManager

    private var weightUnit: String {
        userProfileManager.currentProfile?.weightUnit ?? "Kg"
    }

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.accent(scheme, accentColor: appearanceManager.accentColor))
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(exercisePR.exerciseName.capitalized)
                            .font(.title)
                            .bold()

                        Text(exercisePR.muscleGroup)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(appearanceManager.accentColor.color.opacity(0.2))
                            .cornerRadius(12)
                    }
                    .padding(.top, 20)

                    Divider()
                        .padding(.horizontal)

                    // Personal Records Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("🏅 Personal Records")
                            .font(.title3)
                            .bold()
                            .padding(.horizontal)

                        // Weight PR
                        if let weight = exercisePR.bestWeight, let reps = exercisePR.bestWeightReps {
                            PRDetailCard(
                                icon: "star.fill",
                                iconColor: .yellow,
                                title: "Weight PR",
                                mainValue: "\(String(format: "%.1f", weightUnit == "Kg" ? weight : weight * 2.20462262)) \(weightUnit)",
                                subtitle: "\(reps) reps",
                                date: exercisePR.bestWeightDate
                            )
                        }

                        // 1RM PR
                        if let oneRM = exercisePR.best1RM {
                            PRDetailCard(
                                icon: "trophy.fill",
                                iconColor: .orange,
                                title: "Calculated 1RM",
                                mainValue: "\(String(format: "%.1f", weightUnit == "Kg" ? oneRM : oneRM * 2.20462262)) \(weightUnit)",
                                subtitle: sourceText(for: exercisePR),
                                date: exercisePR.best1RMDate
                            )
                        }

                        // 5RM PR
                        if let fiveRM = exercisePR.best5RM, let reps = exercisePR.best5RMReps {
                            PRDetailCard(
                                icon: "bolt.fill",
                                iconColor: .blue,
                                title: "5RM PR",
                                mainValue: "\(String(format: "%.1f", weightUnit == "Kg" ? fiveRM : fiveRM * 2.20462262)) \(weightUnit)",
                                subtitle: "\(reps) reps",
                                date: exercisePR.best5RMDate
                            )
                        }

                        // 10RM PR
                        if let tenRM = exercisePR.best10RM, let reps = exercisePR.best10RMReps {
                            PRDetailCard(
                                icon: "flame.fill",
                                iconColor: .red,
                                title: "10RM PR",
                                mainValue: "\(String(format: "%.1f", weightUnit == "Kg" ? tenRM : tenRM * 2.20462262)) \(weightUnit)",
                                subtitle: "\(reps) reps",
                                date: exercisePR.best10RMDate
                            )
                        }

                        // Volume PR
                        if let volume = exercisePR.bestVolume, let sets = exercisePR.bestVolumeSets {
                            PRDetailCard(
                                icon: "chart.bar.fill",
                                iconColor: .purple,
                                title: "Volume PR",
                                mainValue: "\(String(format: "%.0f", weightUnit == "Kg" ? volume : volume * 2.20462262)) \(weightUnit)",
                                subtitle: "\(sets) sets in one workout",
                                date: exercisePR.bestVolumeDate
                            )
                        }
                    }

                    Divider()
                        .padding(.horizontal)

                    // Statistics Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("📊 Statistics")
                            .font(.title3)
                            .bold()
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            StatRow(
                                label: "Total Workouts",
                                value: "\(exercisePR.totalWorkouts)"
                            )

                            if let lastPerformed = exercisePR.lastPerformed {
                                StatRow(
                                    label: "Last Performed",
                                    value: lastPerformed.formatted(date: .abbreviated, time: .omitted)
                                )
                            }

                            if let firstPR = exercisePR.bestWeightDate {
                                StatRow(
                                    label: "First PR",
                                    value: firstPR.formatted(date: .abbreviated, time: .omitted)
                                )
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("PR Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helper Functions

    private func sourceText(for pr: ExercisePR) -> String {
        if let weight = pr.best1RMSourceWeight, let reps = pr.best1RMSourceReps {
            let displayWeight = weightUnit == "Kg" ? weight : weight * 2.20462262
            return "From: \(String(format: "%.1f", displayWeight)) \(weightUnit) × \(reps) reps"
        }
        return ""
    }
}

// MARK: - PR Detail Card

struct PRDetailCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let mainValue: String
    let subtitle: String
    let date: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.2))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(mainValue)
                        .font(.title2)
                        .bold()

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            if let date = date {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .bold()
        }
    }
}

#Preview {
    let samplePR = ExercisePR(exerciseName: "bench press", muscleGroup: "Chest")
    samplePR.bestWeight = 100.0
    samplePR.bestWeightReps = 8
    samplePR.bestWeightDate = Date()
    samplePR.best1RM = 120.0
    samplePR.best1RMSourceWeight = 100.0
    samplePR.best1RMSourceReps = 8
    samplePR.best1RMDate = Date()
    samplePR.totalWorkouts = 12
    samplePR.lastPerformed = Date()

    return NavigationStack {
        ExercisePRDetailView(exercisePR: samplePR)
            .environmentObject(AppearanceManager.shared)
            .environmentObject(UserProfileManager.shared)
    }
}
