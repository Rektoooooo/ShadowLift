//
//  AIPersonalizedSplitView.swift
//  ShadowLift
//
//  Created by Claude Code on 05.01.2026.
//

import SwiftUI
import SwiftData

@available(iOS 26, *)
struct AIPersonalizedSplitView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @EnvironmentObject var config: Config
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @Environment(\.colorScheme) var scheme

    @StateObject private var generator = SplitGeneratorService()
    @State private var preferences: SplitPreferences
    @State private var currentStep = 1
    @State private var currentPhase: GenerationPhase = .questionnaire
    @State private var showModifySheet = false
    @State private var showSaveConfirmation = false
    @State private var isSaving = false
    @State private var aiAvailabilityError: String?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    enum GenerationPhase {
        case questionnaire
        case generating
        case preview
    }

    init(viewModel: WorkoutViewModel, config: Config) {
        self.viewModel = viewModel

        // Initialize preferences from existing fitness profile
        if let profile = config.fitnessProfile {
            _preferences = State(initialValue: SplitPreferences(from: profile))
        } else {
            _preferences = State(initialValue: SplitPreferences())
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                FloatingClouds(theme: CloudsTheme.appleIntelligence(scheme))
                    .ignoresSafeArea()

                // Check for Pro+AI access
                if !storeManager.hasAIAccess {
                    // Premium gate view
                    proAIRequiredView
                } else {
                    // Main content based on phase
                    VStack(spacing: 16) {
                        // Show AI unavailability banner if applicable
                        if let availabilityError = aiAvailabilityError {
                            aiUnavailableBannerView(reason: availabilityError)
                                .padding(.horizontal)
                        }

                        Group {
                            switch currentPhase {
                            case .questionnaire:
                                SplitQuestionnaireView(
                                    preferences: $preferences,
                                    currentStep: $currentStep,
                                    onComplete: startGeneration
                                )

                            case .generating, .preview:
                                GeneratedSplitPreviewView(
                                    generatedSplit: generator.generatedSplit,
                                    isGenerating: generator.isGenerating,
                                    onSave: { showSaveConfirmation = true },
                                    onModify: { showModifySheet = true }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if currentPhase == .preview && !generator.isGenerating {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            regenerateSplit()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showModifySheet) {
            SplitChatModificationView(
                generator: generator,
                onApply: {
                    showModifySheet = false
                },
                onCancel: {
                    showModifySheet = false
                }
            )
        }
        .alert("Save Split?", isPresented: $showSaveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                saveSplit()
            }
        } message: {
            if let name = generator.generatedSplit?.name {
                Text("This will add \"\(name)\" to your splits and set it as active.")
            } else {
                Text("This will add the generated split to your collection.")
            }
        }
        .alert("Generation Error", isPresented: $showErrorAlert) {
            Button("Try Again") {
                regenerateSplit()
            }
            Button("Cancel", role: .cancel) {
                currentPhase = .questionnaire
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Check AI availability
            let availability = generator.checkAvailability()
            if !availability.available {
                aiAvailabilityError = availability.reason
            }
            generator.prewarm()
        }
    }

    // MARK: - AI Unavailable Banner

    private func aiUnavailableBannerView(reason: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Intelligence Unavailable")
                    .font(.subheadline)
                    .fontWeight(.bold)

                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if reason.contains("Settings") {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Settings")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.orange)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.15), Color.yellow.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    // MARK: - Pro+AI Required View

    private var deviceSupportsAI: Bool {
        StoreManager.deviceSupportsAI
    }

    private var proAIRequiredView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: deviceSupportsAI
                                ? [.purple.opacity(0.3), .blue.opacity(0.2)]
                                : [.gray.opacity(0.2), .gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: deviceSupportsAI ? "sparkles" : "iphone.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        deviceSupportsAI
                            ? LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [.gray, .gray],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
            }

            // Text - different based on device capability
            VStack(spacing: 8) {
                if deviceSupportsAI {
                    Text("Pro+AI Required")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Upgrade to Pro+AI to generate personalized workout splits using Apple Intelligence.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                } else {
                    Text("Device Not Supported")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("AI features require iPhone 15 Pro or newer with Apple Intelligence.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    // Device info
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                        Text("Your device doesn't support Apple Intelligence")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 8)
                }
            }

            // Only show upgrade button if device supports AI
            if deviceSupportsAI {
                NavigationLink(destination: PremiumSubscriptionView()) {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Upgrade to Pro+AI")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.purple, appearanceManager.accentColor.color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                }
            } else {
                // Show dismiss button for unsupported devices
                Button {
                    dismiss()
                } label: {
                    Text("Go Back")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.gray)
                        .cornerRadius(25)
                }
            }

            Spacer()
        }
    }

    // MARK: - Computed Properties

    private var navigationTitle: String {
        switch currentPhase {
        case .questionnaire:
            return "AI Split Generator"
        case .generating:
            return "Generating..."
        case .preview:
            return "Your Split"
        }
    }

    // MARK: - Actions

    private func startGeneration() {
        currentPhase = .generating

        Task {
            do {
                try await generator.generateSplit(preferences: preferences)
                await MainActor.run {
                    currentPhase = .preview
                }
            } catch {
                debugLog("❌ Error generating split: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to generate workout split. Please check your internet connection and try again."
                    showErrorAlert = true
                    currentPhase = .preview
                }
            }
        }
    }

    private func regenerateSplit() {
        generator.clearSplit()
        currentPhase = .generating

        Task {
            do {
                try await generator.generateSplit(preferences: preferences)
                await MainActor.run {
                    currentPhase = .preview
                }
            } catch {
                debugLog("❌ Error regenerating split: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to regenerate workout split. Please try again."
                    showErrorAlert = true
                    currentPhase = .preview
                }
            }
        }
    }

    private func saveSplit() {
        guard let generatedSplit = generator.generatedSplit,
              let name = generatedSplit.name,
              let days = generatedSplit.days else {
            return
        }

        isSaving = true

        // Deactivate all existing splits
        viewModel.deactivateAllSplits()

        // Create new Split
        let newSplit = Split(
            name: name,
            days: [],
            isActive: true,
            startDate: Date()
        )

        // Create Days from generated data
        var createdDays: [Day] = []

        for genDay in days {
            guard let dayNumber = genDay.dayNumber,
                  let dayName = genDay.name else { continue }

            let day = Day(
                name: dayName,
                dayOfSplit: dayNumber,
                exercises: [],
                date: "",
                isRestDay: genDay.isRestDay ?? false
            )

            // Create Exercises (skip for rest days)
            if genDay.isRestDay != true, let genExercises = genDay.exercises {
                var createdExercises: [Exercise] = []

                for genExercise in genExercises {
                    guard let exerciseName = genExercise.name,
                          let muscleGroup = genExercise.muscleGroup,
                          let repRange = genExercise.repRange,
                          let sets = genExercise.sets,
                          let order = genExercise.exerciseOrder else { continue }

                    let exercise = Exercise(
                        name: exerciseName,
                        sets: [],
                        repGoal: repRange,
                        muscleGroup: muscleGroup,
                        exerciseOrder: order
                    )

                    context.insert(exercise)

                    // Create placeholder sets
                    var exerciseSets: [Exercise.Set] = []
                    for _ in 1...sets {
                        let set = Exercise.Set.createDefault()
                        context.insert(set)
                        exerciseSets.append(set)
                    }
                    exercise.sets = exerciseSets

                    createdExercises.append(exercise)
                }

                day.exercises = createdExercises
            }

            context.insert(day)
            createdDays.append(day)
        }

        newSplit.days = createdDays
        context.insert(newSplit)

        // Save to SwiftData
        do {
            try context.save()
            debugLog("✅ AI Generated split saved: \(name)")

            // Update config
            config.splitStarted = true
            config.dayInSplit = 1
            config.splitLength = createdDays.count

            // Dismiss the view
            dismiss()
        } catch {
            debugLog("❌ Error saving AI split: \(error)")
            errorMessage = "Failed to save workout split. Please try again."
            showErrorAlert = true
            isSaving = false
        }
    }
}

// MARK: - Preview Provider

@available(iOS 26, *)
#Preview {
    // Preview would require proper setup with Config and ViewModel
    Text("AI Personalized Split View")
}
