//
//  FitnessProfileSetupView.swift
//  Gymly
//
//  Created by Sebastián Kučera on 17.10.2025.
//

import SwiftUI

struct FitnessProfileSetupView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var config: Config
    @Environment(\.colorScheme) var scheme
    @StateObject private var iCloudSync: iCloudSyncManager

    @State private var currentStep = 1
    @State private var selectedGoal: FitnessGoal?
    @State private var selectedEquipment: EquipmentType?
    @State private var selectedExperience: ExperienceLevel?
    @State private var selectedDaysPerWeek = 4

    @State private var isSaving = false

    init(config: Config) {
        _iCloudSync = StateObject(wrappedValue: iCloudSyncManager(config: config))
    }

    var body: some View {
        ZStack {
            FloatingClouds(theme: CloudsTheme.graphite(scheme))
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Fitness Profile Setup")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Step \(currentStep) of 4")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 16)

                // Progress Bar
                ProgressView(value: Double(currentStep), total: 4)
                    .tint(.red)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)

                // Step Content
                Group {
                    switch currentStep {
                    case 1:
                        GoalSelectionView(selectedGoal: $selectedGoal)
                    case 2:
                        EquipmentSelectionView(selectedEquipment: $selectedEquipment)
                    case 3:
                        ExperienceSelectionView(selectedExperience: $selectedExperience)
                    case 4:
                        DaysPerWeekSelectionView(selectedDays: $selectedDaysPerWeek)
                    default:
                        EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }

            // Bottom gradient background layer (behind content)
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
                .allowsHitTesting(false)
            }
            .zIndex(1)

            // Floating Navigation Buttons on top
            VStack {
                Spacer()

                HStack(spacing: 16) {
                    // Back Button
                    if currentStep > 1 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }

                    // Next/Finish Button
                    Button(action: {
                        if currentStep < 4 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        } else {
                            saveProfile()
                        }
                    }) {
                        HStack {
                            Text(currentStep < 4 ? "Next" : "Finish")
                            if currentStep < 4 {
                                Image(systemName: "chevron.right")
                            }
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isNextButtonEnabled ? Color.red : Color.secondary.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isNextButtonEnabled || isSaving)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .zIndex(2)
        }
        .interactiveDismissDisabled(true) // Prevent swipe to dismiss
    }

    private var isNextButtonEnabled: Bool {
        switch currentStep {
        case 1: return selectedGoal != nil
        case 2: return selectedEquipment != nil
        case 3: return selectedExperience != nil
        case 4: return true // Always enabled on last step
        default: return false
        }
    }

    private func saveProfile() {
        guard let goal = selectedGoal,
              let equipment = selectedEquipment,
              let experience = selectedExperience else {
            return
        }

        isSaving = true

        // Create profile
        let profile = FitnessProfile(
            goal: goal,
            equipment: equipment,
            experience: experience,
            daysPerWeek: selectedDaysPerWeek
        )

        // Save to Config (UserDefaults)
        config.fitnessProfile = profile
        config.hasCompletedFitnessProfile = true

        // Sync to iCloud
        Task { @MainActor in
            iCloudSync.syncToiCloud()

            // Small delay for visual feedback
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Step 1: Goal Selection
struct GoalSelectionView: View {
    @Binding var selectedGoal: FitnessGoal?

    var body: some View {
        VStack(spacing: 16) {
            Text("What's your fitness goal?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Choose your primary training objective")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(FitnessGoal.allCases, id: \.self) { goal in
                        SelectionCard(
                            icon: goal.icon,
                            title: goal.displayName,
                            description: goal.description,
                            isSelected: selectedGoal == goal
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedGoal = goal
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 120) // Space for floating buttons
            }
        }
    }
}

// MARK: - Step 2: Equipment Selection
struct EquipmentSelectionView: View {
    @Binding var selectedEquipment: EquipmentType?

    var body: some View {
        VStack(spacing: 16) {
            Text("What equipment do you have?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("We'll tailor your workouts accordingly")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(EquipmentType.allCases, id: \.self) { equipment in
                        SelectionCard(
                            icon: equipment.icon,
                            title: equipment.displayName,
                            description: equipment.description,
                            isSelected: selectedEquipment == equipment
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedEquipment = equipment
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 120) // Space for floating buttons
            }
        }
    }
}

// MARK: - Step 3: Experience Selection
struct ExperienceSelectionView: View {
    @Binding var selectedExperience: ExperienceLevel?

    var body: some View {
        VStack(spacing: 16) {
            Text("What's your experience level?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("This helps us set appropriate intensity")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(ExperienceLevel.allCases, id: \.self) { experience in
                        SelectionCard(
                            icon: experience.icon,
                            title: experience.displayName,
                            description: experience.description,
                            isSelected: selectedExperience == experience
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedExperience = experience
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 120) // Space for floating buttons
            }
        }
    }
}

// MARK: - Step 4: Days Per Week Selection
struct DaysPerWeekSelectionView: View {
    @Binding var selectedDays: Int

    var body: some View {
        VStack(spacing: 24) {
            Text("How many days per week?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("How often can you train consistently?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Large number display
            Text("\(selectedDays)")
                .font(.system(size: 80, weight: .bold))
                .foregroundColor(.red)

            Text(selectedDays == 1 ? "day per week" : "days per week")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Stepper
            HStack(spacing: 30) {
                Button(action: {
                    if selectedDays > 1 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDays -= 1
                        }
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(selectedDays > 1 ? .red : .secondary.opacity(0.3))
                }
                .disabled(selectedDays <= 1)

                Button(action: {
                    if selectedDays < 7 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDays += 1
                        }
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(selectedDays < 7 ? .red : .secondary.opacity(0.3))
                }
                .disabled(selectedDays >= 7)
            }

            // Recommendation text
            VStack(spacing: 8) {
                Text(recommendationText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
            }

            Spacer()
        }
    }

    private var recommendationText: String {
        switch selectedDays {
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

// MARK: - Reusable Selection Card
struct SelectionCard: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .red : .white)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
